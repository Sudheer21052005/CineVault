import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../catalogue/artwork_policy.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/entity_ref.dart';
import '../core/material.dart';
import '../core/performance.dart';
import '../models/media.dart';
import '../library/personal_library.dart';
import '../library/personal_insights.dart';
import '../providers/watchlist_provider.dart';
import '../ui/about.dart';
import '../ui/entities.dart';
import '../ui/episodes.dart';
import '../ui/personal_page.dart';
import '../ui/graph_widgets.dart' show entityLabel;
import 'browser_back_stub.dart'
    if (dart.library.js_interop) 'browser_back_web.dart';
import 'navigation_scope.dart';
import 'route_contract.dart';
import 'scroll_watch.dart';

class CineVaultApp extends StatefulWidget {
  const CineVaultApp({
    required this.catalogue,
    required this.watchlist,
    required this.performance,
    required this.startupWatch,
    this.personal,
    super.key,
  });

  final CatalogueRepository catalogue;
  final WatchlistProvider watchlist;
  final AppPerformance performance;
  final Stopwatch startupWatch;
  final PersonalLibrary? personal;

  @override
  State<CineVaultApp> createState() => _CineVaultAppState();
}

class _CineVaultAppState extends State<CineVaultApp> {
  late final _initialUri =
      Uri.tryParse(
        WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      ) ??
      Uri(path: '/');
  late final _delegate = _CineRouter(
    widget.performance,
    widget.startupWatch,
    parseCineRoute(_initialUri),
  );
  late final _provider = PlatformRouteInformationProvider(
    initialRouteInformation: RouteInformation(uri: _initialUri),
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
      widget.personal?.initialize();
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
      ChangeNotifierProvider(
        create: (_) => ArtworkPolicy(widget.catalogue.transport),
      ),
      ChangeNotifierProvider.value(value: widget.watchlist),
      if (widget.personal != null)
        ChangeNotifierProvider.value(value: widget.personal!),
      Provider(
        create: (_) => PersonalInsights(PersonalDiscovery(widget.catalogue)),
      ),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CineVault',
      theme: cineTheme(),
      builder: (_, child) =>
          _ShellOverlay(child: child ?? const SizedBox.shrink()),
      routeInformationParser: const _CineParser(),
      routeInformationProvider: _provider,
      routerDelegate: _delegate,
      backButtonDispatcher: RootBackButtonDispatcher(),
    ),
  );
}

/// The persistent navigation lives outside the page Navigator. Give its rail
/// tooltips a local overlay independent of the individual route overlays.
class _ShellOverlay extends StatefulWidget {
  const _ShellOverlay({required this.child});
  final Widget child;

  @override
  State<_ShellOverlay> createState() => _ShellOverlayState();
}

class _ShellOverlayState extends State<_ShellOverlay> {
  late final _entry = OverlayEntry(builder: (_) => widget.child);

  @override
  void didUpdateWidget(covariant _ShellOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != oldWidget.child) _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
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
  _Entry(
    this.id,
    this.route, {
    this.summary,
    this.heroTag,
    this.artwork,
    this.label,
    this.direct = false,
    PageStorageBucket? bucket,
  }) : bucket = bucket ?? PageStorageBucket();

  final int id;
  final CineRoute route;
  final Media? summary;
  final String? heroTag;
  final String? artwork;
  final String? label;
  final bool direct;
  final PageStorageBucket bucket;
}

class _HistoryEntry {
  const _HistoryEntry(this.id, this.stack, {this.parent});

  final int id;
  final List<_Entry> stack;
  final int? parent;
  AppTab get tab => (stack.first.route as TabRoute).tab;
}

class _CineRouter extends RouterDelegate<_Location>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<_Location> {
  _CineRouter(this._performance, this._startupWatch, CineRoute initial) {
    _active = _HistoryEntry(++_serial, _stackFor(initial));
    _history[_active.id] = _active;
    _remember(_active);
    if (initial is TabRoute && initial.tab == AppTab.search) {
      _lastSearch = initial;
    }
  }

  static const _shellKey = ValueKey('cinevault-shell');
  final AppPerformance _performance;
  final Stopwatch _startupWatch;
  final _history = <int, _HistoryEntry>{};
  final _branches = <AppTab, List<_Entry>>{};
  final _lastTab = <AppTab, AppTab>{};
  final _navigatorKeys = <AppTab, GlobalKey<NavigatorState>>{};
  final _heroControllers = <AppTab, HeroController>{};
  final _shellNavigator = GlobalKey<NavigatorState>();
  final _searchRequests = ValueNotifier<int>(0);
  late _HistoryEntry _active;
  var _lastSearch = const TabRoute(AppTab.search);
  int _serial = DateTime.now().microsecondsSinceEpoch;
  int _navigationRevision = 0;
  bool _shellPainted = false;
  bool _exiting = false;
  bool _disposed = false;

  @override
  GlobalKey<NavigatorState> get navigatorKey => _keyFor(_active.tab);

  GlobalKey<NavigatorState> _keyFor(AppTab tab) =>
      _navigatorKeys.putIfAbsent(tab, () => GlobalKey<NavigatorState>());

  @override
  _Location get currentConfiguration =>
      (route: _active.stack.last.route, historyId: _active.id);

  @override
  Future<void> setNewRoutePath(_Location configuration) async {
    final watch = Stopwatch()..start();
    final route = configuration.route;
    if (configuration.historyId == null &&
        _active.stack.last.route.uri == route.uri) {
      return;
    }
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
          _Entry(
            ++_serial,
            TabRoute(route is PersonalRoute ? AppTab.watchlist : AppTab.home),
          ),
          _Entry(++_serial, route, direct: true),
        ];

  void _replaceStack(List<_Entry> stack, Stopwatch watch, {int? parent}) =>
      _activate(_HistoryEntry(++_serial, stack, parent: parent), watch);

  void _activate(_HistoryEntry entry, Stopwatch? watch) {
    _active = entry;
    _remember(entry);
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

  void _remember(_HistoryEntry entry) {
    _branches[entry.tab] = entry.stack;
    _lastTab[entry.tab.destination] = entry.tab;
  }

  void _open(
    BuildContext context,
    CineRoute route, {
    Media? summary,
    String? heroTag,
    String? artwork,
    String? label,
  }) {
    if (_active.stack.last.route.uri == route.uri) return;
    final watch = Stopwatch()..start();
    Router.navigate(context, () {
      _replaceStack(
        [
          _active.stack.first,
          ..._active.stack.skip(
            (_active.stack.length - 78).clamp(1, _active.stack.length),
          ),
          _Entry(
            ++_serial,
            route,
            summary: summary,
            heroTag: heroTag,
            artwork: artwork,
            label: label ?? summary?.title,
          ),
        ],
        watch,
        parent: _active.id,
      );
    });
  }

  void _select(BuildContext context, AppTab tab) {
    _selectBranch(context, tab, reset: tab == _active.tab);
  }

  void _selectDestination(BuildContext context, AppTab destination) {
    final reselected = _active.tab.destination == destination;
    final tab = reselected ? destination : _lastTab[destination] ?? destination;
    if (reselected && tab != _active.tab) {
      _branches[_active.tab] = [_active.stack.first];
    }
    _selectBranch(context, tab, reset: reselected);
  }

  void _openSearch(BuildContext context) =>
      _selectBranch(context, AppTab.search, reset: true);

  void _selectBranch(BuildContext context, AppTab tab, {required bool reset}) {
    final route = tab == AppTab.search ? _lastSearch : TabRoute(tab);
    final current = _branches[tab];
    final branch = current ?? _stackFor(route);
    final stack = reset ? [branch.first] : branch;
    if (tab == _active.tab && stack.last.id == _active.stack.last.id) return;
    Router.navigate(
      context,
      () => _replaceStack(stack, Stopwatch()..start(), parent: _active.id),
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
        _HistoryEntry(_active.id, [
          _Entry(_active.stack.first.id, route),
        ], parent: _active.parent),
        null,
      );
    });
  }

  void _back(BuildContext context) {
    final stack = _active.stack;
    final previous = _history[_active.parent];
    if (kIsWeb &&
        stack.length > 1 &&
        previous != null &&
        previous.stack.length == stack.length - 1 &&
        previous.stack.last.id == stack[stack.length - 2].id) {
      goBrowserBack();
      return;
    }
    final watch = Stopwatch()..start();
    Router.neglect(context, () => _popStack(watch));
  }

  void _popStack(Stopwatch watch) {
    final stack = _active.stack;
    final previous = _history[_active.parent];
    if (previous != null &&
        ((stack.length == 1 && previous.tab != _active.tab) ||
            (stack.length > 1 &&
                previous.stack.last.id == stack[stack.length - 2].id))) {
      _activate(previous, watch);
      return;
    }
    final current = stack.last;
    final parent = current.direct
        ? switch (current.route) {
            final FilmographyRoute page => TitleRoute((
              kind: EntityKind.person,
              id: page.personId,
            )),
            final SeasonRoute page => TitleRoute((
              kind: EntityKind.tv,
              id: page.ref.seriesId,
            )),
            final EpisodeRoute page => SeasonRoute((
              seriesId: page.ref.seriesId,
              seasonNumber: page.ref.seasonNumber,
            )),
            _ => null,
          }
        : null;
    // Preserve the browser-visible history token when replacing a location.
    final next = parent != null
        ? [stack.first, _Entry(++_serial, parent, direct: true)]
        : stack.length > 1
        ? stack.sublist(0, stack.length - 1)
        : [
            _branches[AppTab.home]?.first ??
                _Entry(++_serial, const TabRoute(AppTab.home)),
          ];
    _activate(_HistoryEntry(_active.id, next), watch);
  }

  void _replace(BuildContext context, CineRoute route) {
    final active = _active;
    final previous = active.stack.last;
    if (previous.route.uri == route.uri ||
        previous.route.uri.path != route.uri.path) {
      return;
    }
    Router.neglect(
      context,
      () => _activate(
        _HistoryEntry(active.id, [
          ...active.stack.take(active.stack.length - 1),
          _Entry(
            previous.id,
            route,
            label: previous.label,
            direct: previous.direct,
            bucket: previous.bucket,
          ),
        ], parent: active.parent),
        null,
      ),
    );
  }

  @override
  Future<bool> popRoute() async {
    if (_shellNavigator.currentState case final shell? when shell.canPop()) {
      return shell.maybePop();
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null) return false;
    if (await navigator.maybePop()) return true;
    if (!navigator.mounted) return false;
    final previousTab = _history[_active.parent]?.tab;
    if (_active.stack.length > 1 ||
        _active.tab != AppTab.home ||
        (previousTab != null && previousTab != _active.tab)) {
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
    final current = _active.stack.last;
    return CineNavigation(
      open: _open,
      select: _select,
      selectDestination: _selectDestination,
      openSearch: _openSearch,
      updateSearch: _updateSearch,
      replace: _replace,
      back: _back,
      searchRequests: _searchRequests,
      child: Navigator(
        key: _shellNavigator,
        pages: [
          MaterialPage<void>(
            key: const ValueKey('persistent-cinevault-shell'),
            // The router owns Android Back, including the exit confirmation.
            // Keep the root Navigator eligible even when a hidden branch reports
            // that its own stack is at the root.
            child: PopScope<void>(
              canPop: false,
              child: ResponsiveShell(
                tab: root.tab,
                covered: _active.stack.length > 1,
                routeLabel:
                    current.label ??
                    switch (current.route) {
                      final TitleRoute route => entityLabel(route.ref.kind),
                      FilmographyRoute() => 'Filmography',
                      final SeasonRoute route =>
                        route.ref.seasonNumber == 0
                            ? 'Specials'
                            : 'Season ${route.ref.seasonNumber}',
                      final EpisodeRoute route =>
                        'Episode ${route.ref.episodeNumber}',
                      GenreRoute() => 'Genre',
                      final FeedRoute route => route.feed.label,
                      _ => null,
                    },
                onAbout: () {
                  final view = navigatorKey.currentState;
                  if (view != null) showCineAbout(view.context);
                },
                child: IndexedStack(
                  index: _branches.keys.toList().indexOf(_active.tab),
                  children: [
                    for (final entry in _branches.entries)
                      KeyedSubtree(
                        key: ValueKey(entry.key),
                        child: TickerMode(
                          enabled: entry.key == _active.tab,
                          child: ExcludeFocus(
                            excluding: entry.key != _active.tab,
                            child: HeroControllerScope(
                              controller: _heroControllers.putIfAbsent(
                                entry.key,
                                MaterialApp.createMaterialHeroController,
                              ),
                              child: _buildBranch(
                                context,
                                entry.key,
                                entry.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        onDidRemovePage: (_) {},
      ),
    );
  }

  Widget _buildBranch(BuildContext context, AppTab tab, List<_Entry> stack) {
    final active = tab == _active.tab;
    return Navigator(
      key: _keyFor(tab),
      pages: [
        MaterialPage<void>(
          key: _shellKey,
          child: ScrollWatch(
            area: tab.area,
            child: MainShell(
              tab: tab,
              searchRoute: _lastSearch,
              covered: !active || stack.length > 1,
            ),
          ),
        ),
        for (final (index, entry) in stack.indexed.skip(1))
          MaterialPage<void>(
            key: ValueKey(entry.id),
            maintainState: active && index >= stack.length - 5,
            child: PageStorage(
              bucket: entry.bucket,
              child: ScrollWatch(
                area: entry.route.area,
                child: _buildPage(context, entry),
              ),
            ),
          ),
      ],
      onDidRemovePage: (page) {
        final top = _active.stack.last;
        if (active &&
            tab == _active.tab &&
            _active.stack.length > 1 &&
            page.key == ValueKey(top.id)) {
          _back(context);
        }
      },
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
        final TitleRoute route when route.ref.kind == EntityKind.person =>
          PersonPage(
            ref: route.ref,
            heroTag: entry.heroTag,
            portrait: entry.artwork,
            previewName: entry.label,
          ),
        final TitleRoute route => CatalogueEntityPage(ref: route.ref),
        final FilmographyRoute route => FilmographyPage(route: route),
        final SeasonRoute route => SeasonPage(ref: route.ref),
        final EpisodeRoute route => EpisodePage(ref: route.ref),
        final GenreRoute route => GenrePage(ref: route.ref),
        final PersonalRoute route => PersonalPage(view: route.view),
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
    _searchRequests.dispose();
    for (final controller in _heroControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
