import 'dart:io';

import 'package:cinevault/catalogue/artwork_policy.dart';
import 'package:cinevault/core/network/catalogue_cache.dart';
import 'package:cinevault/core/network/tmdb_transport.dart';
import 'package:cinevault/core/performance.dart';
import 'package:cinevault/ui/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('breakpoints and grid density agree at every boundary', () {
    expect(
      [
        320,
        390,
        599,
        600,
        768,
        1023,
        1024,
        1440,
      ].map((size) => CineLayout.widthFor(size.toDouble())),
      [
        CineWidth.compact,
        CineWidth.compact,
        CineWidth.compact,
        CineWidth.medium,
        CineWidth.medium,
        CineWidth.medium,
        CineWidth.expanded,
        CineWidth.expanded,
      ],
    );
    expect(cineColumns(288, 1), 2);
    expect(cineColumns(288, 2), 1);
    expect(cineColumns(1140, 1), 7);
    expect(cineCardHeight(140, 2), greaterThan(cineCardHeight(140, 1)));
  });

  test('selects artwork variants by logical width, caps DPR and honors TMDB configuration', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/3/configuration');
      return http.Response(
        '{"images":{"poster_sizes":["original","w154","w342","w93"]}}',
        200,
      );
    });
    final transport = TmdbTransport(
      credential: () async => 'fake',
      performance: AppPerformance(),
      client: client,
    );
    addTearDown(transport.close);
    final policy = ArtworkPolicy(transport);
    addTearDown(policy.dispose);
    expect(policy.width(ArtworkKind.poster, 80, 1), 92);
    expect(policy.width(ArtworkKind.poster, 80, 4), 185);
    expect(policy.width(ArtworkKind.backdrop, 1250, 4), 1280);
    final changed = Future<void>(() async {
      await Future<void>.delayed(Duration.zero);
    });
    policy.loadConfiguration();
    await changed;
    expect(policy.width(ArtworkKind.poster, 80, 1), 93);
    expect(policy.width(ArtworkKind.poster, 80, 4), 342);
  });

  test(
    'catalogue storage evicts by byte and record budget and survives a reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('cinevault-cache-');
      Hive.init(dir.path);
      addTearDown(() async {
        await Hive.close();
        await dir.delete(recursive: true);
      });
      final now = DateTime.now();
      HiveCatalogueCache cache() => HiveCatalogueCache(
        initialize: () async {},
        maxEntries: 2,
        maxBytes: 20,
      );
      final first = cache();
      final response = (
        json: '{"fixture":1}',
        bytes: 13,
        expires: now.add(const Duration(hours: 1)),
      );
      await first.write('/first', response, now);
      await first.write('/second', response, now);
      expect(await first.read('/first', now), isNull);
      expect(decodeStoredResponse((await first.read('/second', now))!), {
        'fixture': 1,
      });
      await Hive.close();
      final reopened = cache();
      expect((await reopened.read('/second', now))?.bytes, 13);
      expect(
        await reopened.read('/second', now.add(const Duration(hours: 2))),
        isNull,
      );
    },
  );

  test('disk cache serves public catalogue responses and never persists search terms', () async {
    final disk = _MemoryCache();
    var calls = 0;
    TmdbTransport transport() => TmdbTransport(
      credential: () async => 'fixture-key',
      performance: AppPerformance(),
      durableCache: disk,
      client: MockClient((_) async {
        calls++;
        return http.Response('{"results":[]}', 200);
      }),
    );
    final initial = transport();
    final reopened = transport();
    addTearDown(initial.close);
    addTearDown(reopened.close);
    await initial.get('/movie/popular', operation: PerfArea.popular);
    await reopened.get('/movie/popular', operation: PerfArea.popular);
    expect(calls, 1);
    await reopened.get(
      '/search/movie',
      operation: PerfArea.textSearch,
      query: {'query': 'private text'},
    );
    await reopened.get(
      '/discover/movie',
      operation: PerfArea.discover,
      query: {'with_genres': '28'},
    );
    expect(calls, 3);
    expect(disk.map, hasLength(1));
    expect(disk.map.keys.single, isNot(contains('fixture-key')));
  });
}

class _MemoryCache implements CatalogueCache {
  final map = <String, StoredResponse>{};

  @override
  Future<StoredResponse?> read(String key, DateTime now) async => map[key];

  @override
  Future<void> write(String key, StoredResponse response, DateTime now) async {
    map[key] = response;
  }
}
