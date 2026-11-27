import 'dart:convert';

import 'package:cinevault/app/application.dart';
import 'package:cinevault/app/route_contract.dart';
import 'package:cinevault/catalogue/catalogue_repository.dart';
import 'package:cinevault/catalogue/entity_ref.dart';
import 'package:cinevault/catalogue/knowledge_models.dart';
import 'package:cinevault/core/material.dart';
import 'package:cinevault/core/network/tmdb_transport.dart';
import 'package:cinevault/core/performance.dart';
import 'package:cinevault/library/library_repository.dart';
import 'package:cinevault/providers/watchlist_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/memory_library_store.dart';
import 'support/tmdb_fixture.dart';

const _movie = (kind: EntityKind.movie, id: 27205);
const _series = (kind: EntityKind.tv, id: 1396);
const _first = (seriesId: 1396, seasonNumber: 1);
const _episode = (seriesId: 1396, seasonNumber: 1, episodeNumber: 1);
const _person = {
  'id': 525,
  'name': 'Christopher Nolan',
  'biography': 'Writer and director.',
  'known_for_department': 'Directing',
  'external_ids': {'imdb_id': 'nm0634240'},
};
const _credits = {
  'cast': [],
  'crew': [
    {
      'id': 525,
      'name': 'Christopher Nolan',
      'job': 'Director',
      'department': 'Directing',
      'credit_id': 'a',
    },
    {
      'id': 525,
      'name': 'Christopher Nolan',
      'job': 'Writer',
      'department': 'Writing',
      'credit_id': 'b',
    },
  ],
};
const _aggregate = {
  'cast': [
    {
      'id': 10,
      'name': 'Cast performer',
      'roles': [
        {'character': 'First character', 'episode_count': 3, 'credit_id': 'a'},
        {'character': 'Second character', 'episode_count': 1, 'credit_id': 'b'},
      ],
    },
  ],
  'crew': [
    {
      'id': 10,
      'name': 'Cast performer',
      'department': 'Production',
      'jobs': [
        {'job': 'Producer', 'episode_count': 2, 'credit_id': 'c'},
      ],
    },
  ],
};
const _filmography = {
  'cast': [
    {
      'id': 155,
      'media_type': 'movie',
      'title': 'The Dark Knight',
      'character': 'Self',
      'release_date': '2008-07-16',
      'vote_average': 8.5,
      'vote_count': 1000,
      'genre_ids': [28],
      'popularity': 100.0,
    },
  ],
  'crew': [
    {
      'id': 155,
      'media_type': 'movie',
      'title': 'The Dark Knight',
      'job': 'Director',
      'credit_id': 'd',
    },
    {
      'id': 155,
      'media_type': 'movie',
      'title': 'The Dark Knight',
      'job': 'Writer',
      'credit_id': 'w',
    },
    {
      'id': 1396,
      'media_type': 'tv',
      'name': 'Breaking Bad',
      'job': 'Producer',
      'first_air_date': '2008-01-20',
      'vote_average': 8.9,
      'vote_count': 205,
      'genre_ids': [18],
    },
    {
      'id': 100,
      'media_type': 'movie',
      'title': 'Unrated credit',
      'job': 'Writer',
    },
  ],
};

void main() {
  test('aggregate and combined credits preserve all jobs, characters and credit IDs', () {
    final cast = readCredits(_aggregate['cast'], _aggregate['crew'])!;
    expect(cast.single.person.ref, (kind: EntityKind.person, id: 10));
    expect(cast.single.roles.map((role) => role.role), [
      'First character',
      'Second character',
      'Producer',
    ]);
    expect(cast.single.roles.map((role) => role.episodes), [3, 1, 2]);
    expect(cast.single.roles.map((role) => role.id), ['a', 'b', 'c']);
    expect(readCredits(null, null), isNull);
    expect(readCredits([], []), isEmpty);
    final combined = readFilmography(_filmography)!;
    expect(combined.first.roles.map((role) => role.role), [
      'Self',
      'Director',
      'Writer',
    ]);
    expect(readFilmography({}), isNull);
    expect(readFilmography({'cast': []}), isEmpty);
    expect(
      const FilmographyFilter(sort: FilmSort.lowRated)
          .apply(combined)
          .map((entry) => entry.title.id),
      [155, 1396, 100],
    );
    expect(
      const FilmographyFilter(sort: FilmSort.topRated)
          .apply(combined)
          .map((entry) => entry.title.id),
      [1396, 155, 100],
    );
    expect(
      const FilmographyFilter(
        kind: MediaKind.movie,
        role: 'Director',
        genre: (kind: MediaKind.movie, id: 28),
        year: 2008,
        minimumVotes: 200,
      ).apply(combined).single.title.id,
      155,
    );
  });

  test('filmography filters and search scopes round trip in typed URLs', () {
    final uri = Uri.parse(
      '/person/525/filmography?kind=movie&role=Director&genre=movie%3A28&year=2008&votes=500&sort=topRated',
    );
    final route = parseCineRoute(uri) as FilmographyRoute;
    expect(route.uri, uri);
    expect(route.filter.minimumVotes, 500);
    expect(
      (parseCineRoute(
        Uri.parse('/search?q=Nolan&scope=person'),
      ) as TabRoute).scope,
      SearchScope.person,
    );
    expect(externalReference('TVDB:81189'), (
      source: 'tvdb_id',
      value: '81189',
    ));
    expect(externalReference('NM0634240'), (
      source: 'imdb_id',
      value: 'nm0634240',
    ));
    expect(externalReference('wikidata:q25191'), (
      source: 'wikidata_id',
      value: 'Q25191',
    ));
    expect(externalReference('tvdb:../../secrets'), isNull);
    expect(website('javascript:alert(1)'), isNull);
  });

  test(
    'requests append only small sections and use supported scoped paths',
    () async {
      final harness = _Harness();
      addTearDown(harness.transport.close);
      final title = await harness.repo.titleKnowledge(_movie);
      expect(title.media.title, 'Inception');
      expect(
        harness.requests.single.queryParameters['append_to_response'],
        'external_ids,keywords',
      );
      expect(harness.requests.single.path, '/3/movie/27205');
      await harness.repo.details(_movie);
      expect(harness.requests, hasLength(1));
      await harness.repo.section(_series, KnowledgeSection.credits);
      expect(harness.requests.last.path, '/3/tv/1396/aggregate_credits');
      await harness.repo.seasonCredits(_first);
      expect(
        harness.requests.last.path,
        '/3/tv/1396/season/1/aggregate_credits',
      );
      await harness.repo.episode(_episode);
      expect(harness.requests.last.path, '/3/tv/1396/season/1/episode/1');
      await harness.repo.episodeImages(_episode);
      expect(
        harness.requests.last.path,
        '/3/tv/1396/season/1/episode/1/images',
      );
      expect(
        harness.requests.last.queryParameters['include_image_language'],
        'en,null',
      );

      final person = await harness.repo.universalSearch(
        'Nolan',
        SearchScope.all,
      );
      expect(person.items.single.entity?.ref, (
        kind: EntityKind.person,
        id: 525,
      ));
      final collections = await harness.repo.universalSearch(
        'franchise',
        SearchScope.collection,
      );
      expect(collections.items.single.entity?.ref.kind, EntityKind.collection);
      final found = await harness.repo.universalSearch(
        'tt1375666',
        SearchScope.all,
      );
      expect(found.items.single.media?.ref, _movie);
      expect(
        harness.requests.last.queryParameters['external_source'],
        'imdb_id',
      );
      await harness.repo.associated(
        MediaKind.tv,
        entity: (kind: EntityKind.network, id: 174),
      )(1, refresh: false);
      expect(harness.requests.last.queryParameters['with_networks'], '174');
      expect(harness.requests.last.path, '/3/discover/tv');
    },
  );

  testWidgets(
    'direct movie, lazy credits and sorted filmography preserve the chain',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester, '/movie/27205');
      expect(find.text('Runtime: 148 minutes'), findsOneWidget);
      expect(
        harness.requests.map((entry) => entry.path),
        isNot(contains('/3/movie/27205/credits')),
      );
      expect(
        harness.requests.map((entry) => entry.path),
        isNot(contains('/3/trending/movie/week')),
      );

      await _tap(tester, 'Cast & crew');
      expect(find.text('Director · Writer'), findsOneWidget);
      await _tap(tester, 'Christopher Nolan');
      expect(find.text('Biography'), findsOneWidget);
      await _tap(tester, 'Full filmography');
      expect(find.text('Filmography'), findsOneWidget);
      await _tap(tester, 'Popularity');
      await _tap(tester, 'Highest rated', last: true);
      expect(find.text('Highest rated'), findsOneWidget);
      await _tap(tester, 'The Dark Knight');
      expect(find.text('Runtime: 152 minutes'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Highest rated'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TV season, episode and guest links work at phone width', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.mount(tester, '/tv/1396', size: const Size(390, 844));
    await _tap(tester, 'Season 1');
    expect(find.text('Episodes'), findsOneWidget);
    await _tap(tester, 'Pilot');
    await _tap(tester, 'Guest stars');
    await _tap(tester, 'Christopher Nolan');
    expect(find.text('Biography'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tap(
  WidgetTester tester,
  String label, {
  bool last = false,
}) async {
  final matches = find.text(label);
  final target = last ? matches.last : matches.first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

class _Harness {
  final base = TmdbFixture();
  final requests = <Uri>[];
  final performance = AppPerformance();
  late final transport = TmdbTransport(
    credential: () async => 'fixture-only',
    performance: performance,
    client: MockClient(_respond),
  );
  late final repo = CatalogueRepository(transport);

  Future<http.Response> _respond(http.Request request) async {
    requests.add(request.url);
    final path = request.url.path;
    final firstEpisode = {
      'name': 'Pilot',
      'episode_number': 1,
      'id': 62085,
      'guest_stars': [
        {'id': 525, 'name': 'Christopher Nolan', 'character': 'Fixture guest'},
      ],
      'crew': [],
    };
    final supplemental = switch (path) {
      '/3/movie/27205/credits' => _credits,
      '/3/tv/1396/aggregate_credits' ||
      '/3/tv/1396/season/1/aggregate_credits' => _aggregate,
      '/3/person/525' => _person,
      '/3/person/525/combined_credits' => _filmography,
      '/3/tv/1396/season/1' => {
        'name': 'Season 1',
        'episodes': [firstEpisode],
      },
      '/3/tv/1396/season/1/episode/1' => firstEpisode,
      '/3/search/multi' => {
        'results': [
          {..._person, 'media_type': 'person'},
        ],
      },
      '/3/search/collection' => {
        'results': [
          {'id': 10, 'name': 'Franchise'},
        ],
      },
      '/3/find/tt1375666' => {
        'movie_results': [
          {'id': 27205, 'title': 'Inception'},
        ],
      },
      _ => null,
    };
    if (supplemental != null) {
      return http.Response(jsonEncode(supplemental), 200);
    }
    final response = await base.respond(request);
    if (path == '/3/tv/1396' && response.statusCode == 200) {
      return http.Response(
        jsonEncode({
          ...jsonDecode(response.body) as Json,
          'seasons': [
            {'season_number': 0, 'name': 'Specials'},
            {'season_number': 1, 'name': 'Season 1'},
          ],
        }),
        200,
      );
    }
    return response;
  }

  Future<void> mount(
    WidgetTester tester,
    String initial, {
    Size size = const Size(1440, 900),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.defaultRouteNameTestValue = initial;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    final library = WatchlistProvider(
      LibraryRepository(MemoryLibraryStore()),
      performance,
    );
    addTearDown(transport.close);
    addTearDown(library.dispose);
    await tester.pumpWidget(
      CineVaultApp(
        catalogue: repo,
        watchlist: library,
        performance: performance,
        startupWatch: Stopwatch()..start(),
      ),
    );
    await tester.pumpAndSettle();
  }
}
