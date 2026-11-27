import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

import 'app/navigation_scope.dart';
import 'app/route_contract.dart';
import 'catalogue/catalogue_repository.dart';
import 'catalogue/entity_ref.dart';
import 'catalogue/paged_controller.dart';
import 'core/material.dart';
import 'core/network/tmdb_transport.dart';
import 'core/performance.dart';
import 'models/media.dart';
import 'models/watchlist_item.dart';
import 'providers/watchlist_provider.dart';

class LruCache<K, V> {
  final int maxSize;
  final Map<K, V> _map = <K, V>{};
  LruCache({required this.maxSize});
  V? get(K key) => _map[key];
  void put(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    if (_map.length > maxSize) {
      _map.remove(_map.keys.first);
    }
  }
}

const canvas = Color(0xFF0B0D12);
const surface = Color(0xFF121722);
const elevated = Color(0xFF192131);
const secondary = Color(0xFF202A3A);
const primary = Color(0xFF3B82F6);
const bright = Color(0xFF60A5FA);
const gold = Color(0xFFF4C95D);
const muted = Color(0xFFA8B1C2);
const watched = Color(0xFF39B982);
const watching = Color(0xFFE9A23B);

final _ambientColorCache = LruCache<String, Color>(maxSize: 50);

ThemeData cineTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: canvas,
  colorScheme: const ColorScheme.dark(primary: primary, surface: surface),
  fontFamily: 'Poppins',
  cardColor: surface,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: primary),
    ),
  ),
  appBarTheme: const AppBarTheme(backgroundColor: canvas, elevation: 0),
);

class CompactBottomNav extends StatelessWidget {
  const CompactBottomNav({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home',
      ),
      _NavItem(
        icon: Icons.local_movies_outlined,
        activeIcon: Icons.local_movies,
        label: 'Now Playing',
      ),
      _NavItem(
        icon: Icons.tv_outlined,
        activeIcon: Icons.tv,
        label: 'TV Shows',
      ),
      _NavItem(icon: Icons.search, activeIcon: Icons.search, label: 'Search'),
      _NavItem(
        icon: Icons.bookmark_border,
        activeIcon: Icons.bookmark,
        label: 'Watchlist',
      ),
      _NavItem(
        icon: Icons.insights_outlined,
        activeIcon: Icons.insights,
        label: 'Stats',
      ),
    ];

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: surface,
          border: Border(top: BorderSide(color: secondary, width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: List.generate(destinations.length, (index) {
            final item = destinations[index];
            final isActive = index == currentIndex;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(index),
                borderRadius: BorderRadius.zero,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? secondary : Colors.transparent,
                    border: Border(
                      top: BorderSide(
                        color: isActive ? primary : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        size: 22,
                        color: isActive ? bright : muted,
                      ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isActive ? bright : muted,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

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
    _visited.add(widget.tab);
    final navigation = CineNavigation.of(context);
    return Scaffold(
      body: IndexedStack(
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
                          AppTab.nowPlaying => const NowPlayingPage(),
                          AppTab.tv => const TvShowsPage(),
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
      ),
      bottomNavigationBar: CompactBottomNav(
        currentIndex: widget.tab.index,
        onTap: (index) => navigation.select(context, AppTab.values[index]),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _heroKey = GlobalKey<_HeroCarouselState>();
  final _recommendationsKey = GlobalKey<_RecommendationsSectionState>();
  final _shelves = {
    for (final feed in const [
      CatalogueFeed.trending,
      CatalogueFeed.popular,
      CatalogueFeed.nowPlaying,
      CatalogueFeed.recent,
      CatalogueFeed.upcoming,
      CatalogueFeed.topRated,
      CatalogueFeed.tvPopular,
      CatalogueFeed.tvToday,
      CatalogueFeed.tvOnAir,
    ])
      feed: GlobalKey<_PagedHorizontalSectionState>(),
  };

  Future<void> _onRefresh() => Future.wait<void>([
    if (_heroKey.currentState case final hero?) hero.refresh(),
    for (final key in _shelves.values)
      if (key.currentState case final shelf?) shelf.refresh(),
    if (_recommendationsKey.currentState case final shelf?) shelf.refresh(),
  ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: canvas,
    body: RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(0),
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: canvas,
            automaticallyImplyLeading: false,
            toolbarHeight: 56,
            titleSpacing: 16,
            title: Row(
              children: [
                SvgPicture.asset(
                  'assets/images/branding/cinevault_emblem.svg',
                  width: 26,
                  height: 26,
                ),
                const SizedBox(width: 8),
                const Text(
                  'CineVault',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () {
                  CineNavigation.of(context).select(context, AppTab.search);
                },
                icon: const Icon(Icons.search_rounded, size: 24),
                tooltip: 'Search',
                style: IconButton.styleFrom(
                  backgroundColor: surface,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList.list(
              children: [
                HeroCarousel(key: _heroKey),
                const SizedBox(height: 16),
                const Text(
                  'Explore genres',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      GenreChip(label: 'Action', genreId: 28),
                      GenreChip(label: 'Adventure', genreId: 12),
                      GenreChip(label: 'Comedy', genreId: 35),
                      GenreChip(label: 'Drama', genreId: 18),
                      GenreChip(label: 'Horror', genreId: 27),
                      GenreChip(label: 'Romance', genreId: 10749),
                      GenreChip(label: 'Sci-Fi', genreId: 878),
                      GenreChip(label: 'Thriller', genreId: 53),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverList.builder(
            itemCount: _shelves.length + 1,
            itemBuilder: (context, index) {
              if (index == _shelves.length) {
                return RecommendationsSection(key: _recommendationsKey);
              }
              final feed = _shelves.keys.elementAt(index);
              return PagedHorizontalSection(key: _shelves[feed], feed: feed);
            },
          ),
        ],
      ),
    ),
  );
}

class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key});
  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final controller = PageController();
  late Future<List<Media>> future;
  Timer? autoAdvance;
  int page = 0;
  List<Media> items = [];
  Color? _ambientColor;
  bool _firstAmbientLoaded = false;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<Media>> _load({bool refresh = false}) async =>
      (await context.read<CatalogueRepository>().browseFeed(
        CatalogueFeed.popular,
        refresh: refresh,
      )).items;

  Future<void> refresh() async {
    final request = _load(refresh: true);
    setState(() => future = request);
    try {
      await request;
    } catch (_) {
      // FutureBuilder renders the error and a fresh retry action.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    autoAdvance?.cancel();
    if (TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      autoAdvance = Timer.periodic(const Duration(seconds: 6), (_) {
        if (items.length < 2 || !controller.hasClients) return;
        controller.animateToPage(
          (page + 1) % items.length,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    autoAdvance?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _updateAmbientColor(Media media) async {
    if (media.backdropPath == null) {
      if (mounted) setState(() => _ambientColor = null);
      return;
    }
    final cacheKey = media.key;
    final cached = _ambientColorCache.get(cacheKey);
    if (cached != null) {
      if (mounted) setState(() => _ambientColor = cached);
      return;
    }
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(
          '${CatalogueRepository.backdropBase}${media.backdropPath}',
        ),
        maximumColorCount: 16,
      );
      final color =
          palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          palette.mutedColor?.color ??
          palette.darkVibrantColor?.color;
      if (color != null) {
        final adjusted = Color.fromRGBO(
          (color.r * 0.15).round(),
          (color.g * 0.15).round(),
          (color.b * 0.15).round(),
          1.0,
        );
        _ambientColorCache.put(cacheKey, adjusted);
        if (mounted && items.elementAtOrNull(page)?.key == cacheKey) {
          setState(() => _ambientColor = adjusted);
        }
      }
    } catch (_) {
      if (mounted && items.elementAtOrNull(page)?.key == cacheKey) {
        setState(() => _ambientColor = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Media>>(
    future: future,
    builder: (_, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting &&
          items.isEmpty) {
        return const SkeletonBox(height: 220);
      }
      if (snapshot.hasError && items.isEmpty) {
        return Container(
          height: 180,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: secondary),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, color: muted, size: 36),
                const SizedBox(height: 8),
                const Text(
                  'Unable to load featured movies',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    refresh();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      if (snapshot.hasData) {
        items = snapshot.data!.take(5).toList();
      }
      if (items.isEmpty) return const SizedBox.shrink();
      if (!_firstAmbientLoaded && items.isNotEmpty) {
        _firstAmbientLoaded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateAmbientColor(items[0]);
        });
      }
      return SizedBox(
        height: 220,
        child: Stack(
          children: [
            if (_ambientColor != null)
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.2,
                      colors: [_ambientColor!.withValues(alpha: 0.4), canvas],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                ),
              ),
            PageView.builder(
              controller: controller,
              itemCount: items.length,
              onPageChanged: (value) {
                setState(() => page = value);
                if (items.elementAtOrNull(value) case final media?) {
                  _updateAmbientColor(media);
                }
              },
              itemBuilder: (_, index) {
                final media = items[index];
                return GestureDetector(
                  onTap: () =>
                      CineNavigation.of(context).openTitle(context, media),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        media.backdropPath == null
                            ? Container(color: elevated)
                            : Image.network(
                                '${CatalogueRepository.backdropBase}${media.backdropPath}',
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Container(color: elevated),
                              ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                canvas.withValues(alpha: 0.85),
                                canvas.withValues(alpha: 0.95),
                              ],
                              stops: const [0.3, 0.7, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'FEATURED',
                                style: TextStyle(
                                  color: bright,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                media.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${media.year}  \u00B7  ${media.rating.toStringAsFixed(1)} \u2605',
                                style: const TextStyle(
                                  color: gold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.tonalIcon(
                                onPressed: () =>
                                    CineNavigation.of(context)
                                        .openTitle(context, media),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 15,
                                ),
                                label: const Text('View details'),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: surface.withValues(
                                    alpha: 0.9,
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Consumer<WatchlistProvider>(
                            builder: (_, provider, _) {
                              final saved =
                                  provider.find(media.id, media.type) != null;
                              return IconButton(
                                tooltip: saved
                                    ? 'Already in watchlist'
                                    : 'Add to watchlist',
                                style: IconButton.styleFrom(
                                  backgroundColor: canvas.withValues(
                                    alpha: 0.7,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                ),
                                onPressed: saved
                                    ? null
                                    : () => _save(context, media),
                                icon: Icon(
                                  saved
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  size: 20,
                                ),
                              );
                            },
                          ),
                        ),
                        if (items.length > 1) ...[
                          Positioned(
                            left: 8,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: IconButton(
                                tooltip: 'Previous featured title',
                                style: IconButton.styleFrom(
                                  backgroundColor: canvas.withValues(
                                    alpha: 0.6,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                ),
                                onPressed: () => controller.previousPage(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOutCubic,
                                ),
                                icon: const Icon(Icons.chevron_left, size: 22),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: IconButton(
                                tooltip: 'Next featured title',
                                style: IconButton.styleFrom(
                                  backgroundColor: canvas.withValues(
                                    alpha: 0.6,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                ),
                                onPressed: () => controller.nextPage(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOutCubic,
                                ),
                                icon: const Icon(Icons.chevron_right, size: 22),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    items.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == page ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: index == page ? bright : muted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (snapshot.hasError)
              Positioned(
                top: 8,
                left: 8,
                child: FilledButton.tonal(
                  onPressed: refresh,
                  child: const Text('Retry featured titles'),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class GenreChip extends StatelessWidget {
  const GenreChip({required this.label, required this.genreId, super.key});
  final String label;
  final int genreId;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.local_movies_outlined, size: 15),
      onPressed: () => CineNavigation.of(context).open(
        context,
        GenreRoute((kind: MediaKind.movie, id: genreId)),
        label: '$label movies',
      ),
    ),
  );
}

class FilterField<T> extends StatelessWidget {
  const FilterField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });
  final String label;
  final T? value;
  final List<DropdownMenuItem<T?>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(14, 8, 8, 2),
    decoration: BoxDecoration(
      color: elevated,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: secondary),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T?>(
        value: value,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        dropdownColor: elevated,
        items: items,
        onChanged: onChanged,
        selectedItemBuilder: (_) => items
            .map(
              (item) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  DefaultTextStyle.merge(child: item.child),
                ],
              ),
            )
            .toList(),
      ),
    ),
  );
}

class PagedHorizontalSection extends StatefulWidget {
  const PagedHorizontalSection({required this.feed, this.title, super.key});

  final CatalogueFeed feed;
  final String? title;

  @override
  State<PagedHorizontalSection> createState() => _PagedHorizontalSectionState();
}

class _PagedHorizontalSectionState extends State<PagedHorizontalSection>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _pages = PagedController();

  String get _title => widget.title ?? widget.feed.label;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pages.setQuery(
      context.read<CatalogueRepository>().feedLoader(widget.feed),
    );
    _scroll.addListener(() {
      if (_scroll.position.extentAfter <=
          _scroll.position.viewportDimension * .65) {
        unawaited(_pages.loadNext());
      }
    });
  }

  Future<void> refresh() => _pages.refresh();

  @override
  void dispose() {
    _scroll.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: _pages,
      builder: (context, _) {
        final state = _pages.state;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      CineNavigation.of(context)
                          .open(context, FeedRoute(widget.feed), label: _title),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.status == PageStatus.loading)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              if (state.status == PageStatus.refreshing)
                const LinearProgressIndicator(),
              if (state.error != null)
                MessageState(
                  message: _catalogueMessage(state.error),
                  onRetry: refresh,
                ),
              if (state.items.isEmpty && state.status == PageStatus.ready)
                const MessageState(message: 'No titles available right now.'),
              if (state.items.isNotEmpty)
                SizedBox(
                  height: 250,
                  child: ListView.separated(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    itemCount:
                        state.items.length +
                        (state.loadingNext || state.nextError != null ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, index) => index == state.items.length
                        ? Center(child: _nextPageAction(_pages, state))
                        : MediaCard(
                            media: state.items[index],
                            heroTag: '$_title-${state.items[index].key}',
                          ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) => DiscoveryPage(
    title: 'Now Playing',
    loader: context.read<CatalogueRepository>().feedLoader(
      CatalogueFeed.nowPlaying,
    ),
  );
}

class TvShowsPage extends StatelessWidget {
  const TvShowsPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: const [
      Text(
        'TV Shows',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
      SizedBox(height: 18),
      PagedHorizontalSection(feed: CatalogueFeed.tvPopular, title: 'Popular'),
      PagedHorizontalSection(feed: CatalogueFeed.tvToday),
      PagedHorizontalSection(feed: CatalogueFeed.tvTopRated),
    ],
  );
}

class RecommendationsSection extends StatefulWidget {
  const RecommendationsSection({super.key});

  @override
  State<RecommendationsSection> createState() => _RecommendationsSectionState();
}

class _RecommendationsSectionState extends State<RecommendationsSection> {
  EntityRef? _seed;
  Future<List<Media>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final item = context.watch<WatchlistProvider>().items.firstOrNull;
    final kind = MediaKind.parse(item?.type);
    final seed = item == null || kind == null
        ? null
        : (kind: kind.entityKind, id: item.id);
    if (seed == _seed) return;
    _seed = seed;
    _future = seed == null
        ? null
        : context.read<CatalogueRepository>().related(seed);
  }

  Future<void> refresh() async {
    final seed = _seed;
    if (seed == null) return;
    final future = context.read<CatalogueRepository>().related(
      seed,
      refresh: true,
    );
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // This optional Home shelf can be retried on the next Home refresh.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_seed == null) return const SizedBox.shrink();
    final library = context.read<WatchlistProvider>();
    return FutureBuilder<List<Media>>(
      future: _future,
      builder: (_, snapshot) {
        final items = (snapshot.data ?? const <Media>[])
            .where((item) => library.find(item.id, item.type) == null)
            .take(8)
            .toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 22),
            const Text(
              'Picked for your collection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Based on titles you saved',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 235,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) => MediaCard(
                  media: items[index],
                  heroTag: 'recommendations-${items[index].key}',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({required this.title, required this.loader, super.key});

  final String title;
  final PageLoader loader;

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final _pages = PagedController();

  @override
  void initState() {
    super.initState();
    _pages.setQuery(widget.loader);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: canvas,
    appBar: AppBar(
      backgroundColor: canvas,
      leading: BackButton(
        onPressed: () => CineNavigation.of(context).back(context),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _pages.refresh,
      child: _PagedViewport(
        pages: _pages,
        cardWidth: 190,
        cardHeight: 300,
        heroPrefix: widget.title,
        emptyMessage: 'No titles available.',
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select a title to view its details.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    ),
  );
}

class _PagedViewport extends StatelessWidget {
  const _PagedViewport({
    required this.pages,
    required this.header,
    required this.heroPrefix,
    required this.emptyMessage,
    required this.cardWidth,
    required this.cardHeight,
    this.scroll,
    this.onFirstPaint,
    this.idleMessage,
  });

  final PagedController pages;
  final Widget header;
  final ScrollController? scroll;
  final VoidCallback? onFirstPaint;
  final String heroPrefix;
  final String emptyMessage;
  final String? idleMessage;
  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: pages,
    builder: (context, _) {
      final state = pages.state;
      if (state.status == PageStatus.ready ||
          state.status == PageStatus.failed) {
        if (onFirstPaint != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onFirstPaint!());
        }
      }
      return NotificationListener<ScrollNotification>(
        onNotification: (event) {
          if (event.depth == 0 &&
              event.metrics.axis == Axis.vertical &&
              (event is ScrollUpdateNotification ||
                  event is ScrollEndNotification) &&
              event.metrics.extentAfter < 500) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) unawaited(pages.loadNext());
            });
          }
          return false;
        },
        child: CustomScrollView(
          controller: scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                idleMessage == null ? 8 : 20,
                20,
                0,
              ),
              sliver: SliverToBoxAdapter(child: header),
            ),
            if (state.status == PageStatus.idle && idleMessage != null)
              SliverToBoxAdapter(child: MessageState(message: idleMessage!)),
            if (state.status == PageStatus.loading ||
                state.status == PageStatus.refreshing)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (state.error != null)
              SliverToBoxAdapter(
                child: MessageState(
                  message: _catalogueMessage(state.error),
                  onRetry: pages.refresh,
                ),
              ),
            if (state.items.isEmpty && state.status == PageStatus.ready)
              SliverToBoxAdapter(child: MessageState(message: emptyMessage)),
            if (state.items.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverGrid.builder(
                  itemCount: state.items.length,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: cardWidth,
                    mainAxisExtent: cardHeight,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 20,
                  ),
                  itemBuilder: (_, index) {
                    final item = state.items[index];
                    return MediaCard(
                      media: item,
                      heroTag: '$heroPrefix-${item.key}',
                    );
                  },
                ),
              ),
            if (state.loadingNext ||
                state.nextError != null ||
                (state.hasMore &&
                    state.items.isEmpty &&
                    state.status == PageStatus.ready))
              SliverToBoxAdapter(
                child: Center(child: _nextPageAction(pages, state)),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
        ),
      );
    },
  );
}

Widget _nextPageAction(PagedController pages, PageState state) {
  if (state.loadingNext) {
    return const Padding(
      padding: EdgeInsets.all(14),
      child: SizedBox.square(
        dimension: 26,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
  return TextButton(
    onPressed: () => pages.loadNext(retry: state.nextError != null),
    child: Text(state.nextError == null ? 'Load more' : 'Retry loading more'),
  );
}

String _catalogueMessage(Object? error) => error is TmdbException
    ? error.toString()
    : 'Unable to load catalogue data. Please retry.';

class SearchPage extends StatefulWidget {
  const SearchPage({required this.location, super.key});

  final TabRoute location;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final _pages = PagedController(
    onFirstPage: (success) {
      _firstOutcome = success ? PerfOutcome.success : PerfOutcome.failure;
    },
  );
  late TabRoute _location;
  Stopwatch? _inputWatch;
  PerfOutcome? _firstOutcome;

  @override
  void initState() {
    super.initState();
    _setLocation(widget.location, immediate: true);
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.location.uri != _location.uri) {
      _setLocation(widget.location, immediate: true);
    }
  }

  void _setLocation(
    TabRoute location, {
    required bool immediate,
    bool synchronize = true,
  }) {
    _location = location;
    if (synchronize && _text.text != location.text) {
      _text.value = TextEditingValue(
        text: location.text,
        selection: TextSelection.collapsed(offset: location.text.length),
      );
    }
    final repository = context.read<CatalogueRepository>();
    final filters = location.discovery;
    final query = location.text.trim();
    _firstOutcome = null;
    if (filters == null && query.isEmpty) {
      _inputWatch = null;
      _pages.setQuery(null);
      return;
    }
    _inputWatch = Stopwatch()..start();
    context.read<AppPerformance>().record(
      const PerfSample(
        PerfEvent.searchInput,
        Duration.zero,
        area: PerfArea.search,
      ),
    );
    if (filters != null) {
      _pages.setQuery(
        (page, {required refresh}) =>
            repository.discover(filters, page: page, refresh: refresh),
      );
    } else {
      _pages.setQuery(
        (page, {required refresh}) => repository.search(
          query,
          location.scope,
          page: page,
          refresh: refresh,
        ),
        debounce: immediate ? Duration.zero : const Duration(milliseconds: 300),
      );
    }
  }

  void _apply(
    TabRoute location, {
    bool immediate = true,
    bool synchronize = true,
  }) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(
      () => _setLocation(
        location,
        immediate: immediate,
        synchronize: synchronize,
      ),
    );
    CineNavigation.of(context).updateSearch(context, location);
  }

  void _search(String text, {bool immediate = false}) {
    final location = TabRoute(
      AppTab.search,
      text: text.trim(),
      scope: _location.scope,
    );
    if (!immediate && location.uri == _location.uri) return;
    _apply(location, immediate: immediate, synchronize: false);
  }

  void _markFirstPaint() {
    final started = _inputWatch;
    final outcome = _firstOutcome;
    if (!mounted || started == null || outcome == null) return;
    _inputWatch = null;
    context.read<AppPerformance>().record(
      PerfSample(
        _location.discovery == null
            ? PerfEvent.searchResults
            : PerfEvent.searchDiscovery,
        started.elapsed,
        area: PerfArea.search,
        outcome: outcome,
      ),
    );
  }

  Future<void> _openFilters() async {
    final repository = context.read<CatalogueRepository>();
    var browse = _location.discovery != null;
    var scope = _location.scope;
    DiscoveryQuery filters = _location.discovery ?? defaultDiscovery;
    Future<List<Genre>>? genres = browse
        ? repository.genres(filters.kind)
        : null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: secondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Search options',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setSheet(() {
                        scope = SearchScope.all;
                        filters = defaultDiscovery;
                        if (browse) genres = repository.genres(filters.kind);
                      }),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilterField<bool>(
                  label: 'MODE',
                  value: browse,
                  items: const [
                    DropdownMenuItem(
                      value: false,
                      child: Text('Search by title'),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text('Browse by filters'),
                    ),
                  ],
                  onChanged: (value) => setSheet(() {
                    browse = value ?? false;
                    if (browse) genres = repository.genres(filters.kind);
                  }),
                ),
                if (!browse)
                  FilterField<SearchScope>(
                    label: 'TITLE SCOPE',
                    value: scope,
                    items: const [
                      DropdownMenuItem(
                        value: SearchScope.all,
                        child: Text('All titles'),
                      ),
                      DropdownMenuItem(
                        value: SearchScope.movie,
                        child: Text('Movies'),
                      ),
                      DropdownMenuItem(
                        value: SearchScope.tv,
                        child: Text('TV shows'),
                      ),
                    ],
                    onChanged: (value) =>
                        setSheet(() => scope = value ?? scope),
                  )
                else ...[
                  FilterField<MediaKind>(
                    label: 'CONTENT TYPE',
                    value: filters.kind,
                    items: const [
                      DropdownMenuItem(
                        value: MediaKind.movie,
                        child: Text('Movies'),
                      ),
                      DropdownMenuItem(
                        value: MediaKind.tv,
                        child: Text('TV shows'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null || value == filters.kind) return;
                      setSheet(() {
                        filters = (
                          kind: value,
                          genre: null,
                          year: filters.year,
                          minimumRating: filters.minimumRating,
                          sort: filters.sort,
                        );
                        genres = repository.genres(value);
                      });
                    },
                  ),
                  FutureBuilder<List<Genre>>(
                    future: genres,
                    builder: (_, snapshot) {
                      final list =
                          snapshot.connectionState == ConnectionState.done
                          ? snapshot.data ?? const <Genre>[]
                          : const <Genre>[];
                      final selected = filters.genre;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilterField<int>(
                            label: 'GENRE',
                            value: selected,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All genres'),
                              ),
                              if (selected != null &&
                                  !list.any((item) => item.id == selected))
                                DropdownMenuItem(
                                  value: selected,
                                  child: const Text('Selected genre'),
                                ),
                              for (final genre in list)
                                DropdownMenuItem(
                                  value: genre.id,
                                  child: Text(genre.name),
                                ),
                            ],
                            onChanged: (value) => setSheet(
                              () => filters = (
                                kind: filters.kind,
                                genre: value,
                                year: filters.year,
                                minimumRating: filters.minimumRating,
                                sort: filters.sort,
                              ),
                            ),
                          ),
                          if (snapshot.hasError)
                            TextButton(
                              onPressed: () => setSheet(
                                () => genres = repository.genres(
                                  filters.kind,
                                  refresh: true,
                                ),
                              ),
                              child: const Text('Retry loading genres'),
                            ),
                        ],
                      );
                    },
                  ),
                  FilterField<int>(
                    label: filters.kind == MediaKind.tv
                        ? 'FIRST AIR YEAR'
                        : 'RELEASE YEAR',
                    value: filters.year,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Any year'),
                      ),
                      for (final year in {
                        ...List.generate(
                          12,
                          (index) => DateTime.now().year - index,
                        ),
                        if (filters.year != null) filters.year!,
                      })
                        DropdownMenuItem(value: year, child: Text('$year')),
                    ],
                    onChanged: (value) => setSheet(
                      () => filters = (
                        kind: filters.kind,
                        genre: filters.genre,
                        year: value,
                        minimumRating: filters.minimumRating,
                        sort: filters.sort,
                      ),
                    ),
                  ),
                  FilterField<double>(
                    label: 'MINIMUM RATING',
                    value: filters.minimumRating,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Any rating'),
                      ),
                      for (final value in {
                        6.0,
                        7.0,
                        8.0,
                        9.0,
                        if (filters.minimumRating != null)
                          filters.minimumRating!,
                      })
                        DropdownMenuItem(value: value, child: Text('$value+')),
                    ],
                    onChanged: (value) => setSheet(
                      () => filters = (
                        kind: filters.kind,
                        genre: filters.genre,
                        year: filters.year,
                        minimumRating: value,
                        sort: filters.sort,
                      ),
                    ),
                  ),
                  FilterField<CatalogueSort>(
                    label: 'SORT BY',
                    value: filters.sort,
                    items: [
                      for (final sort in CatalogueSort.values)
                        DropdownMenuItem(value: sort, child: Text(sort.label)),
                    ],
                    onChanged: (value) => setSheet(
                      () => filters = (
                        kind: filters.kind,
                        genre: filters.genre,
                        year: filters.year,
                        minimumRating: filters.minimumRating,
                        sort: value ?? filters.sort,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final location = TabRoute(
                        AppTab.search,
                        text: browse ? '' : _text.text.trim(),
                        scope: scope,
                        discovery: browse ? filters : null,
                      );
                      Navigator.pop(sheetContext);
                      _apply(location);
                    },
                    child: Text(
                      browse ? 'Apply filters' : 'Apply search scope',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = _location.discovery;
    final hint = switch (_location.scope) {
      SearchScope.all => 'Search movies and TV shows',
      SearchScope.movie => 'Search movies',
      SearchScope.tv => 'Search TV shows',
    };
    return _PagedViewport(
      pages: _pages,
      scroll: _scroll,
      onFirstPaint: _markFirstPaint,
      cardWidth: 180,
      cardHeight: 270,
      heroPrefix: 'search',
      idleMessage: 'Search the TMDB catalogue to find your next story.',
      emptyMessage: filters == null
          ? 'No matching titles found.'
          : 'No titles match these discovery filters.',
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            onChanged: _search,
            onSubmitted: (value) => _search(value, immediate: true),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Search options',
                    onPressed: _openFilters,
                    icon: Icon(
                      filters == null && _location.scope == SearchScope.all
                          ? Icons.filter_alt_outlined
                          : Icons.filter_alt,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear search',
                    onPressed: () =>
                        _apply(TabRoute(AppTab.search, scope: _location.scope)),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
          if (filters != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                filters.kind == MediaKind.movie
                    ? 'Browsing movies'
                    : 'Browsing TV shows',
                style: const TextStyle(color: muted),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class WatchlistPage extends StatefulWidget {
  const WatchlistPage({super.key});
  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  final searchController = TextEditingController();
  WatchStatus? status;
  String sort = 'recent';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String _statusLabel(WatchStatus value) => switch (value) {
    WatchStatus.planToWatch => 'Plan to Watch',
    WatchStatus.watching => 'Watching',
    WatchStatus.watched => 'Watched',
  };

  Future<void> _edit(BuildContext context, WatchlistItem item) async {
    final notes = TextEditingController(text: item.notes);
    final review = TextEditingController(text: item.review);
    var selectedStatus = item.status;
    var saving = false;
    String? writeError;
    double? rating = item.userRating;
    DateTime? watchedDate = item.dateWatched;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) {
          final provider = sheetContext.read<WatchlistProvider>();
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit ${item.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<WatchStatus>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Viewing status',
                  ),
                  items: WatchStatus.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_statusLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(() {
                    if (value == WatchStatus.watched &&
                        selectedStatus != value) {
                      watchedDate ??= DateTime.now();
                    }
                    selectedStatus = value ?? selectedStatus;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<double?>(
                  initialValue: rating,
                  decoration: const InputDecoration(
                    labelText: 'Personal rating',
                  ),
                  items:
                      <double?>[
                            null,
                            0.5,
                            1.0,
                            1.5,
                            2.0,
                            2.5,
                            3.0,
                            3.5,
                            4.0,
                            4.5,
                            5.0,
                            if (rating != null &&
                                !const [
                                  0.5,
                                  1.0,
                                  1.5,
                                  2.0,
                                  2.5,
                                  3.0,
                                  3.5,
                                  4.0,
                                  4.5,
                                  5.0,
                                ].contains(rating))
                              rating,
                          ]
                          .map(
                            (value) => DropdownMenuItem<double?>(
                              value: value,
                              child: Text(
                                value == null
                                    ? 'Not rated'
                                    : '$value / 5 \u2605',
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setSheetState(() => rating = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: review,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Personal review',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: sheetContext,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                          initialDate: watchedDate ?? DateTime.now(),
                        );
                        if (picked != null && sheetContext.mounted) {
                          setSheetState(() => watchedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        watchedDate == null
                            ? 'Set date watched'
                            : 'Watched ${watchedDate!.day}/${watchedDate!.month}/${watchedDate!.year}',
                      ),
                    ),
                    if (watchedDate != null)
                      IconButton(
                        tooltip: 'Clear watched date',
                        onPressed: () =>
                            setSheetState(() => watchedDate = null),
                        icon: const Icon(Icons.clear),
                      ),
                  ],
                ),
                if (writeError != null) MessageState(message: writeError!),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final edit = (
                              status: selectedStatus,
                              rating: rating,
                              notes: notes.text.trim(),
                              review: review.text.trim(),
                              watchedDate: watchedDate,
                            );
                            setSheetState(() {
                              saving = true;
                              writeError = null;
                            });
                            try {
                              await provider.update(item, edit);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            } catch (_) {
                              if (!sheetContext.mounted) return;
                              setSheetState(() {
                                saving = false;
                                writeError = 'Unable to save changes. Your previous entry is still available.';
                              });
                            }
                          },
                    child: Text(saving ? 'Saving…' : 'Save changes'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    notes.dispose();
    review.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<WatchlistProvider>(
    builder: (_, provider, _) {
      if (!provider.initialized) return _libraryState(provider);
      final query = searchController.text.trim().toLowerCase();
      final visible =
          provider.items.where((item) {
            final matchesQuery =
                query.isEmpty || item.title.toLowerCase().contains(query);
            return matchesQuery && (status == null || item.status == status);
          }).toList()..sort((a, b) {
            if (sort == 'title') {
              return a.title.toLowerCase().compareTo(b.title.toLowerCase());
            }
            if (sort == 'rating') {
              return (b.userRating ?? 0).compareTo(a.userRating ?? 0);
            }
            return b.addedAt.compareTo(a.addedAt);
          });
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'My Watchlist',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${provider.items.length} saved titles',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search your collection',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Clear watchlist search',
                onPressed: () {
                  searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: status == null,
                onSelected: (_) => setState(() => status = null),
              ),
              ...WatchStatus.values.map(
                (value) => FilterChip(
                  label: Text(_statusLabel(value)),
                  selected: status == value,
                  onSelected: (_) =>
                      setState(() => status = status == value ? null : value),
                ),
              ),
              DropdownButton<String>(
                value: sort,
                items: const [
                  DropdownMenuItem(value: 'recent', child: Text('Recent')),
                  DropdownMenuItem(value: 'title', child: Text('Title')),
                  DropdownMenuItem(value: 'rating', child: Text('Rating')),
                ],
                onChanged: (value) => setState(() => sort = value ?? sort),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (provider.items.isEmpty)
            const MessageState(
              message: 'Your collection is empty. Add films and shows from their detail pages.',
            )
          else if (visible.isEmpty)
            const MessageState(message: 'No saved titles match these filters.')
          else
            ...visible.map(
              (item) => Card(
                color: surface,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: Poster(path: item.posterPath, width: 48, height: 72),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.type == 'tv' ? 'TV show' : 'Movie'} \u00B7 ${_statusLabel(item.status)}${item.userRating == null ? '' : ' \u00B7 ${item.userRating}/5'}',
                  ),
                  onTap: () => _edit(context, item),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove ${item.title}',
                    onPressed: () => _remove(context, item),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});
  @override
  Widget build(BuildContext context) => Consumer<WatchlistProvider>(
    builder: (_, provider, _) {
      if (!provider.initialized) return _libraryState(provider);
      final counts = provider.statusCounts;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Statistics',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Stat(label: 'Saved', value: provider.items.length, color: bright),
              Stat(
                label: 'Movies',
                value: provider.countType('movie'),
                color: gold,
              ),
              Stat(
                label: 'TV shows',
                value: provider.countType('tv'),
                color: watched,
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (provider.items.isEmpty)
            const MessageState(
              message:
                  'Save titles to see your personal collection statistics.',
            )
          else ...[
            SizedBox(
              height: 250,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                builder: (_, value, _) => PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        value:
                            (counts[WatchStatus.watched] ?? 0).toDouble() *
                            value,
                        color: watched,
                        title: 'Watched',
                        radius: 85,
                      ),
                      PieChartSectionData(
                        value:
                            (counts[WatchStatus.watching] ?? 0).toDouble() *
                            value,
                        color: watching,
                        title: 'Watching',
                        radius: 85,
                      ),
                      PieChartSectionData(
                        value:
                            (counts[WatchStatus.planToWatch] ?? 0).toDouble() *
                            value,
                        color: primary,
                        title: 'Plan',
                        radius: 85,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ActivitySummary(provider: provider),
            Achievements(provider: provider),
            if (provider.achievementsNeedRetry)
              MessageState(
                message: 'Some achievements could not be updated.',
                onRetry: provider.initialize,
              ),
          ],
        ],
      );
    },
  );
}

class MediaDetailsPage extends StatefulWidget {
  const MediaDetailsPage({
    required this.ref,
    this.summary,
    this.heroTag,
    super.key,
  });

  final EntityRef ref;
  final Media? summary;
  final String? heroTag;

  @override
  State<MediaDetailsPage> createState() => _MediaDetailsPageState();
}

class _MediaDetailsPageState extends State<MediaDetailsPage> {
  late final _repository = context.read<CatalogueRepository>();
  late Future<Media> _details;
  Media? _lastGood;

  @override
  void initState() {
    super.initState();
    _details = _request();
  }

  Future<Media> _request({bool refresh = false}) async =>
      _lastGood = await _repository.details(widget.ref, refresh: refresh);

  void _refresh() => setState(() => _details = _request(refresh: true));

  @override
  Widget build(BuildContext context) => FutureBuilder<Media>(
    future: _details,
    initialData: widget.summary,
    builder: (context, snapshot) {
      final item = snapshot.data ?? _lastGood ?? widget.summary;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            item?.title ?? 'Title details',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: BackButton(
            onPressed: () => CineNavigation.of(context).back(context),
          ),
        ),
        body: item == null
            ? snapshot.hasError
                  ? Center(
                      child: MessageState(
                        message: _catalogueMessage(snapshot.error),
                        onRetry: _refresh,
                      ),
                    )
                  : const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  if (item.backdropPath != null)
                    Image.network(
                      '${CatalogueRepository.backdropBase}${item.backdropPath}',
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(height: 220),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            widget.heroTag == null
                                ? Poster(
                                    path: item.posterPath,
                                    width: 112,
                                    height: 168,
                                  )
                                : Hero(
                                    tag: widget.heroTag!,
                                    child: Poster(
                                      path: item.posterPath,
                                      width: 112,
                                      height: 168,
                                    ),
                                  ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${item.year}  \u00B7  ${item.rating.toStringAsFixed(1)} \u2605',
                                    style: const TextStyle(color: gold),
                                  ),
                                  const SizedBox(height: 12),
                                  Consumer<WatchlistProvider>(
                                    builder: (_, provider, _) {
                                      final saved =
                                          provider.find(item.id, item.type) !=
                                          null;
                                      return FilledButton.icon(
                                        onPressed: !provider.initialized
                                            ? null
                                            : () => saved
                                                  ? _remove(
                                                      context,
                                                      provider.find(
                                                        item.id,
                                                        item.type,
                                                      )!,
                                                    )
                                                  : _save(context, item),
                                        icon: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 220,
                                          ),
                                          transitionBuilder:
                                              (child, animation) =>
                                                  ScaleTransition(
                                                    scale: animation,
                                                    child: child,
                                                  ),
                                          child: Icon(
                                            saved
                                                ? Icons.bookmark
                                                : Icons.bookmark_add_outlined,
                                            key: ValueKey(saved),
                                          ),
                                        ),
                                        label: Text(
                                          saved
                                              ? 'Remove from watchlist'
                                              : 'Add to watchlist',
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (item.genres.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            children: item.genres
                                .map((genre) => Chip(label: Text(genre)))
                                .toList(),
                          ),
                        const SizedBox(height: 18),
                        const Text(
                          'Overview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.overview.isEmpty
                              ? 'No overview available.'
                              : item.overview,
                          style: const TextStyle(color: muted, height: 1.5),
                        ),
                        const SizedBox(height: 22),
                        if (item.isMovie)
                          Text(
                            'Runtime: ${item.runtime == null ? 'Not available' : '${item.runtime} minutes'}',
                            style: const TextStyle(color: muted),
                          )
                        else
                          Text(
                            'Seasons: ${item.seasons ?? 'N/A'}  \u00B7  Episodes: ${item.episodes ?? 'N/A'}  \u00B7  Episode runtime: ${item.episodeRuntime == null ? 'N/A' : '${item.episodeRuntime} min'}',
                            style: const TextStyle(color: muted),
                          ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                  if (snapshot.hasError)
                    MessageState(
                      message: _catalogueMessage(snapshot.error),
                      onRetry: _refresh,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: RelatedSection(
                      title: 'Similar ${item.isMovie ? 'movies' : 'TV shows'}',
                      ref: widget.ref,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: RelatedSection(
                      title: 'Recommended',
                      ref: widget.ref,
                      recommended: true,
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

Widget _libraryState(WatchlistProvider provider) => Center(
  child: provider.openFailed
      ? MessageState(
          message: 'Unable to open your local watchlist.',
          onRetry: provider.initialize,
        )
      : const CircularProgressIndicator(),
);

Future<void> _save(BuildContext context, Media media) async {
  final provider = context.read<WatchlistProvider>();
  if (!provider.initialized) {
    _libraryMessage(
      context,
      'Your watchlist is unavailable. Open Watchlist to retry.',
    );
    return;
  }
  try {
    await provider.save(media);
    if (context.mounted) _libraryMessage(context, 'Added to your watchlist');
  } catch (_) {
    if (context.mounted) {
      _libraryMessage(context, 'Unable to save this title. Please retry.');
    }
  }
}

Future<void> _remove(BuildContext context, WatchlistItem item) async {
  final provider = context.read<WatchlistProvider>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remove title?'),
      content: Text('Remove ${item.title} from your watchlist?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await provider.remove(item);
  } catch (_) {
    if (context.mounted) {
      _libraryMessage(context, 'Unable to remove this title. Please retry.');
    }
  }
}

void _libraryMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class MediaCard extends StatelessWidget {
  const MediaCard({required this.media, this.heroTag, super.key});
  final Media media;
  final String? heroTag;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () =>
        CineNavigation.of(context).openTitle(context, media, heroTag: heroTag),
    child: SizedBox(
      width: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: heroTag == null
                ? Poster(path: media.posterPath)
                : Hero(
                    tag: heroTag!,
                    child: Poster(path: media.posterPath),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            media.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '${media.year}  \u00B7  ${media.rating.toStringAsFixed(1)} \u2605',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class RelatedSection extends StatefulWidget {
  const RelatedSection({
    required this.title,
    required this.ref,
    this.recommended = false,
    super.key,
  });
  final String title;
  final EntityRef ref;
  final bool recommended;

  @override
  State<RelatedSection> createState() => _RelatedSectionState();
}

class _RelatedSectionState extends State<RelatedSection>
    with AutomaticKeepAliveClientMixin {
  late final _repository = context.read<CatalogueRepository>();
  late Future<List<Media>> loader;

  @override
  void initState() {
    super.initState();
    loader = _request();
  }

  Future<List<Media>> _request({bool refresh = false}) => _repository.related(
    widget.ref,
    recommended: widget.recommended,
    refresh: refresh,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Media>>(
      future: loader,
      builder: (_, snapshot) {
        final items = snapshot.data?.take(8).toList() ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return MessageState(
            message: '${widget.title}: ${_catalogueMessage(snapshot.error)}',
            onRetry: () => setState(() => loader = _request(refresh: true)),
          );
        }
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) => GestureDetector(
                  onTap: () =>
                      CineNavigation.of(context)
                          .openTitle(context, items[index]),
                  child: SizedBox(
                    width: 132,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Poster(path: items[index].posterPath)),
                        const SizedBox(height: 6),
                        Text(
                          items[index].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class Poster extends StatelessWidget {
  const Poster({this.path, this.width, this.height, super.key});
  final String? path;
  final double? width;
  final double? height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: width,
      height: height,
      color: elevated,
      child: path == null
          ? const Icon(Icons.movie_outlined, color: muted, size: 32)
          : FadeInPoster(path: path!),
    ),
  );
}

class FadeInPoster extends StatefulWidget {
  const FadeInPoster({required this.path, super.key});
  final String path;
  @override
  State<FadeInPoster> createState() => _FadeInPosterState();
}

class _FadeInPosterState extends State<FadeInPoster>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..forward();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(parent: controller, curve: Curves.easeOut),
    child: Image.network(
      '${CatalogueRepository.imageBase}${widget.path}',
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.broken_image_outlined, color: muted),
    ),
  );
}

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({this.height = 120, super.key});
  final double height;
  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, _) => Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment(-1 + controller.value * 2, 0),
          end: Alignment(1 + controller.value * 2, 0),
          colors: const [surface, elevated, surface],
        ),
      ),
    ),
  );
}

class MessageState extends StatelessWidget {
  const MessageState({required this.message, this.onRetry, super.key});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    ),
  );
}

class Stat extends StatelessWidget {
  const Stat({
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 105,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: value),
          duration: const Duration(milliseconds: 600),
          builder: (_, number, _) => Text(
            '$number',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: muted)),
      ],
    ),
  );
}

class ActivitySummary extends StatelessWidget {
  const ActivitySummary({required this.provider, super.key});
  final WatchlistProvider provider;
  @override
  Widget build(BuildContext context) {
    final activity = provider.activityByDay;
    final watchedCount = activity.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final monthCounts = <int, int>{};
    for (final entry in activity.entries) {
      monthCounts[entry.key.month] =
          (monthCounts[entry.key.month] ?? 0) + entry.value;
    }
    final peak = monthCounts.entries.isEmpty
        ? null
        : monthCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return Card(
      color: surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Viewing activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '$watchedCount watched titles with recorded dates',
              style: const TextStyle(color: muted),
            ),
            if (peak != null)
              Text(
                'Most active month: ${_monthName(peak.key)} (${peak.value})',
                style: const TextStyle(color: bright),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: List.generate(28, (index) {
                final date = DateTime.now().subtract(
                  Duration(days: 27 - index),
                );
                final count =
                    activity[DateTime(date.year, date.month, date.day)] ?? 0;
                return Tooltip(
                  message: '${date.day}/${date.month}: $count watched',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: count == 0
                          ? secondary
                          : Color.lerp(
                              primary,
                              watched,
                              (count / 3).clamp(0, 1),
                            ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class Achievements extends StatelessWidget {
  const Achievements({required this.provider, super.key});
  final WatchlistProvider provider;
  static const definitions = <String, String>{
    'first-watch': 'First Watch',
    'ten-watched': '10 Titles Watched',
    'genre-explorer': 'Genre Explorer',
    'movie-marathon': 'Movie Marathon',
    'tv-completion': 'TV Explorer',
  };
  @override
  Widget build(BuildContext context) {
    final unlocked = provider.unlockedAchievements.toSet();
    return Card(
      color: surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Achievements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ...definitions.entries.map(
              (entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: AnimatedScale(
                  scale: unlocked.contains(entry.key) ? 1 : .85,
                  duration: const Duration(milliseconds: 400),
                  child: Icon(
                    unlocked.contains(entry.key)
                        ? Icons.emoji_events
                        : Icons.lock_outline,
                    color: unlocked.contains(entry.key) ? gold : muted,
                  ),
                ),
                title: Text(entry.value),
                subtitle: Text(
                  unlocked.contains(entry.key)
                      ? 'Unlocked from your activity'
                      : 'Keep tracking to unlock',
                  style: const TextStyle(color: muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _monthName(int month) => const [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month];
