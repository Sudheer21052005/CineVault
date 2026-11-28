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
import 'package:flutter/services.dart';
import 'package:http/testing.dart';

import 'support/memory_library_store.dart';
import 'support/tmdb_fixture.dart';

void main() {
  testWidgets('desktop navigation remains exposed beside a nested route', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _mount(tester);
      expect(find.bySemanticsLabel('About CineVault'), findsOneWidget);
      await tester.tap(find.text('Now Playing').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inception').first);
      await tester.pumpAndSettle();
      expect(find.text('Runtime: 148 minutes'), findsOneWidget);
      expect(find.bySemanticsLabel('About CineVault'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

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

      await tester.tap(find.text('Now Playing').first);
      await tester.pumpAndSettle();
      expect(find.text('Films in theatrical release.'), findsOneWidget);
      await tester.tap(find.text('Inception').first);
      await tester.pumpAndSettle();
      expect(find.text('Runtime: 148 minutes'), findsOneWidget);
      expect(harness.tmdb.paths, isNot(contains('/3/movie/27205/similar')));
      expect(harness.tmdb.paths, isNot(contains('/3/movie/27205/images')));
      await tester.ensureVisible(find.text('Related'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Related'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('The Dark Knight').first,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('The Dark Knight').first);
      await tester.pumpAndSettle();
      expect(find.text('Runtime: 152 minutes'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Similar movies'), findsOneWidget);
      expect(find.text('The Dark Knight').first.hitTestable(), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Films in theatrical release.'), findsOneWidget);
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
      await tester.tap(find.text('Search').first);
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
      await tester.tap(find.text('Watchlist').first);
      await tester.pumpAndSettle();
      expect(find.text('Unable to open your local watchlist.'), findsOneWidget);
      store.failOpen = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('0 saved titles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard search and all breakpoint shells preserve the search query',
    (tester) async {
      await _mount(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'Inception');
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pumpAndSettle();
      for (final width in [320, 390, 599, 600, 768, 1023, 1024, 1440]) {
        tester.view.physicalSize = Size(width.toDouble(), 900);
        await tester.pumpAndSettle();
        final layout = width < 600
            ? 'mobile-bottom-nav'
            : width < 1024
            ? 'tablet-rail'
            : 'desktop-sidebar';
        expect(
          find.byKey(ValueKey(layout)),
          findsOneWidget,
          reason: 'Navigation at $width',
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          'Inception',
        );
        expect(tester.takeException(), isNull, reason: 'Layout at $width');
      }
    },
  );

  testWidgets('compact views lay out at 200 percent text', (tester) async {
    final errorHandler = FlutterError.onError;
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = (details) {
      errors.add(details);
      errorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = errorHandler);
    await _mount(tester);
    tester.view.physicalSize = const Size(320, 740);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final path in [
      '/',
      '/discover',
      '/discover/movies',
      '/discover/tv',
      '/discover/now-playing',
      '/search?q=Inception',
      '/movie/27205',
      '/library/watchlist',
      '/library/stats',
    ]) {
      await tester.binding.handlePushRoute(path);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: <String>[
          path,
          for (final error in errors) error.toDiagnosticsNode().toStringDeep(),
        ].join('\n'),
      );
    }
  });
}

Future<({TmdbFixture tmdb, List<PerfSample> events})> _mount(
  WidgetTester tester, {
  MemoryLibraryStore? store,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
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
