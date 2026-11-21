import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

import 'models/media.dart';
import 'models/watchlist_item.dart';
import 'providers/watchlist_provider.dart';
import 'services/tmdb_service.dart';

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

class CineVaultApp extends StatelessWidget {
  const CineVaultApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'CineVault',
    theme: cineTheme(),
    home: const StartupPage(),
  );
}

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});
  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1700), () {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FadeTransition(
        opacity: CurvedAnimation(parent: controller, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: .82, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/branding/cinevault_emblem.svg',
                width: 90,
                height: 90,
              ),
              const SizedBox(height: 18),
              const Text(
                'CineVault',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'DISCOVER \u00B7 COLLECT \u00B7 REMEMBER',
                style: TextStyle(color: muted, fontSize: 10, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final service = TmdbService();
  final pages = const [
    HomePage(),
    NowPlayingPage(),
    TvShowsPage(),
    SearchPage(),
    WatchlistPage(),
    StatisticsPage(),
  ];
  void setTab(int i) => setState(() => index = i);
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      // If not on home tab, navigate home first
      if (index != 0) {
        setState(() => index = 0);
        return;
      }
      // On home tab: show exit confirmation
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Exit CineVault?', style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text('Are you sure you want to exit the app?', style: TextStyle(color: muted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Exit'),
            ),
          ],
        ),
      );
      if (shouldExit == true && context.mounted) {
        SystemNavigator.pop();
      }
    },
    child: Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: CompactBottomNav(
        currentIndex: index,
        onTap: (value) => setState(() => index = value),
      ),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Key _refreshKey = UniqueKey();

  Future<void> _onRefresh() async {
    TmdbService.clearCache();
    if (mounted) setState(() => _refreshKey = UniqueKey());
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: canvas,
    body: RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        key: _refreshKey,
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
                  final shell = context
                      .findAncestorStateOfType<_MainShellState>();
                  shell?.setTab(3);
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
                const HeroCarousel(),
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
          SliverList.list(
            children: [
              Section(
                title: 'Trending this week',
                loader: TmdbService().trendingMovies(),
                path: '/trending/movie/week',
              ),
              const Section(title: 'Popular movies', path: '/movie/popular'),
              const Section(title: 'Now playing', path: '/movie/now_playing'),
              Section(
                title: 'Recently released',
                path: '/discover/movie',
                initialPage: TmdbService().recentMoviesPage(),
                pageLoader: (page) =>
                    TmdbService().recentMoviesPage(page: page),
              ),
              Section(
                title: 'Upcoming releases',
                path: '/movie/upcoming',
                initialPage: TmdbService().upcomingMoviesPage(),
                pageLoader: (page) =>
                    TmdbService().upcomingMoviesPage(page: page),
              ),
              const Section(
                title: 'Top rated movies',
                path: '/movie/top_rated',
              ),
              const TvSection(title: 'Popular TV shows', path: '/tv/popular'),
              const TvSection(title: 'Airing today', path: '/tv/airing_today'),
              const TvSection(title: 'On the air', path: '/tv/on_the_air'),
              const RecommendationsSection(),
            ],
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
    future = TmdbService().popularMovies();
    autoAdvance = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || items.length < 2 || !controller.hasClients) return;
      controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
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
    final cacheKey = '${media.type}-${media.id}';
    final cached = _ambientColorCache.get(cacheKey);
    if (cached != null) {
      if (mounted) setState(() => _ambientColor = cached);
      return;
    }
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage('${TmdbService.backdropBase}${media.backdropPath}'),
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
        if (mounted) setState(() => _ambientColor = adjusted);
      }
    } catch (_) {
      if (mounted) setState(() => _ambientColor = null);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Media>>(
    future: future,
    builder: (_, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SkeletonBox(height: 220);
      }
      if (snapshot.hasError) {
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
                    setState(() {
                      future = TmdbService().popularMovies();
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      items = snapshot.data?.take(5).toList() ?? [];
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
                _updateAmbientColor(items[value]);
              },
              itemBuilder: (_, index) {
                final media = items[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MediaDetailsPage(media: media),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        media.backdropPath == null
                            ? Container(color: elevated)
                            : Image.network(
                                '${TmdbService.backdropBase}${media.backdropPath}',
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
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MediaDetailsPage(media: media),
                                  ),
                                ),
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
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DiscoveryPage(
            title: '$label movies',
            loader: TmdbService().discoverPage(genreId: genreId),
            pageLoader: (page) =>
                TmdbService().discoverPage(genreId: genreId, page: page),
          ),
        ),
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

class Section extends StatelessWidget {
  const Section({
    required this.title,
    required this.path,
    this.loader,
    this.initialPage,
    this.pageLoader,
    super.key,
  });
  final String title;
  final String path;
  final Future<List<Media>>? loader;
  final Future<TmdbPage>? initialPage;
  final Future<TmdbPage> Function(int page)? pageLoader;

  @override
  Widget build(BuildContext context) => PagedHorizontalSection(
    title: title,
    path: path,
    initialPage:
        initialPage ??
        (loader == null ? TmdbService().pageResults(path) : _asPage(loader!)),
    pageLoader:
        pageLoader ?? (page) => TmdbService().pageResults(path, page: page),
  );

  Future<TmdbPage> _asPage(Future<List<Media>> source) async {
    final items = await source;
    return TmdbPage(
      items: items,
      page: 1,
      totalPages: items.isEmpty ? 1 : 500,
      totalResults: items.length,
    );
  }
}

class PagedHorizontalSection extends StatefulWidget {
  const PagedHorizontalSection({
    required this.title,
    required this.path,
    required this.initialPage,
    required this.pageLoader,
    super.key,
  });
  final String title;
  final String path;
  final Future<TmdbPage> initialPage;
  final Future<TmdbPage> Function(int page) pageLoader;

  @override
  State<PagedHorizontalSection> createState() => _PagedHorizontalSectionState();
}

class _PagedHorizontalSectionState extends State<PagedHorizontalSection> {
  final controller = ScrollController();
  final items = <Media>[];
  late Future<TmdbPage> initial;
  int page = 1;
  int totalPages = 1;
  bool loadingMore = false;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    initial = _loadInitial();
    controller.addListener(_onScroll);
  }

  Future<TmdbPage> _loadInitial() async {
    final result = await widget.initialPage;
    _append(result.items);
    page = result.page;
    totalPages = result.totalPages;
    return result;
  }

  void _append(List<Media> next) {
    final keys = items.map((item) => item.key).toSet();
    items.addAll(next.where((item) => keys.add(item.key)));
  }

  void _onScroll() {
    if (!controller.hasClients ||
        loadingMore ||
        page >= totalPages ||
        page >= 500) {
      return;
    }
    if (controller.position.pixels >=
        controller.position.maxScrollExtent * .7) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (loadingMore || page >= totalPages || page >= 500) return;
    setState(() {
      loadingMore = true;
      hasError = false;
    });
    try {
      final result = await widget.pageLoader(page + 1);
      if (!mounted) return;
      setState(() {
        _append(result.items);
        page = result.page;
        totalPages = result.totalPages;
        loadingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loadingMore = false;
          hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TmdbPage>(
    future: initial,
    builder: (context, snapshot) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DiscoveryPage(
                    title: widget.title,
                    loader: widget.initialPage,
                    pageLoader: widget.pageLoader,
                  ),
                ),
              ),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (snapshot.connectionState == ConnectionState.waiting)
          const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (snapshot.hasError)
          MessageState(
            message: snapshot.error.toString().replaceFirst(
              'TMDB request failed: ',
              '',
            ),
            onRetry: () => setState(() => initial = _loadInitial()),
          )
        else if (items.isEmpty)
          const MessageState(message: 'No titles available right now.')
        else
          SizedBox(
            height: 250,
            child: ListView.separated(
              controller: controller,
              scrollDirection: Axis.horizontal,
              itemCount: items.length + (loadingMore || hasError ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                if (i == items.length) {
                  return Center(
                    child: hasError
                        ? IconButton(
                            onPressed: _loadMore,
                            icon: const Icon(Icons.refresh),
                          )
                        : const SizedBox(
                            width: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                  );
                }
                return MediaCard(
                  media: items[i],
                  heroTag: '${widget.title}-${items[i].key}',
                );
              },
            ),
          ),
      ],
    ),
  );
}

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});
  @override
  Widget build(BuildContext context) => DiscoveryPage(
    title: 'Now Playing',
    loader: TmdbService().pageResults('/movie/now_playing'),
    pageLoader: (page) =>
        TmdbService().pageResults('/movie/now_playing', page: page),
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
      TvSection(title: 'Popular', path: '/tv/popular'),
      TvSection(title: 'Airing today', path: '/tv/airing_today'),
      TvSection(title: 'Top rated', path: '/tv/top_rated'),
    ],
  );
}

class TvSection extends StatelessWidget {
  const TvSection({required this.title, required this.path, super.key});
  final String title;
  final String path;
  @override
  Widget build(BuildContext context) => PagedHorizontalSection(
    title: title,
    path: path,
    initialPage: TmdbService().pageResults(path, type: 'tv'),
    pageLoader: (page) =>
        TmdbService().pageResults(path, type: 'tv', page: page),
  );
}

class RecommendationsSection extends StatelessWidget {
  const RecommendationsSection({super.key});
  @override
  Widget build(BuildContext context) => Consumer<WatchlistProvider>(
    builder: (_, provider, _) {
      final seed = provider.items.isEmpty ? null : provider.items.first;
      if (seed == null) return const SizedBox.shrink();
      final media = Media(
        id: seed.id,
        type: seed.type,
        title: seed.title,
        posterPath: seed.posterPath,
        genres: seed.genres,
      );
      return FutureBuilder<List<Media>>(
        future: TmdbService().similar(media),
        builder: (_, snapshot) {
          final items =
              snapshot.data
                  ?.where((item) => provider.find(item.id, item.type) == null)
                  .take(8)
                  .toList() ??
              [];
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
    },
  );
}

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({
    required this.title,
    required this.loader,
    this.pageLoader,
    super.key,
  });
  final String title;
  final Future<TmdbPage> loader;
  final Future<TmdbPage> Function(int page)? pageLoader;
  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  late Future<List<Media>> initialLoad;
  final items = <Media>[];
  int page = 1;
  int totalPages = 1;
  bool loadingMore = false;
  bool reachedEnd = false;

  @override
  void initState() {
    super.initState();
    initialLoad = _loadInitial();
  }

  Future<List<Media>> _loadInitial() async {
    final loaded = await widget.loader;
    _append(loaded.items);
    page = loaded.page;
    totalPages = loaded.totalPages;
    reachedEnd = !loaded.hasMore;
    return loaded.items;
  }

  void _append(List<Media> next) {
    final existing = items.map((item) => item.key).toSet();
    items.addAll(next.where((item) => existing.add(item.key)));
  }

  Future<void> _loadMore() async {
    if (widget.pageLoader == null || loadingMore || reachedEnd) return;
    setState(() => loadingMore = true);
    try {
      final next = await widget.pageLoader!(page + 1);
      if (!mounted) return;
      setState(() {
        page++;
        _append(next.items);
        reachedEnd = !next.hasMore;
        totalPages = next.totalPages;
        loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    final refreshed = await widget.loader;
    if (!mounted) return;
    setState(() {
      items
        ..clear()
        ..addAll(refreshed.items);
      page = refreshed.page;
      totalPages = refreshed.totalPages;
      reachedEnd = !refreshed.hasMore;
      loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: canvas,
    appBar: AppBar(
      backgroundColor: canvas,
      leading: IconButton(
        tooltip: 'Back to home',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    body: FutureBuilder<List<Media>>(
      future: initialLoad,
      builder: (context, snapshot) => RefreshIndicator(
        onRefresh: _refresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 500) {
              _loadMore();
            }
            return false;
          },
          child: ListView(
            key: const PageStorageKey<String>('discovery-list'),
            addAutomaticKeepAlives: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                widget.title == 'Popular movies'
                    ? 'Popular movies this week'
                    : widget.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a title to view its details.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (snapshot.hasError)
                MessageState(message: snapshot.error.toString())
              else if (snapshot.data?.isEmpty ?? true)
                const MessageState(message: 'No titles available.')
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length + (loadingMore ? 1 : 0),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisExtent: 300,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 20,
                  ),
                  itemBuilder: (_, i) {
                    if (i == items.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return MediaCard(
                      media: items[i],
                      heroTag: '${widget.title}-${items[i].key}',
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final controller = TextEditingController();
  final scrollController = ScrollController();
  Timer? timer;
  Future<List<Media>>? result;
  List<Media> results = [];
  int searchPage = 1;
  int searchTotalPages = 1;
  bool loadingMore = false;
  int requestToken = 0;
  bool searching = false;
  String type = 'movie';
  int? genreId;
  int? year;
  double? minimumRating;
  String sortBy = 'popularity.desc';
  static const genres = <int, String>{
    28: 'Action',
    35: 'Comedy',
    18: 'Drama',
    27: 'Horror',
    878: 'Science Fiction',
    10749: 'Romance',
  };
  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void search(String value, {bool immediate = false}) {
    timer?.cancel();
    final query = value.trim();
    if (query.isEmpty &&
        genreId == null &&
        year == null &&
        minimumRating == null) {
      setState(() {
        result = null;
        results = [];
        searching = false;
      });
      return;
    }
    void start() {
      if (!mounted) return;
      final token = ++requestToken;
      setState(() {
        searching = true;
        results = [];
        searchPage = 1;
        searchTotalPages = 1;
        result = query.isNotEmpty
            ? TmdbService().searchPage(query).then((page) {
                if (mounted && token == requestToken) {
                  setState(() {
                    results = page.items;
                    searchTotalPages = page.totalPages;
                    searching = false;
                  });
                }
                return page.items;
              })
            : TmdbService()
                  .discoverPage(
                    type: type,
                    genreId: genreId,
                    year: year,
                    minimumRating: minimumRating,
                    sortBy: sortBy,
                  )
                  .then((page) {
                    if (mounted && token == requestToken) {
                      setState(() {
                        results = page.items;
                        searchTotalPages = page.totalPages;
                        searching = false;
                      });
                    }
                    return page.items;
                  });
      });
    }

    if (immediate) {
      start();
    } else {
      timer = Timer(const Duration(milliseconds: 450), start);
    }
  }

  Future<void> _loadMoreSearch() async {
    final query = controller.text.trim();
    if (loadingMore ||
        searchPage >= searchTotalPages ||
        (query.isEmpty &&
            genreId == null &&
            year == null &&
            minimumRating == null)) {
      return;
    }
    final token = requestToken;
    setState(() => loadingMore = true);
    try {
      final next = query.isNotEmpty
          ? await TmdbService().searchPage(query, page: searchPage + 1)
          : await TmdbService().discoverPage(
              type: type,
              genreId: genreId,
              year: year,
              minimumRating: minimumRating,
              sortBy: sortBy,
              page: searchPage + 1,
            );
      if (!mounted || token != requestToken) return;
      final keys = results.map((item) => item.key).toSet();
      setState(() {
        results.addAll(next.items.where((item) => keys.add(item.key)));
        searchPage = next.page;
        searchTotalPages = next.totalPages;
        loadingMore = false;
      });
    } catch (_) {
      if (mounted && token == requestToken) setState(() => loadingMore = false);
    }
  }

  Future<void> _openFilters() async {
    var nextType = type;
    var nextGenre = genreId;
    var nextYear = year;
    var nextRating = minimumRating;
    var nextSort = sortBy;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 16,
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
                      'Discovery filters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setSheetState(() {
                        nextType = 'movie';
                        nextGenre = null;
                        nextYear = null;
                        nextRating = null;
                        nextSort = 'popularity.desc';
                      }),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilterField<String>(
                  label: 'CONTENT TYPE',
                  value: nextType,
                  items: const [
                    DropdownMenuItem(value: 'movie', child: Text('Movies')),
                    DropdownMenuItem(value: 'tv', child: Text('TV shows')),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => nextType = value ?? nextType),
                ),
                FilterField<int>(
                  label: 'GENRE',
                  value: nextGenre,
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('All genres'),
                    ),
                    ...genres.entries.map(
                      (entry) => DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    ),
                  ],
                  onChanged: (value) => setSheetState(() => nextGenre = value),
                ),
                FilterField<int>(
                  label: 'RELEASE YEAR',
                  value: nextYear,
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Any year'),
                    ),
                    ...List.generate(
                      12,
                      (index) => DateTime.now().year - index,
                    ).map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setSheetState(() => nextYear = value),
                ),
                FilterField<double>(
                  label: 'MINIMUM RATING',
                  value: nextRating,
                  items: [
                    const DropdownMenuItem<double>(
                      value: null,
                      child: Text('Any rating'),
                    ),
                    ...[6.0, 7.0, 8.0, 9.0].map(
                      (value) => DropdownMenuItem<double>(
                        value: value,
                        child: Text('$value+'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setSheetState(() => nextRating = value),
                ),
                FilterField<String>(
                  label: 'SORT BY',
                  value: nextSort,
                  items: const [
                    DropdownMenuItem(
                      value: 'popularity.desc',
                      child: Text('Popularity'),
                    ),
                    DropdownMenuItem(
                      value: 'vote_average.desc',
                      child: Text('Rating'),
                    ),
                    DropdownMenuItem(
                      value: 'primary_release_date.desc',
                      child: Text('Release date'),
                    ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => nextSort = value ?? nextSort),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        type = nextType;
                        genreId = nextGenre;
                        year = nextYear;
                        minimumRating = nextRating;
                        sortBy = nextSort;
                      });
                      Navigator.pop(sheetContext);
                      search(controller.text, immediate: true);
                    },
                    child: const Text(
                      'Apply filters',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
  Widget build(
    BuildContext context,
  ) => NotificationListener<ScrollNotification>(
    onNotification: (notification) {
      if (notification.metrics.pixels >=
          notification.metrics.maxScrollExtent * .75) {
        _loadMoreSearch();
      }
      return false;
    },
    child: ListView(
      padding: const EdgeInsets.all(20),
      controller: scrollController,
      children: [
        const Text(
          'Search',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          onChanged: search,
          onSubmitted: (value) => search(value, immediate: true),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search movies and TV shows',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _openFilters,
                  icon: Icon(
                    genreId != null || year != null || minimumRating != null
                        ? Icons.filter_alt
                        : Icons.filter_alt_outlined,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    controller.clear();
                    search('');
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (searching && result == null)
          const Center(child: CircularProgressIndicator())
        else if (result == null)
          const MessageState(
            message: 'Search the TMDB catalogue to find your next story.',
          )
        else
          FutureBuilder<List<Media>>(
            future: result,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return MessageState(message: snapshot.error.toString());
              }
              if (results.isEmpty) {
                return const MessageState(message: 'No matching titles found.');
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: results.length + (loadingMore ? 1 : 0),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisExtent: 270,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                ),
                itemBuilder: (_, i) {
                  if (i == results.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  return MediaCard(
                    media: results[i],
                    heroTag: 'search-${results[i].key}',
                  );
                },
              );
            },
          ),
      ],
    ),
  );
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
                  decoration: const InputDecoration(labelText: 'Viewing status'),
                  items: WatchStatus.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_statusLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(
                    () => selectedStatus = value ?? selectedStatus,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<double?>(
                  initialValue: rating,
                  decoration: const InputDecoration(labelText: 'Personal rating'),
                  items: <double?>[
                    null,
                    0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0,
                    if (rating != null &&
                        !const [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
                            .contains(rating))
                      rating,
                  ]
                      .map(
                        (value) => DropdownMenuItem<double?>(
                          value: value,
                          child: Text(
                            value == null ? 'Not rated' : '$value / 5 \u2605',
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
                  decoration: const InputDecoration(labelText: 'Personal review'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      initialDate: watchedDate ?? DateTime.now(),
                    );
                    if (picked != null) {
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await provider.update(
                        item,
                        status: selectedStatus,
                        userRating: rating,
                        notes: notes.text.trim(),
                        review: review.text.trim(),
                        dateWatched: watchedDate,
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text('Save changes'),
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
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Remove title?'),
                          content: Text(
                            'Remove ${item.title} from your watchlist?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) await provider.remove(item);
                    },
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
          ],
        ],
      );
    },
  );
}

class MediaDetailsPage extends StatelessWidget {
  const MediaDetailsPage({required this.media, this.heroTag, super.key});
  final Media media;
  final String? heroTag;
  @override
  Widget build(BuildContext context) => FutureBuilder<Media>(
    future: TmdbService().details(media),
    initialData: media,
    builder: (context, snapshot) {
      final item = snapshot.data ?? media;
      return Scaffold(
        appBar: AppBar(
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: ListView(
          children: [
            if (item.backdropPath != null)
              Image.network(
                '${TmdbService.backdropBase}${item.backdropPath}',
                height: 220,
                fit: BoxFit.cover,
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heroTag == null
                          ? Poster(
                              path: item.posterPath,
                              width: 112,
                              height: 168,
                            )
                          : Hero(
                              tag: heroTag!,
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
                                    provider.find(item.id, item.type) != null;
                                return FilledButton.icon(
                                  onPressed: () => saved
                                      ? provider.remove(
                                          provider.find(item.id, item.type)!,
                                        )
                                      : _save(context, item),
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    transitionBuilder: (child, animation) =>
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                  RelatedSection(
                    title: 'Similar ${item.isMovie ? 'movies' : 'TV shows'}',
                    loader: TmdbService().similar(item),
                    onTap: (related) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaDetailsPage(media: related),
                      ),
                    ),
                  ),
                  RelatedSection(
                    title: 'Recommended',
                    loader: TmdbService().recommendations(item),
                    onTap: (related) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaDetailsPage(media: related),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _save(BuildContext context, Media media) async {
  await context.read<WatchlistProvider>().save(media);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Added to your watchlist')));
  }
}

class MediaCard extends StatelessWidget {
  const MediaCard({required this.media, this.heroTag, super.key});
  final Media media;
  final String? heroTag;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaDetailsPage(media: media, heroTag: heroTag),
      ),
    ),
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

class RelatedSection extends StatelessWidget {
  const RelatedSection({
    required this.title,
    required this.loader,
    required this.onTap,
    super.key,
  });
  final String title;
  final Future<List<Media>> loader;
  final ValueChanged<Media> onTap;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Media>>(
    future: loader,
    builder: (_, snapshot) {
      final items = snapshot.data?.take(8).toList() ?? [];
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: LinearProgressIndicator(),
        );
      }
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
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
                onTap: () => onTap(items[index]),
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
      '${TmdbService.imageBase}${widget.path}',
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
