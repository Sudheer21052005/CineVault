import 'package:cinevault/app/application.dart';
import 'package:cinevault/app/route_contract.dart';
import 'package:cinevault/catalogue/catalogue_repository.dart';
import 'package:cinevault/catalogue/entity_ref.dart';
import 'package:cinevault/core/material.dart';
import 'package:cinevault/core/network/tmdb_transport.dart';
import 'package:cinevault/core/performance.dart';
import 'package:cinevault/library/library_repository.dart';
import 'package:cinevault/providers/watchlist_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'support/memory_library_store.dart';
import 'support/tmdb_fixture.dart';

void main() {
  test(
    'route contract validates IDs and round trips nested entity/discovery URLs',
    () {
      final season =
          parseCineRoute(Uri.parse('/tv/1396/season/0')) as SeasonRoute;
      expect(season.ref, (seriesId: 1396, seasonNumber: 0));
      for (final path in [
        '/movie/27205',
        '/tv/1396',
        '/person/525',
        '/person/525/filmography',
        '/collection/10',
        '/company/260',
        '/keyword/18',
        '/network/10',
        '/genre/tv/10759',
        '/tv/1396/season/1/episode/2',
        '/search?q=Inception&scope=movie',
        '/search?mode=discover&kind=tv&genre=10759&year=2026&rating=8.0&sort=release',
      ]) {
        expect(parseCineRoute(Uri.parse(path)).uri.toString(), path);
      }
      for (final path in [
        '/movie/0',
        '/tv/1/season/-1',
        '/tv/1/season/0/episode/0',
        '/person/no',
      ]) {
        expect(parseCineRoute(Uri.parse(path)), isA<UnknownRoute>());
      }
      final movie = parseCineRoute(Uri.parse('/movie/1396')) as TitleRoute;
      final tv = parseCineRoute(Uri.parse('/tv/1396')) as TitleRoute;
      expect(movie.ref, (kind: EntityKind.movie, id: 1396));
      expect(movie.ref, isNot(tv.ref));
    },
  );

  testWidgets(
    'Home is immediate, inactive feeds stay lazy, and nested Back returns to origin',
    (tester) async {
      final harness = await _mount(tester);
      expect(find.text('CineVault'), findsOneWidget);
      expect(
        harness.events.map((event) => event.event),
        contains(PerfEvent.startupShell),
      );
      expect(harness.tmdb.paths, isNot(contains('/3/tv/popular')));

      await tester.tap(find.text('Now Playing'));
      await tester.pumpAndSettle();
      expect(find.text('Select a title to view its details.'), findsOneWidget);
      await tester.tap(find.text('Inception').first);
      await tester.pumpAndSettle();
      expect(find.text('Runtime: 148 minutes'), findsOneWidget);
      await tester.tap(find.text('The Dark Knight').first);
      await tester.pumpAndSettle();
      expect(find.text('Runtime: 152 minutes'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Runtime: 148 minutes'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Select a title to view its details.'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('CineVault'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        harness.tmdb.paths.where((path) => path == '/3/movie/27205'),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'search, clear and scoped results stay reachable when the library fails',
    (tester) async {
      final store = MemoryLibraryStore()..failOpen = true;
      final harness = await _mount(tester, store: store);
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Inception');
      await tester.pump(const Duration(milliseconds: 310));
      await tester.pumpAndSettle();
      expect(find.text('Inception'), findsWidgets);
      expect(harness.tmdb.paths, contains('/3/search/multi'));
      expect(
        harness.events.map((event) => event.event),
        contains(PerfEvent.searchResults),
      );

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(
        find.text('Search the TMDB catalogue to find your next story.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Watchlist'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to open your local watchlist.'), findsOneWidget);
      store.failOpen = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('0 saved titles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<({TmdbFixture tmdb, List<PerfSample> events})> _mount(
  WidgetTester tester, {
  MemoryLibraryStore? store,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 850);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final events = <PerfSample>[];
  final performance = AppPerformance(sink: events.add);
  final tmdb = TmdbFixture();
  final transport = TmdbTransport(
    credential: () async => 'fixture-only',
    performance: performance,
    client: MockClient(tmdb.respond),
  );
  final provider = WatchlistProvider(
    LibraryRepository(store ?? MemoryLibraryStore()),
    performance,
  );
  addTearDown(transport.close);
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    CineVaultApp(
      catalogue: CatalogueRepository(transport),
      watchlist: provider,
      performance: performance,
      startupWatch: Stopwatch()..start(),
    ),
  );
  await tester.pumpAndSettle();
  return (tmdb: tmdb, events: events);
}
