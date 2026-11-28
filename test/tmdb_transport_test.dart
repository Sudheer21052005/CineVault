import 'dart:async';
import 'dart:convert';

import 'package:cinevault/catalogue/catalogue_repository.dart';
import 'package:cinevault/catalogue/entity_ref.dart';
import 'package:cinevault/core/network/tmdb_transport.dart';
import 'package:cinevault/core/performance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/tmdb_fixture.dart';

void main() {
  const credential = 'fixture-credential-never-recorded';
  const area = PerfArea.popular;

  test('deduplicates in flight, keys by request independent of ordering, and bounds cache', () async {
    var requests = 0;
    var now = DateTime.utc(2026, 11, 27);
    final pending = Completer<http.Response>();
    final transport = TmdbTransport(
      credential: () async => credential,
      performance: AppPerformance(),
      maxEntries: 2,
      maxBytes: 30,
      now: () => now,
      client: MockClient((_) async {
        requests++;
        return requests == 1
            ? pending.future
            : http.Response('{"ok":true}', 200);
      }),
    );
    addTearDown(transport.close);
    final first = transport.get(
      '/a',
      operation: area,
      query: {'page': '1', 'region': 'IN'},
    );
    final joined = transport.get(
      '/a',
      operation: area,
      query: {'region': 'IN', 'page': '1'},
      refresh: true,
    );
    expect(identical(first, joined), isTrue);
    pending.complete(http.Response('{"ok":true}', 200));
    await joined;
    await transport.get(
      '/a',
      operation: area,
      query: {'region': 'IN', 'page': '1'},
    );
    expect(requests, 1);
    await transport.get('/b', operation: area);
    await transport.get('/c', operation: area);
    await transport.get(
      '/a',
      operation: area,
      query: {'region': 'IN', 'page': '1'},
    );
    expect(requests, 4);
    now = now.add(const Duration(minutes: 16));
    await transport.get(
      '/a',
      operation: area,
      query: {'region': 'IN', 'page': '1'},
    );
    expect(requests, 5);
  });

  test(
    'fresh retry preserves successful cached data and returns typed errors',
    () async {
      var requests = 0;
      var status = 200;
      final events = <PerfSample>[];
      final transport = TmdbTransport(
        credential: () async => credential,
        performance: AppPerformance(sink: events.add),
        sleep: (_) async {},
        client: MockClient((_) async {
          requests++;
          return http.Response(
            status == 200 ? '{"page":1}' : '{"message":"$credential"}',
            status,
          );
        }),
      );
      addTearDown(transport.close);
      await transport.get(
        '/a',
        operation: area,
        query: {'query': 'private title'},
      );
      status = 503;
      await expectLater(
        transport.get(
          '/a',
          operation: area,
          query: {'query': 'private title'},
          refresh: true,
        ),
        throwsA(
          isA<TmdbException>().having(
            (e) => e.kind,
            'kind',
            TmdbErrorKind.server,
          ),
        ),
      );
      expect(requests, 4);
      expect(
        (await transport.get(
          '/a',
          operation: area,
          query: {'query': 'private title'},
        ))['page'],
        1,
      );
      expect(requests, 4);
      expect(
        jsonEncode(events.map((e) => e.fields).toList()),
        isNot(contains(credential)),
      );
      expect(
        jsonEncode(events.map((e) => e.fields).toList()),
        isNot(contains('private title')),
      );
      status = 401;
      await expectLater(
        transport.get('/b', operation: area),
        throwsA(
          isA<TmdbException>().having(
            (e) => e.kind,
            'kind',
            TmdbErrorKind.unauthorized,
          ),
        ),
      );
      expect(requests, 5);
    },
  );

  test('429 shares Retry-After and honors the caller budget', () async {
    var now = DateTime.utc(2026, 11, 27);
    var requests = 0;
    final waits = <Duration>[];
    final transport = TmdbTransport(
      credential: () async => credential,
      performance: AppPerformance(),
      now: () => now,
      sleep: (delay) async {
        waits.add(delay);
        now = now.add(delay);
      },
      client: MockClient((request) async {
        requests++;
        if (requests == 1) {
          return http.Response('{}', 429, headers: {'Retry-After': '2'});
        }
        if (request.url.path.endsWith('/limited')) {
          return http.Response('{}', 429, headers: {'Retry-After': '30'});
        }
        return http.Response('{}', 200);
      }),
    );
    addTearDown(transport.close);
    await transport.get('/recovered', operation: area);
    expect(waits, [const Duration(seconds: 2)]);
    final rateLimited = throwsA(
      isA<TmdbException>()
          .having((e) => e.kind, 'kind', TmdbErrorKind.rateLimited)
          .having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 30),
          ),
    );
    await expectLater(transport.get('/limited', operation: area), rateLimited);
    await expectLater(transport.get('/other', operation: area), rateLimited);
    expect(requests, 3);
  });

  test(
    'bounds simultaneous requests and stops retrying malformed JSON',
    () async {
      final running = <Completer<http.Response>>[];
      final transport = TmdbTransport(
        credential: () async => credential,
        performance: AppPerformance(),
        maxConcurrent: 2,
        client: MockClient((_) {
          final reply = Completer<http.Response>();
          running.add(reply);
          return reply.future;
        }),
      );
      addTearDown(transport.close);
      final one = transport.get('/a', operation: area);
      final two = transport.get('/b', operation: area);
      final three = transport.get('/c', operation: area);
      await Future<void>.delayed(Duration.zero);
      expect(running, hasLength(2));
      final badResponse = expectLater(
        one,
        throwsA(
          isA<TmdbException>().having(
            (e) => e.kind,
            'kind',
            TmdbErrorKind.invalidResponse,
          ),
        ),
      );
      running[0].complete(http.Response('[]', 200));
      await badResponse;
      await Future<void>.delayed(Duration.zero);
      expect(running, hasLength(3));
      running[1].complete(http.Response('{}', 200));
      running[2].complete(http.Response('{}', 200));
      await Future.wait([two, three]);
    },
  );

  test('maps actual movie/TV search scopes and keeps TV discovery parameters separate', () async {
    final fixture = TmdbFixture();
    final requests = <Uri>[];
    final transport = TmdbTransport(
      credential: () async => credential,
      performance: AppPerformance(),
      client: MockClient((request) {
        requests.add(request.url);
        return fixture.respond(request);
      }),
    );
    addTearDown(transport.close);
    final repository = CatalogueRepository(transport);
    expect(
      (await repository.search(
        'Inception',
        SearchScope.movie,
      )).items.single.key,
      'movie-27205',
    );
    expect(
      (await repository.search('Inception', SearchScope.tv)).items,
      isEmpty,
    );
    expect(
      (await repository.search('Breaking', SearchScope.tv)).items.single.key,
      'tv-1396',
    );
    expect(
      (await repository.search(
        'Inception',
        SearchScope.all,
      )).items.single.genreIds,
      [28, 878],
    );
    final tv = await repository.discover((
      kind: MediaKind.tv,
      genre: 10759,
      year: 2026,
      minimumRating: 8.0,
      sort: CatalogueSort.release,
    ));
    expect(tv.items.single.key, 'tv-1396');
    final uri = requests.last;
    expect(uri.path, '/3/discover/tv');
    expect(uri.queryParameters, containsPair('first_air_date_year', '2026'));
    expect(uri.queryParameters, containsPair('sort_by', 'first_air_date.desc'));
    expect(uri.queryParameters, isNot(contains('query')));
    expect(fixture.paths.take(4), [
      '/3/search/movie',
      '/3/search/tv',
      '/3/search/tv',
      '/3/search/multi',
    ]);
  });
}
