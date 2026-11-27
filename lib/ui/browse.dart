import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/navigation_scope.dart';
import '../app/route_contract.dart';
import '../catalogue/artwork_policy.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/entity_ref.dart';
import '../catalogue/paged_controller.dart';
import '../core/material.dart';
import '../models/media.dart';
import '../providers/watchlist_provider.dart';
import 'artwork.dart';
import 'catalogue_widgets.dart';
import 'design_system.dart';
import 'library.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _feature = GlobalKey<_FeaturedCarouselState>();
  late final _feeds = {
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
      feed: GlobalKey<FeedShelfState>(),
  };

  Future<void> _refresh() => Future.wait<void>([
    if (_feature.currentState case final feature?) feature.refresh(),
    for (final key in _feeds.values)
      if (key.currentState case final shelf?) shelf.refresh(),
  ]);

  @override
  Widget build(BuildContext context) => CinePage(
    onRefresh: _refresh,
    scrollKey: const PageStorageKey('home'),
    slivers: [
      CineSliver(top: 20, bottom: 24, child: _FeaturedCarousel(key: _feature)),
      const CineSliver(bottom: 24, child: _BrowseLinks()),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: CineLayout.gutterOf(context)),
        sliver: SliverList.builder(
          itemCount: _feeds.length + 1,
          itemBuilder: (context, index) {
            if (index == _feeds.length) return const _PersonalShelf();
            final feed = _feeds.keys.elementAt(index);
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: FeedShelf(key: _feeds[feed], feed: feed),
            );
          },
        ),
      ),
    ],
  );
}

class _BrowseLinks extends StatelessWidget {
  const _BrowseLinks();

  @override
  Widget build(BuildContext context) {
    final nav = CineNavigation.of(context);
    final compact = CineLayout.widthOf(context) == CineWidth.compact;
    return Wrap(
      spacing: compact ? 6 : 8,
      runSpacing: 8,
      children: [
        for (final (tab, label, icon) in const [
          (AppTab.movies, 'Movies', Icons.movie_creation_outlined),
          (AppTab.tv, 'TV Shows', Icons.tv_rounded),
          (AppTab.nowPlaying, 'Now Playing', Icons.local_activity_outlined),
        ])
          ActionChip(
            avatar: Icon(icon, size: compact ? 15 : 18),
            label: Text(label, style: TextStyle(fontSize: compact ? 12 : 14)),
            labelPadding: EdgeInsets.symmetric(horizontal: compact ? 3 : 8),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: 6,
            ),
            onPressed: () => nav.select(context, tab),
          ),
      ],
    );
  }
}

class _FeaturedCarousel extends StatefulWidget {
  const _FeaturedCarousel({super.key});

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  final _controller = PageController();
  late final _catalogue = context.read<CatalogueRepository>();
  late Future<TmdbPage> _request;
  List<Media> _items = const [];
  int _current = 0;
  Timer? _timer;
  bool _running = false;
  bool _hovering = false;
  bool _focused = false;
  bool _pausing = false;
  bool _didPrefetch = false;

  @override
  void initState() {
    super.initState();
    _request = _catalogue.browseFeed(CatalogueFeed.trending);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _running =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!_running || _hovering || _focused || _pausing) return;
    _timer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        _move(1);
      }
    });
  }

  void _move(int direction) {
    if (_items.length < 2 || !_controller.hasClients) return;
    _select((_current + direction) % _items.length);
  }

  void _select(int index) {
    if (!_controller.hasClients || index == _current) return;
    if (MediaQuery.disableAnimationsOf(context) ||
        (index - _current).abs() > 1) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> refresh() async {
    final next = _catalogue.browseFeed(CatalogueFeed.trending, refresh: true);
    setState(() => _request = next);
    try {
      await next;
    } catch (_) {
      // The existing feature remains visible if the refresh fails.
    }
  }

  void _prefetch(double width, bool compact, int index) {
    if (!_running || _didPrefetch || _items.length < 2 || index != _current) {
      return;
    }
    _didPrefetch = true;
    final next = _items[(_current + 1) % _items.length];
    final (path, kind) = _featuredImage(next, compact);
    if (path == null) return;
    final image = context.read<ArtworkPolicy>().provider(
      path,
      kind,
      width,
      MediaQuery.devicePixelRatioOf(context),
    );
    precacheImage(image, context, onError: (_, _) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = CineLayout.widthOf(context) == CineWidth.compact;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final compact = phone || width < 550;
        final height =
            (compact
                ? (width * 1.13).clamp(360.0, 455.0)
                : (width * .40).clamp(340.0, 475.0)) +
            math.max(0, (scale - 1) * 164);
        return SizedBox(
          height: height,
          child: FutureBuilder<TmdbPage>(
            future: _request,
            builder: (context, snapshot) {
              if (snapshot.hasData &&
                  snapshot.connectionState == ConnectionState.done) {
                final results = snapshot.data!.items;
                final illustrated = results.where(
                  (item) =>
                      item.backdropPath != null || item.posterPath != null,
                );
                _items = (illustrated.isEmpty ? results : illustrated)
                    .take(5)
                    .toList();
                _current = _current.clamp(0, math.max(0, _items.length - 1));
              }
              if (_items.isEmpty) {
                if (snapshot.hasError ||
                    snapshot.connectionState == ConnectionState.done) {
                  return MessageState(
                    message: snapshot.hasError
                        ? catalogueError(snapshot.error)
                        : 'No featured titles right now.',
                    onRetry: refresh,
                  );
                }
                return const CineSkeleton(radius: 22);
              }
              return Focus(
                onFocusChange: (value) {
                  _focused = value;
                  _schedule();
                },
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                        _move(-1),
                    const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                        _move(1),
                  },
                  child: MouseRegion(
                    onEnter: (_) {
                      _hovering = true;
                      _schedule();
                    },
                    onExit: (_) {
                      _hovering = false;
                      _schedule();
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(compact ? 18 : 23),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PageView.builder(
                            controller: _controller,
                            itemCount: _items.length,
                            onPageChanged: (index) {
                              setState(() => _current = index);
                              _schedule();
                            },
                            itemBuilder: (_, index) => _FeatureFrame(
                              media: _items[index],
                              compact: compact,
                              onReady: () {
                                if (mounted) {
                                  _prefetch(width, compact, index);
                                  _schedule();
                                }
                              },
                            ),
                          ),
                          if (_items.length > 1)
                            Positioned(
                              bottom: compact ? 13 : 20,
                              left: compact ? 16 : null,
                              right: compact ? 16 : 20,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: compact
                                    ? MainAxisAlignment.center
                                    : MainAxisAlignment.end,
                                children: [
                                  CineIconButton(
                                    label: 'Previous featured title',
                                    icon: Icons.chevron_left_rounded,
                                    overlay: true,
                                    onPressed: () => _move(-1),
                                  ),
                                  Flexible(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                      ),
                                      child: Text(
                                        '${_current + 1} / ${_items.length}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: cineLabel(color: ink, size: 11),
                                      ),
                                    ),
                                  ),
                                  CineIconButton(
                                    label: 'Next featured title',
                                    icon: Icons.chevron_right_rounded,
                                    overlay: true,
                                    onPressed: () => _move(1),
                                  ),
                                  ...[
                                    const SizedBox(width: 5),
                                    CineIconButton(
                                      label: _pausing
                                          ? 'Play featured carousel'
                                          : 'Pause featured carousel',
                                      icon: _pausing
                                          ? Icons.play_arrow_rounded
                                          : Icons.pause_rounded,
                                      overlay: true,
                                      onPressed: () {
                                        setState(() => _pausing = !_pausing);
                                        _schedule();
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          if (snapshot.hasError)
                            Positioned(
                              top: 14,
                              right: 14,
                              child: CineIconButton(
                                label: 'Retry featured titles',
                                icon: Icons.refresh,
                                overlay: true,
                                onPressed: refresh,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

(String?, ArtworkKind) _featuredImage(Media media, bool compact) =>
    compact && media.posterPath != null
    ? (media.posterPath, ArtworkKind.poster)
    : media.backdropPath != null
    ? (media.backdropPath, ArtworkKind.backdrop)
    : (media.posterPath, ArtworkKind.poster);

class _FeatureFrame extends StatelessWidget {
  const _FeatureFrame({
    required this.media,
    required this.compact,
    required this.onReady,
  });
  final Media media;
  final bool compact;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final (path, kind) = _featuredImage(media, compact);
    return DecoratedBox(
      decoration: const BoxDecoration(color: surface),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CineArt(
            path: path,
            kind: kind,
            alignment: const Alignment(0, -.38),
            onReady: onReady,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x40090C13),
                  Color(0xFF090C13),
                ],
                stops: [0, .37, .99],
              ),
            ),
          ),
          if (!compact)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xF0090C13),
                    Color(0xAA090C13),
                    Colors.transparent,
                  ],
                  stops: [0, .37, .87],
                ),
              ),
            ),
          Positioned(
            left: compact ? 17 : 34,
            right: compact ? 17 : 200,
            bottom: compact ? 75 : 33,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 570),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.isMovie ? 'FEATURED FILM' : 'FEATURED SERIES',
                      style: cineLabel(color: gold, size: 11),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: cineDisplay(compact ? 34 : 55),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 11,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          media.year,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        if (media.rating > 0) CineScore(media.rating),
                      ],
                    ),
                    if (!compact && media.overview.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 11),
                        child: Text(
                          media.overview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () =>
                              CineNavigation.of(context)
                                  .openTitle(context, media),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 19,
                          ),
                          label: const Text('View details'),
                        ),
                        LibraryTitleAction(media: media, compact: compact),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) => const CinePage(
    scrollKey: PageStorageKey('discover'),
    slivers: [
      CineSliver(
        top: 25,
        bottom: 20,
        child: CineHeading(
          'Discover',
          subtitle:
              'Explore movies, television, and what’s playing in cinemas.',
        ),
      ),
      CineSliver(bottom: 24, child: _BrowseLinks()),
      CineSliver(bottom: 26, child: _SpotlightPair()),
      CineSliver(bottom: 30, child: GenreLinks()),
      CineSliver(bottom: 26, child: FeedShelf(feed: CatalogueFeed.trending)),
      CineSliver(child: FeedShelf(feed: CatalogueFeed.tvOnAir)),
    ],
  );
}

class _SpotlightPair extends StatelessWidget {
  const _SpotlightPair();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth >= 650
          ? (box.maxWidth - 15) / 2
          : box.maxWidth;
      return Wrap(
        spacing: 15,
        runSpacing: 15,
        children: [
          SizedBox(
            width: width,
            child: const _BrowseSpotlight(
              feed: CatalogueFeed.popular,
              label: 'Movies',
              tab: AppTab.movies,
            ),
          ),
          SizedBox(
            width: width,
            child: const _BrowseSpotlight(
              feed: CatalogueFeed.tvPopular,
              label: 'TV Shows',
              tab: AppTab.tv,
            ),
          ),
        ],
      );
    },
  );
}

class _BrowseSpotlight extends StatefulWidget {
  const _BrowseSpotlight({
    required this.feed,
    required this.label,
    required this.tab,
  });
  final CatalogueFeed feed;
  final String label;
  final AppTab tab;

  @override
  State<_BrowseSpotlight> createState() => _BrowseSpotlightState();
}

class _BrowseSpotlightState extends State<_BrowseSpotlight> {
  late final Future<TmdbPage> _request;
  @override
  void initState() {
    super.initState();
    _request = context.read<CatalogueRepository>().browseFeed(widget.feed);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TmdbPage>(
    future: _request,
    builder: (context, snapshot) {
      final items = snapshot.data?.items ?? const <Media>[];
      final media =
          items.where((item) => item.backdropPath != null).firstOrNull ??
          items.firstOrNull;
      final path = media?.backdropPath;
      return Material(
        color: surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height:
              205 +
              math.max(0, MediaQuery.textScalerOf(context).scale(22) - 22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CineArt(
                path: path ?? media?.posterPath,
                kind: path == null ? ArtworkKind.poster : ArtworkKind.backdrop,
                alignment: const Alignment(.18, -.23),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xF5090C13)],
                  ),
                ),
              ),
              InkWell(
                onTap: () =>
                    CineNavigation.of(context).select(context, widget.tab),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(19),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.label, style: cineDisplay(29)),
                              if (media != null)
                                Text(
                                  media.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_outward_rounded, color: ink),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class MoviesPage extends StatelessWidget {
  const MoviesPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _CategoryPage(kind: MediaKind.movie);
}

class TvShowsPage extends StatelessWidget {
  const TvShowsPage({super.key});
  @override
  Widget build(BuildContext context) => const _CategoryPage(kind: MediaKind.tv);
}

class _CategoryPage extends StatelessWidget {
  const _CategoryPage({required this.kind});
  final MediaKind kind;

  @override
  Widget build(BuildContext context) {
    final movie = kind == MediaKind.movie;
    final title = movie ? 'Movies' : 'TV Shows';
    final feeds = movie
        ? const [
            CatalogueFeed.popular,
            CatalogueFeed.nowPlaying,
            CatalogueFeed.recent,
            CatalogueFeed.upcoming,
            CatalogueFeed.topRated,
          ]
        : const [
            CatalogueFeed.tvPopular,
            CatalogueFeed.tvToday,
            CatalogueFeed.tvOnAir,
            CatalogueFeed.tvTopRated,
          ];
    return CinePage(
      scrollKey: PageStorageKey(kind.name),
      slivers: [
        CineSliver(
          top: 25,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CineHeading(
                title,
                subtitle: movie
                    ? 'Browse new releases, popular films and top-rated titles.'
                    : 'Find your next series or see what’s airing today.',
              ),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: () {
                  final nav = CineNavigation.of(context);
                  nav.updateSearch(
                    context,
                    TabRoute(
                      AppTab.search,
                      discovery: (
                        kind: kind,
                        genre: null,
                        year: null,
                        minimumRating: null,
                        sort: CatalogueSort.popularity,
                      ),
                    ),
                  );
                  nav.select(context, AppTab.search);
                },
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(movie ? 'Filter movies' : 'Filter TV shows'),
              ),
            ],
          ),
        ),
        CineSliver(bottom: 24, child: GenreLinks(kind: kind)),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: CineLayout.gutterOf(context),
          ),
          sliver: SliverList.builder(
            itemCount: feeds.length,
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: FeedShelf(feed: feeds[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class GenreLinks extends StatelessWidget {
  const GenreLinks({this.kind = MediaKind.movie, super.key});
  final MediaKind kind;

  @override
  Widget build(BuildContext context) {
    final movies = kind == MediaKind.movie;
    final values = movies
        ? const [
            (28, 'Action'),
            (35, 'Comedy'),
            (18, 'Drama'),
            (27, 'Horror'),
            (878, 'Science Fiction'),
            (53, 'Thriller'),
          ]
        : const [
            (10759, 'Action & Adventure'),
            (35, 'Comedy'),
            (18, 'Drama'),
            (9648, 'Mystery'),
            (10765, 'Sci-Fi & Fantasy'),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Explore by genre', style: cineDisplay(23)),
        const SizedBox(height: 11),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final (id, name) in values)
              ActionChip(
                label: Text(name),
                onPressed: () => CineNavigation.of(
                  context,
                ).open(context, GenreRoute((kind: kind, id: id)), label: name),
              ),
          ],
        ),
      ],
    );
  }
}

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});
  @override
  Widget build(BuildContext context) => DiscoveryPage(
    title: 'Now Playing',
    subtitle: 'Films in theatrical release.',
    loader: context.read<CatalogueRepository>().feedLoader(
      CatalogueFeed.nowPlaying,
    ),
  );
}

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({
    required this.title,
    required this.loader,
    this.subtitle,
    super.key,
  });
  final String title;
  final String? subtitle;
  final PageLoader loader;

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final _pages = PagedController<Media>();
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
  Widget build(BuildContext context) => PagedBrowseView(
    pages: _pages,
    results: (items) => PosterGrid(heroPrefix: widget.title, items: items),
    heroPrefix: widget.title,
    emptyMessage: 'No titles available.',
    header: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BackButton(onPressed: () => CineNavigation.of(context).back(context)),
        const SizedBox(height: 8),
        CineHeading(widget.title, subtitle: widget.subtitle),
      ],
    ),
  );
}

class _PersonalShelf extends StatefulWidget {
  const _PersonalShelf();
  @override
  State<_PersonalShelf> createState() => _PersonalShelfState();
}

class _PersonalShelfState extends State<_PersonalShelf> {
  String? _key;
  Future<List<Media>>? _request;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<WatchlistProvider>();
    final first = provider.items.firstOrNull;
    if (first?.key == _key) return;
    _key = first?.key;
    final kind = MediaKind.parse(first?.type);
    _request = first == null || kind == null
        ? null
        : context.read<CatalogueRepository>().related((
            kind: kind.entityKind,
            id: first.id,
          ));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Media>>(
    future: _request,
    builder: (context, snapshot) {
      final library = context.read<WatchlistProvider>();
      final matches = (snapshot.data ?? const <Media>[])
          .where((item) => library.find(item.id, item.type) == null)
          .take(8)
          .toList();
      return matches.isEmpty
          ? const SizedBox.shrink()
          : PosterShelf(
              title: 'Picked for your watchlist',
              shelfId: 'personal',
              items: matches,
            );
    },
  );
}
