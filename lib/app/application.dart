import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/entity_ref.dart';
import '../core/material.dart';
import '../core/performance.dart';
import '../models/media.dart';
import '../providers/watchlist_provider.dart';
import 'navigation_scope.dart';
import 'route_contract.dart';
import 'scroll_watch.dart';

class CineVaultApp extends StatefulWidget {
  const CineVaultApp({
    required this.catalogue,
    required this.watchlist,
    required this.performance,
    required this.startupWatch,
    super.key,
  });

  final CatalogueRepository catalogue;
  final WatchlistProvider watchlist;
  final AppPerformance performance;
  final Stopwatch startupWatch;

  @override
  State<CineVaultApp> createState() => _CineVaultAppState();
}

class _CineVaultAppState extends State<CineVaultApp> {
  late final _delegate = _CineRouter(widget.performance, widget.startupWatch);
  late final _provider = PlatformRouteInformationProvider(
    initialRouteInformation: RouteInformation(
      uri: Uri.parse(
        WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.performance.record(
        PerfSample(PerfEvent.startupFirstFrame, widget.startupWatch.elapsed),
      );
      widget.watchlist.initialize();
    });
  }

  @override
  void dispose() {
    _delegate.dispose();
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider.value(value: widget.catalogue),
      Provider.value(value: widget.performance),
      ChangeNotifierProvider.value(value: widget.watchlist),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CineVault',
      theme: cineTheme(),
      routeInformationParser: const _CineParser(),
      routeInformationProvider: _provider,
      routerDelegate: _delegate,
      backButtonDispatcher: RootBackButtonDispatcher(),
    ),
  );
}

typedef _Location = ({CineRoute route, int? historyId});

class _CineParser extends RouteInformationParser<_Location> {
  const _CineParser();

  @override
  Future<_Location> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final state = routeInformation.state;
    return (
      route: parseCineRoute(routeInformation.uri),
      historyId: state is int ? state : null,
    );
  }

  @override
  RouteInformation restoreRouteInformation(_Location configuration) =>
      RouteInformation(
        uri: configuration.route.uri,
        state: configuration.historyId,
      );
}

class _Entry {
  const _Entry(this.id, this.route, {this.summary, this.heroTag, this.label});

  final int id;
  final CineRoute route;
  final Media? summary;
  final String? heroTag;
  final String? label;
}

class _HistoryEntry {
  const _HistoryEntry(this.id, this.stack);

  final int id;
  final List<_Entry> stack;
}

class _CineRouter extends RouterDelegate<_Location>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<_Location> {
  _CineRouter(this._performance, this._startupWatch);

  static const _shellKey = ValueKey('cinevault-shell');
  final AppPerformance _performance;
  final Stopwatch _startupWatch;
  final _history = <int, _HistoryEntry>{};
  var _active = const _HistoryEntry(0, [_Entry(0, TabRoute(AppTab.home))]);
  var _lastSearch = const TabRoute(AppTab.search);
  int _serial = 0;
  int _navigationRevision = 0;
  bool _shellPainted = false;
  bool _exiting = false;
  bool _disposed = false;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  _Location get currentConfiguration =>
      (route: _active.stack.last.route, historyId: _active.id);

  @override
  Future<void> setNewRoutePath(_Location configuration) async {
    final watch = Stopwatch()..start();
    final route = configuration.route;
    final saved = _history[configuration.historyId];
    if (saved != null && saved.stack.last.route.uri == route.uri) {
      _activate(saved, watch);
    } else {
      _replaceStack(_stackFor(route), watch);
    }
  }

  List<_Entry> _stackFor(CineRoute route) => route is TabRoute
      ? [_Entry(++_serial, route)]
      : [
          _Entry(++_serial, const TabRoute(AppTab.home)),
          _Entry(++_serial, route),
        ];

  void _replaceStack(List<_Entry> stack, Stopwatch watch) =>
      _activate(_HistoryEntry(++_serial, stack), watch);

  void _activate(_HistoryEntry entry, Stopwatch? watch) {
    _active = entry;
    _history[entry.id] = entry;
    if (_history.length > 80) {
      _history.remove(_history.keys.firstWhere((id) => id != entry.id));
    }
    final root = entry.stack.first.route as TabRoute;
    if (root.tab == AppTab.search) _lastSearch = root;
    final revision = ++_navigationRevision;
    if (watch != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed || revision != _navigationRevision) return;
        _performance.record(
          PerfSample(
            PerfEvent.navigation,
            watch.elapsed,
            area: entry.stack.last.route.area,
            outcome: PerfOutcome.success,
          ),
        );
      });
    }
    notifyListeners();
  }

  void _open(
    BuildContext context,
    CineRoute route, {
    Media? summary,
    String? heroTag,
    String? label,
  }) {
    if (_active.stack.last.route.uri == route.uri) return;
    final watch = Stopwatch()..start();
    Router.navigate(context, () {
      _replaceStack([
        ..._active.stack,
        _Entry(
          ++_serial,
          route,
          summary: summary,
          heroTag: heroTag,
          label: label,
        ),
      ], watch);
    });
  }

  void _select(BuildContext context, AppTab tab) {
    final route = tab == AppTab.search ? _lastSearch : TabRoute(tab);
    if (_active.stack.last.route.uri == route.uri) return;
    Router.navigate(
      context,
      () => _replaceStack(_stackFor(route), Stopwatch()..start()),
    );
  }

  void _updateSearch(BuildContext context, TabRoute route) {
    _lastSearch = route;
    if (_active.stack.length != 1 ||
        (_active.stack.first.route as TabRoute).tab != AppTab.search ||
        _active.stack.first.route.uri == route.uri) {
      return;
    }
    Router.neglect(context, () {
      _activate(
        _HistoryEntry(_active.id, [_Entry(_active.stack.first.id, route)]),
        null,
      );
    });
  }

  void _back(BuildContext context) {
    final watch = Stopwatch()..start();
    Router.neglect(context, () => _popStack(watch));
  }

  void _popStack(Stopwatch watch) {
    final stack = _active.stack;
    // Preserve the browser-visible history token when replacing a location.
    final next = stack.length > 1
        ? stack.sublist(0, stack.length - 1)
        : _stackFor(const TabRoute(AppTab.home));
    _activate(_HistoryEntry(_active.id, next), watch);
  }

  @override
  Future<bool> popRoute() async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return false;
    if (await navigator.maybePop()) return true;
    if (!navigator.mounted) return false;
    if (_active.stack.length > 1 ||
        (_active.stack.first.route as TabRoute).tab != AppTab.home) {
      _back(navigator.context);
      return true;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    if (_exiting) return true;
    _exiting = true;
    try {
      final shouldExit = await showDialog<bool>(
        context: navigator.context,
        builder: (context) => AlertDialog(
          title: const Text('Exit CineVault?'),
          content: const Text('Are you sure you want to exit the app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Exit'),
            ),
          ],
        ),
      );
      if (shouldExit == true) await SystemNavigator.pop();
    } finally {
      _exiting = false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shellPainted) {
      _shellPainted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        _performance.record(
          PerfSample(
            PerfEvent.startupShell,
            _startupWatch.elapsed,
            area: _active.stack.last.route.area,
          ),
        );
      });
    }
    final root = _active.stack.first.route as TabRoute;
    return CineNavigation(
      open: _open,
      select: _select,
      updateSearch: _updateSearch,
      back: _back,
      child: Navigator(
        key: navigatorKey,
        pages: [
          MaterialPage<void>(
            key: _shellKey,
            child: ScrollWatch(
              area: root.area,
              child: MainShell(
                tab: root.tab,
                searchRoute: _lastSearch,
                covered: _active.stack.length > 1,
              ),
            ),
          ),
          for (final entry in _active.stack.skip(1))
            MaterialPage<void>(
              key: ValueKey(entry.id),
              child: ScrollWatch(
                area: entry.route.area,
                child: _buildPage(context, entry),
              ),
            ),
        ],
        onDidRemovePage: (page) {
          final top = _active.stack.last;
          if (_active.stack.length > 1 && page.key == ValueKey(top.id)) {
            _back(context);
          }
        },
      ),
    );
  }

  Widget _buildPage(BuildContext context, _Entry entry) =>
      switch (entry.route) {
        final TitleRoute route
            when route.ref.kind == EntityKind.movie ||
                route.ref.kind == EntityKind.tv =>
          MediaDetailsPage(
            ref: route.ref,
            summary: entry.summary,
            heroTag: entry.heroTag,
          ),
        final FeedRoute route => DiscoveryPage(
          title: entry.label ?? route.feed.label,
          loader: context.read<CatalogueRepository>().feedLoader(route.feed),
        ),
        final GenreRoute route => DiscoveryPage(
          title:
              entry.label ??
              (route.ref.kind == MediaKind.movie ? 'Movie genre' : 'TV genre'),
          loader: (page, {required refresh}) =>
              context.read<CatalogueRepository>().discover(
                (
                  kind: route.ref.kind,
                  genre: route.ref.id,
                  year: null,
                  minimumRating: null,
                  sort: CatalogueSort.popularity,
                ),
                page: page,
                refresh: refresh,
              ),
        ),
        _ => Scaffold(
          appBar: AppBar(
            title: const Text('Explore'),
            leading: BackButton(onPressed: () => _back(context)),
          ),
          body: const Center(
            child: MessageState(
              message: 'This destination is not available yet.',
            ),
          ),
        ),
      };

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
