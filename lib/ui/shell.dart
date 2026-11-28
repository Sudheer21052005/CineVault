import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/navigation_scope.dart';
import '../app/route_contract.dart';
import '../core/material.dart';
import 'browse.dart';
import 'design_system.dart';
import 'library.dart';
import 'search.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    required this.tab,
    required this.searchRoute,
    required this.covered,
    super.key,
  });

  final AppTab tab;
  final TabRoute searchRoute;
  final bool covered;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _visited = <AppTab>{};

  @override
  Widget build(BuildContext context) {
    if (!widget.covered) _visited.add(widget.tab);
    return IndexedStack(
      index: widget.tab.index,
      children: [
        for (final tab in AppTab.values)
          TickerMode(
            enabled: tab == widget.tab && !widget.covered,
            child: HeroMode(
              enabled: tab == widget.tab,
              child: ExcludeFocus(
                excluding: tab != widget.tab,
                child: _visited.contains(tab)
                    ? switch (tab) {
                        AppTab.home => const HomePage(),
                        AppTab.discover => const DiscoverPage(),
                        AppTab.movies => const MoviesPage(),
                        AppTab.tv => const TvShowsPage(),
                        AppTab.nowPlaying => const NowPlayingPage(),
                        AppTab.search => SearchPage(
                          location: widget.searchRoute,
                        ),
                        AppTab.watchlist => const WatchlistPage(),
                        AppTab.stats => const StatisticsPage(),
                      }
                    : const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}

class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({
    required this.tab,
    required this.covered,
    required this.child,
    required this.onAbout,
    this.routeLabel,
    super.key,
  });
  final AppTab tab;
  final bool covered;
  final Widget child;
  final VoidCallback onAbout;
  final String? routeLabel;

  @override
  Widget build(BuildContext context) {
    final width = CineLayout.widthOf(context);
    final mobile = width == CineWidth.compact;
    final navigation = CineNavigation.of(context);
    void search() => navigation.focusSearch(context);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): search,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): search,
      },
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: Scaffold(
          bottomNavigationBar: mobile && !covered
              ? KeyedSubtree(
                  key: const ValueKey('mobile-bottom-nav'),
                  child: _BottomBar(active: tab),
                )
              : null,
          body: Row(
            children: [
              if (!mobile)
                KeyedSubtree(
                  key: ValueKey(
                    width == CineWidth.expanded
                        ? 'desktop-sidebar'
                        : 'tablet-rail',
                  ),
                  child: _SideBar(
                    active: tab,
                    expanded: width == CineWidth.expanded,
                    onAbout: onAbout,
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    if (!covered || !mobile)
                      _TopBar(
                        mobile: mobile,
                        active: tab,
                        routeLabel: routeLabel,
                        search: search,
                        back: covered && !mobile
                            ? () => navigation.back(context)
                            : null,
                      ),
                    Expanded(
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: !covered || !mobile,
                        removeBottom: mobile && !covered,
                        // Navigator route barriers must not hide the persistent
                        // navigation controls from the accessibility tree.
                        child: Semantics(
                          container: true,
                          explicitChildNodes: true,
                          child: child,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Destination = ({AppTab tab, String label, IconData icon});

const _home = (tab: AppTab.home, label: 'Home', icon: Icons.home_rounded);
const _discover = (
  tab: AppTab.discover,
  label: 'Discover',
  icon: Icons.explore_outlined,
);
const _search = (
  tab: AppTab.search,
  label: 'Search',
  icon: Icons.search_rounded,
);
const _library = (
  tab: AppTab.watchlist,
  label: 'Library',
  icon: Icons.bookmarks_outlined,
);
const _movies = (
  tab: AppTab.movies,
  label: 'Movies',
  icon: Icons.movie_creation_outlined,
);
const _tv = (tab: AppTab.tv, label: 'TV Shows', icon: Icons.tv_rounded);
const _now = (
  tab: AppTab.nowPlaying,
  label: 'Now Playing',
  icon: Icons.local_activity_outlined,
);
const _watchlist = (
  tab: AppTab.watchlist,
  label: 'Watchlist',
  icon: Icons.bookmark_border_rounded,
);
const _stats = (
  tab: AppTab.stats,
  label: 'Statistics',
  icon: Icons.bar_chart_rounded,
);

String _section(AppTab tab) => switch (tab) {
  AppTab.home => 'Home',
  AppTab.discover => 'Discover',
  AppTab.movies => 'Discover / Movies',
  AppTab.tv => 'Discover / TV Shows',
  AppTab.nowPlaying => 'Discover / Now Playing',
  AppTab.search => 'Search',
  AppTab.watchlist => 'Library / Watchlist',
  AppTab.stats => 'Library / Statistics',
};

AppTab _group(AppTab tab) => switch (tab) {
  AppTab.movies || AppTab.tv || AppTab.nowPlaying => AppTab.discover,
  AppTab.stats => AppTab.watchlist,
  _ => tab,
};

void _select(BuildContext context, AppTab tab) {
  final navigator = CineNavigation.of(context);
  if (tab == AppTab.search) {
    navigator.focusSearch(context);
  } else {
    navigator.select(context, tab);
  }
}

class CineBrand extends StatelessWidget {
  const CineBrand({this.markOnly = false, super.key});
  final bool markOnly;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SvgPicture.asset(
        'assets/images/branding/cinevault_emblem.svg',
        width: 30,
        height: 30,
        excludeFromSemantics: true,
      ),
      if (!markOnly) ...[
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            'CineVault',
            style: cineDisplay(23),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ],
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.mobile,
    required this.active,
    required this.search,
    this.back,
    this.routeLabel,
  });
  final bool mobile;
  final AppTab active;
  final VoidCallback search;
  final VoidCallback? back;
  final String? routeLabel;

  @override
  Widget build(BuildContext context) {
    final shortcut = Theme.of(context).platform == TargetPlatform.macOS
        ? '⌘ K'
        : 'Ctrl K';
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: canvas,
        border: Border(bottom: BorderSide(color: outline)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: CineLayout.gutterOf(context),
            vertical: mobile ? 7 : 10,
          ),
          child: Row(
            children: [
              if (back != null) ...[
                BackButton(onPressed: back),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: mobile
                    ? const CineBrand()
                    : Text(
                        routeLabel ?? _section(active),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
              ),
              if (mobile)
                IconButton(
                  onPressed: search,
                  tooltip: 'Global search',
                  icon: const Icon(Icons.search_rounded),
                )
              else
                SizedBox(
                  width: CineLayout.widthOf(context) == CineWidth.expanded
                      ? 324
                      : 260,
                  child: OutlinedButton(
                    onPressed: search,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: muted,
                        ),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: Text(
                            'Search titles',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(shortcut, style: cineLabel(size: 10)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.active,
    required this.expanded,
    required this.onAbout,
  });
  final AppTab active;
  final bool expanded;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: expanded ? 220 : 76,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: surface,
        border: Border(right: BorderSide(color: outline)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                expanded ? 20 : 10,
                18,
                expanded ? 15 : 10,
                20,
              ),
              child: Align(
                alignment: expanded ? Alignment.centerLeft : Alignment.center,
                child: CineBrand(markOnly: !expanded),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: expanded ? 11 : 8),
                children: expanded
                    ? [
                        for (final destination in [_home, _discover, _search])
                          _row(context, destination),
                        const _SideLabel('Catalogue'),
                        for (final destination in [_movies, _tv, _now])
                          _row(context, destination),
                        const _SideLabel('Your library'),
                        for (final destination in [_watchlist, _stats])
                          _row(context, destination),
                      ]
                    : [
                        for (final destination in [
                          _home,
                          _discover,
                          _search,
                          _library,
                        ])
                          _row(context, destination),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(),
                        ),
                        for (final destination in [_movies, _tv, _now, _stats])
                          _row(context, destination),
                      ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(11),
              child: Builder(
                builder: (context) => _NavButton(
                  label: 'About CineVault',
                  icon: Icons.info_outline_rounded,
                  selected: false,
                  compact: !expanded,
                  onTap: onAbout,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _row(BuildContext context, _Destination target) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: _NavButton(
      label: target.label,
      icon: target.icon,
      compact: !expanded,
      selected: target.tab == active,
      onTap: () => _select(context, target.tab),
    ),
  );
}

class _SideLabel extends StatelessWidget {
  const _SideLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(11, 21, 0, 8),
    child: Text(text.toUpperCase(), style: cineLabel(size: 10)),
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    final color = selected ? blue : muted;
    final card = Material(
      color: selected ? const Color(0xFF192E50) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? const Color(0xFF294B7D) : Colors.transparent,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        focusColor: blue.withValues(alpha: .3),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 47),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 0 : 12,
              vertical: 10,
            ),
            child: compact
                ? Center(child: Icon(icon, color: color, size: 23))
                : Row(
                    children: [
                      Icon(icon, color: color, size: 21),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected ? ink : muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: compact
          ? Tooltip(message: label, excludeFromSemantics: true, child: card)
          : card,
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.active});
  final AppTab active;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: surface,
      border: Border(top: BorderSide(color: outline)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: Row(
          children: [
            for (final tab in [_home, _discover, _search, _library])
              Expanded(
                child: _BottomItem(tab: tab, active: _group(active) == tab.tab),
              ),
          ],
        ),
      ),
    ),
  );
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({required this.tab, required this.active});
  final _Destination tab;
  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: active,
    button: true,
    label: tab.label,
    onTap: () => _select(context, tab.tab),
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: active ? const Color(0xFF192E50) : Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _select(context, tab.tab),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(5, 6, 5, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, size: 23, color: active ? blue : muted),
                const SizedBox(height: 3),
                SizedBox(
                  height: 15,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tab.label,
                      style: TextStyle(
                        color: active ? ink : muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
