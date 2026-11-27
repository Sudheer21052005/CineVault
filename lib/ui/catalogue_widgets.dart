import 'dart:async';

import 'package:provider/provider.dart';

import '../app/navigation_scope.dart';
import '../app/route_contract.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/entity_ref.dart';
import '../catalogue/paged_controller.dart';
import '../core/material.dart';
import '../core/network/tmdb_transport.dart';
import '../models/media.dart';
import 'artwork.dart';
import 'design_system.dart';

String catalogueError(Object? error) => error is TmdbException
    ? error.toString()
    : 'Unable to load catalogue data. Please retry.';

class PosterCard extends StatefulWidget {
  const PosterCard({required this.media, required this.heroTag, super.key});
  final Media media;
  final String heroTag;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool hover = false;
  bool focus = false;

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final titleStyle = Theme.of(context).textTheme.titleMedium!;
    final titleHeight =
        MediaQuery.textScalerOf(context).scale(titleStyle.fontSize!) *
        titleStyle.height! *
        2;
    void open() =>
        CineNavigation.of(context)
            .openTitle(context, media, heroTag: widget.heroTag);
    final label =
        '${media.title} ${media.year}'
        '${media.rating > 0 ? ' · ${media.rating.toStringAsFixed(1)} ★' : ''}';
    return Semantics(
      label: label,
      button: true,
      onTap: open,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: open,
          onHover: (value) => setState(() => hover = value),
          onFocusChange: (value) => setState(() => focus = value),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Hero(
                        tag: widget.heroTag,
                        child: CineArt(path: media.posterPath),
                      ),
                    ),
                    if (!media.isMovie)
                      const Positioned(
                        left: 8,
                        top: 8,
                        child: _ContentBadge('TV'),
                      ),
                    IgnorePointer(
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 140),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: focus
                                ? blue
                                : hover
                                ? const Color(0xFF9CAFCB)
                                : Colors.white12,
                            width: focus ? 2.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: titleHeight,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    media.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle.copyWith(
                      color: hover || focus ? blue : ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      media.year,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (media.rating > 0)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: CineScore(media.rating),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentBadge extends StatelessWidget {
  const _ContentBadge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xDB090C13),
      border: Border.all(color: Colors.white30),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(text, style: cineLabel(color: ink, size: 10)),
    ),
  );
}

class PagedBrowseView<T extends CatalogueItem> extends StatelessWidget {
  const PagedBrowseView({
    required this.pages,
    required this.header,
    required this.heroPrefix,
    required this.emptyMessage,
    required this.results,
    this.scrollKey,
    this.scroll,
    this.onFirstPaint,
    this.idle,
    this.refresh = true,
    super.key,
  });

  final PagedController<T> pages;
  final Widget Function(List<T>) results;
  final Widget header;
  final ScrollController? scroll;
  final PageStorageKey<String>? scrollKey;
  final VoidCallback? onFirstPaint;
  final String heroPrefix;
  final String emptyMessage;
  final Widget? idle;
  final bool refresh;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: pages,
    builder: (context, _) {
      final state = pages.state;
      if ((state.status == PageStatus.ready ||
              state.status == PageStatus.failed) &&
          onFirstPaint != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onFirstPaint!());
      }
      return NotificationListener<ScrollNotification>(
        onNotification: (event) {
          if (event.depth == 0 &&
              (event is ScrollUpdateNotification ||
                  event is ScrollEndNotification) &&
              event.metrics.extentAfter < 600) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) unawaited(pages.loadNext());
            });
          }
          return false;
        },
        child: CinePage(
          controller: scroll,
          scrollKey: scrollKey,
          onRefresh: refresh ? pages.refresh : null,
          slivers: [
            CineSliver(top: 24, bottom: 26, child: header),
            if (state.status == PageStatus.idle && idle != null)
              CineSliver(child: idle!),
            if (state.error != null)
              CineSliver(
                bottom: 18,
                child: MessageState(
                  icon: Icons.cloud_off_rounded,
                  message: catalogueError(state.error),
                  onRetry: pages.refresh,
                ),
              ),
            if (state.status == PageStatus.loading)
              PosterGrid(heroPrefix: heroPrefix, skeletons: 14)
            else if (state.items.isNotEmpty)
              results(state.items)
            else if (state.status == PageStatus.ready)
              CineSliver(child: MessageState(message: emptyMessage)),
            if (state.loadingNext ||
                state.nextError != null ||
                (state.hasMore &&
                    state.items.isEmpty &&
                    state.status == PageStatus.ready))
              CineSliver(
                top: 18,
                child: Center(child: nextPageAction(pages, state)),
              ),
          ],
        ),
      );
    },
  );
}

class PosterGrid extends StatelessWidget {
  const PosterGrid({
    required this.heroPrefix,
    this.items = const [],
    this.skeletons,
    super.key,
  });

  final List<Media> items;
  final int? skeletons;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) => CatalogueGrid(
    count: skeletons ?? items.length,
    itemBuilder: (_, index) => skeletons != null
        ? const PosterSkeleton()
        : PosterCard(
            media: items[index],
            heroTag: '$heroPrefix-${items[index].key}',
          ),
  );
}

class CatalogueGrid extends StatelessWidget {
  const CatalogueGrid({
    required this.count,
    required this.itemBuilder,
    this.extraHeight = 0,
    super.key,
  });

  final int count;
  final IndexedWidgetBuilder itemBuilder;
  final double extraHeight;

  @override
  Widget build(BuildContext context) {
    const gap = 14.0;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: CineLayout.gutterOf(context)),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final extent = constraints.crossAxisExtent;
          final columns = cineColumns(extent, scale);
          final width = (extent - (columns - 1) * gap) / columns;
          return SliverGrid.builder(
            itemCount: count,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: gap,
              mainAxisSpacing: 10,
              mainAxisExtent:
                  cineCardHeight(width, scale) + extraHeight * scale,
            ),
            itemBuilder: itemBuilder,
          );
        },
      ),
    );
  }
}

class PosterSkeleton extends StatelessWidget {
  const PosterSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AspectRatio(aspectRatio: 2 / 3, child: CineSkeleton()),
      SizedBox(height: 10),
      FractionallySizedBox(
        widthFactor: .75,
        alignment: Alignment.centerLeft,
        child: CineSkeleton(height: 11, radius: 4),
      ),
      SizedBox(height: 8),
      FractionallySizedBox(
        widthFactor: .36,
        alignment: Alignment.centerLeft,
        child: CineSkeleton(height: 8, radius: 4),
      ),
    ],
  );
}

Widget nextPageAction<T extends CatalogueItem>(
  PagedController<T> pages,
  PageState<T> state,
) => state.loadingNext
    ? const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
    : OutlinedButton.icon(
        onPressed: () => pages.loadNext(retry: state.nextError != null),
        icon: Icon(state.nextError == null ? Icons.more_horiz : Icons.refresh),
        label: Text(
          state.nextError == null ? 'Load more' : 'Retry loading more',
        ),
      );

class FeedShelf extends StatefulWidget {
  const FeedShelf({required this.feed, this.title, super.key});
  final CatalogueFeed feed;
  final String? title;

  @override
  State<FeedShelf> createState() => FeedShelfState();
}

class FeedShelfState extends State<FeedShelf> {
  final _pages = PagedController<Media>();

  @override
  void initState() {
    super.initState();
    _pages.setQuery(
      context.read<CatalogueRepository>().feedLoader(widget.feed),
    );
  }

  Future<void> refresh() => _pages.refresh();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _pages,
    builder: (context, _) {
      final data = _pages.state;
      final title = widget.title ?? widget.feed.label;
      return PosterShelf(
        title: title,
        shelfId: 'feed-${widget.feed.name}',
        items: data.items,
        loading: data.status == PageStatus.loading,
        action: () =>
            CineNavigation.of(context)
                .open(context, FeedRoute(widget.feed), label: title),
        notice: data.error == null
            ? null
            : MessageState(
                message: catalogueError(data.error),
                onRetry: refresh,
              ),
        onNearEnd: _pages.loadNext,
        trailing: data.loadingNext || data.nextError != null
            ? nextPageAction(_pages, data)
            : null,
      );
    },
  );
}

class PosterShelf extends StatefulWidget {
  const PosterShelf({
    required this.title,
    required this.shelfId,
    required this.items,
    this.loading = false,
    this.action,
    this.notice,
    this.onNearEnd,
    this.trailing,
    super.key,
  });

  final String title;
  final String shelfId;
  final List<Media> items;
  final bool loading;
  final VoidCallback? action;
  final Widget? notice;
  final VoidCallback? onNearEnd;
  final Widget? trailing;

  @override
  State<PosterShelf> createState() => _PosterShelfState();
}

class _PosterShelfState extends State<PosterShelf> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_nearEnd);
  }

  void _nearEnd() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 420) {
      widget.onNearEnd?.call();
    }
  }

  void _move(int direction) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final next =
        (position.pixels + position.viewportDimension * .77 * direction).clamp(
          0.0,
          position.maxScrollExtent,
        );
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _scroll.jumpTo(next);
    } else {
      _scroll.animateTo(
        next,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = CineLayout.widthOf(context) == CineWidth.compact;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final width = switch (CineLayout.widthOf(context)) {
      CineWidth.compact => 126.0,
      CineWidth.medium => 145.0,
      CineWidth.expanded => 163.0,
    };
    final show = widget.items.isNotEmpty || widget.loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  widget.title,
                  style: cineDisplay(compact ? 24 : 28),
                ),
              ),
            ),
            if (widget.action != null)
              TextButton.icon(
                onPressed: widget.action,
                label: const Text('See all'),
                icon: const Icon(Icons.arrow_outward_rounded, size: 16),
              ),
            if (!compact && widget.items.length > 4) ...[
              const SizedBox(width: 5),
              CineIconButton(
                label: 'Scroll ${widget.title} left',
                icon: Icons.chevron_left,
                onPressed: () => _move(-1),
              ),
              const SizedBox(width: 5),
              CineIconButton(
                label: 'Scroll ${widget.title} right',
                icon: Icons.chevron_right,
                onPressed: () => _move(1),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (widget.notice != null) widget.notice!,
        if (!show && widget.notice == null)
          const Text('No titles available.', style: TextStyle(color: muted)),
        if (show)
          SizedBox(
            height: cineCardHeight(width, scale),
            child: ListView.separated(
              key: PageStorageKey(widget.shelfId),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 3),
              itemCount: widget.loading
                  ? 7
                  : widget.items.length + (widget.trailing == null ? 0 : 1),
              separatorBuilder: (_, _) => SizedBox(width: compact ? 11 : 14),
              itemBuilder: (_, index) {
                final item = widget.items.elementAtOrNull(index);
                final child = widget.loading
                    ? const PosterSkeleton()
                    : item == null
                    ? Center(child: widget.trailing)
                    : PosterCard(
                        media: item,
                        heroTag: '${widget.shelfId}-${item.key}',
                      );
                return SizedBox(width: width, child: child);
              },
            ),
          ),
      ],
    );
  }
}
