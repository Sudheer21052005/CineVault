import 'dart:math' as math;

import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:provider/provider.dart';

import '../app/navigation_scope.dart';
import '../app/route_contract.dart';
import '../catalogue/artwork_policy.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/entity_ref.dart';
import '../catalogue/knowledge_models.dart';
import '../core/material.dart';
import '../models/media.dart';
import '../library/personal_models.dart';
import '../library/personal_library.dart';
import 'artwork.dart';
import 'catalogue_widgets.dart';
import 'design_system.dart';
import 'library.dart';
import 'media_sections.dart';
import 'personal_actions.dart';

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
  late final _catalogue = context.read<CatalogueRepository>();
  final _scroll = _TitleScrollController();
  final _tabAnchor = GlobalKey();
  final _sectionOffsets = <TitleSection, double>{};
  final _palette = ValueNotifier<Color>(const Color(0xFF314D76));
  TitleSection _section = TitleSection.overview;
  late Future<TitleKnowledge> _request;
  TitleKnowledge? _lastGood;
  bool _restoredTab = false;

  @override
  void initState() {
    super.initState();
    _request = _fetch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredTab) return;
    _restoredTab = true;
    final previous = PageStorage.maybeOf(context)
        ?.readState(context, identifier: 'title-selected-section');
    if (previous is TitleSection) _section = previous;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _palette.dispose();
    super.dispose();
  }

  Future<TitleKnowledge> _fetch({bool refresh = false}) async =>
      _lastGood = await _catalogue.titleKnowledge(widget.ref, refresh: refresh);

  void _select(TitleSection section) {
    if (_section == section) return;
    final header = _tabAnchor.currentContext?.findRenderObject();
    if (_scroll.hasClients && header is RenderSliver) {
      final pinOffset = header.constraints.precedingScrollExtent;
      final pixels = _scroll.position.pixels;
      _sectionOffsets[_section] = math.max(0, pixels - pinOffset);
      _scroll.restoreAtLayout(
        pixels >= pinOffset
            ? pinOffset + (_sectionOffsets[section] ?? 0)
            : pixels,
      );
    }
    setState(() => _section = section);
    PageStorage.maybeOf(context)
        ?.writeState(context, section, identifier: 'title-selected-section');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TitleKnowledge>(
    future: _request,
    builder: (context, snapshot) {
      final knowledge = snapshot.data ?? _lastGood;
      final item = knowledge?.media ?? widget.summary;
      final compact = CineLayout.widthOf(context) == CineWidth.compact;
      final personal =
          item != null && context.watch<PersonalLibrary?>()?.ready == true
          ? PersonalActions(
              key: ValueKey(item.key),
              title: PersonalTitle.media(item, data: knowledge?.data),
              details: knowledge,
              compact: compact,
            )
          : null;
      final sections = [
        for (final section in TitleSection.values)
          if (section != TitleSection.seasons ||
              widget.ref.kind == EntityKind.tv)
            section,
      ];
      final tabHeight =
          (MediaQuery.textScalerOf(context).scale(14) / 14 * 23 + 29).clamp(
            52.0,
            94.0,
          );
      Widget sectionBody(TitleSection section) {
        final blocks = <WidgetBuilder>[
          if (item != null &&
              (section == TitleSection.overview ||
                  section == TitleSection.details))
            (_) => _DetailOverview(
              media: item,
              raw: section == TitleSection.details ? knowledge?.data : null,
              showStory: section == TitleSection.overview,
            ),
          if (knowledge != null) ...titleSectionBlocks(knowledge, section),
        ];
        return SliverPadding(
          key: ValueKey(section),
          padding: EdgeInsets.fromLTRB(
            CineLayout.gutterOf(context),
            19,
            CineLayout.gutterOf(context),
            12,
          ),
          sliver: SliverList.builder(
            itemCount: blocks.length,
            itemBuilder: (context, index) => _RetainedTitleBlock(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: section == TitleSection.overview
                    ? blocks[index](context)
                    : TweenAnimationBuilder<double>(
                        duration: cineMotion(context, 155),
                        tween: Tween(begin: .88, end: 1),
                        curve: Curves.easeOutCubic,
                        child: blocks[index](context),
                        builder: (_, opacity, child) =>
                            Opacity(opacity: opacity, child: child),
                      ),
              ),
            ),
          ),
        );
      }

      return ValueListenableBuilder<Color>(
        valueListenable: _palette,
        child: CinePage(
          controller: _scroll,
          scrollKey: PageStorageKey(
            'details-${widget.ref.kind.name}-${widget.ref.id}',
          ),
          slivers: [
            if (item == null)
              CineSliver(
                top: 17,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (CineLayout.widthOf(context) == CineWidth.compact)
                      const _DetailBack(),
                    if (!snapshot.hasError)
                      const CineSkeleton(height: 345, radius: 22),
                  ],
                ),
              )
            else
              CineSliver(
                top: 16,
                bottom: 11,
                child: _DetailBillboard(
                  media: item,
                  heroTag: widget.heroTag,
                  onPalette: (value) => _palette.value = value,
                  compactActions: compact ? personal : null,
                ),
              ),
            if (snapshot.hasError)
              CineSliver(
                bottom: 13,
                child: MessageState(
                  icon: Icons.cloud_off_rounded,
                  message: catalogueError(snapshot.error),
                  onRetry: () {
                    final retry = _fetch(refresh: true);
                    setState(() {
                      _request = retry;
                    });
                  },
                ),
              ),
            if (!compact && personal != null)
              CineSliver(bottom: 9, child: personal),
            if (item != null)
              SliverPersistentHeader(
                key: _tabAnchor,
                pinned: true,
                delegate: _TitleTabHeader(
                  sections: sections,
                  active: _section,
                  onSelect: _select,
                  height: tabHeight,
                  gutter: CineLayout.gutterOf(context),
                ),
              ),
            if (item != null &&
                knowledge == null &&
                _section != TitleSection.overview &&
                !snapshot.hasError)
              const CineSliver(top: 14, child: CineSkeleton(height: 120)),
            if (item != null) ...[
              if (_section == TitleSection.overview ||
                  _sectionOffsets.containsKey(TitleSection.overview))
                SliverOffstage(
                  offstage: _section != TitleSection.overview,
                  sliver: TickerMode(
                    enabled: _section == TitleSection.overview,
                    child: ExcludeFocus(
                      excluding: _section != TitleSection.overview,
                      child: sectionBody(TitleSection.overview),
                    ),
                  ),
                ),
              if (_section != TitleSection.overview) sectionBody(_section),
              // Short tabs must still allow the header to remain pinned.
              SliverLayoutBuilder(
                builder: (_, tail) {
                  final header = _tabAnchor.currentContext?.findRenderObject();
                  final pinOffset = header is RenderSliver
                      ? header.constraints.precedingScrollExtent
                      : 0.0;
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: math.max(
                        0,
                        tail.viewportMainAxisExtent -
                            (tail.precedingScrollExtent - pinOffset),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        builder: (context, tone, child) => AnimatedContainer(
          duration: cineMotion(context, 320),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(.46, -.89),
              radius: 1.18,
              colors: [
                Color.alphaBlend(tone.withValues(alpha: .34), canvas),
                canvas,
              ],
            ),
          ),
          child: child,
        ),
      );
    },
  );
}

// Keep the few lazily mounted blocks alive within the selected section.
// Re-entering a block reuses its resolved content and measured extent.
class _RetainedTitleBlock extends StatefulWidget {
  const _RetainedTitleBlock({required this.child});
  final Widget child;

  @override
  State<_RetainedTitleBlock> createState() => _RetainedTitleBlockState();
}

class _RetainedTitleBlockState extends State<_RetainedTitleBlock>
    with AutomaticKeepAliveClientMixin<_RetainedTitleBlock> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _TitleScrollController extends ScrollController {
  void restoreAtLayout(double offset) {
    final current = position as _TitleScrollPosition;
    current.goIdle();
    current.nextOffset = offset;
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _TitleScrollPosition(physics, context, oldPosition);
}

class _TitleScrollPosition extends ScrollPositionWithSingleContext {
  _TitleScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) : super(physics: physics, context: context, oldPosition: oldPosition);

  double? nextOffset;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final target = nextOffset;
    nextOffset = null;
    if (target != null) {
      final offset = target.clamp(minScrollExtent, maxScrollExtent);
      if (offset != pixels) {
        correctPixels(offset);
        return false;
      }
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}

class _TitleTabHeader extends SliverPersistentHeaderDelegate {
  const _TitleTabHeader({
    required this.sections,
    required this.active,
    required this.onSelect,
    required this.height,
    required this.gutter,
  });
  final List<TitleSection> sections;
  final TitleSection active;
  final ValueChanged<TitleSection> onSelect;
  final double height, gutter;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  bool shouldRebuild(covariant _TitleTabHeader oldDelegate) =>
      active != oldDelegate.active ||
      height != oldDelegate.height ||
      gutter != oldDelegate.gutter ||
      sections.length != oldDelegate.sections.length;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: const Color(0xFF111A29),
    child: Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: gutter),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: outline)),
      ),
      child: DefaultTabController(
        length: sections.length,
        initialIndex: sections.indexOf(active),
        animationDuration: cineMotion(context, 190),
        child: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 15),
          labelColor: blue,
          unselectedLabelColor: muted,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorColor: blue,
          dividerColor: Colors.transparent,
          onTap: (index) => onSelect(sections[index]),
          tabs: [for (final section in sections) Tab(text: section.label)],
        ),
      ),
    ),
  );
}

class _DetailBack extends StatelessWidget {
  const _DetailBack();

  @override
  Widget build(BuildContext context) => BackButton(
    onPressed: () => CineNavigation.of(context).back(context),
    style: IconButton.styleFrom(
      backgroundColor: canvas.withValues(alpha: .84),
      foregroundColor: ink,
      minimumSize: const Size.square(46),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: outline),
      ),
    ),
  );
}

class _DetailBillboard extends StatelessWidget {
  const _DetailBillboard({
    required this.media,
    required this.onPalette,
    this.heroTag,
    this.compactActions,
  });
  final Media media;
  final String? heroTag;
  final ValueChanged<Color> onPalette;
  final Widget? compactActions;

  Widget _poster(BuildContext context, double width) => SizedBox(
    width: width,
    height: width * 1.5,
    child: sharedArt(
      context,
      heroTag,
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CineArt(path: media.posterPath),
      ),
    ),
  );

  Widget _image() => Stack(
    fit: StackFit.expand,
    children: [
      CineArt(
        path: media.backdropPath ?? media.posterPath,
        kind: media.backdropPath == null
            ? ArtworkKind.poster
            : ArtworkKind.backdrop,
        alignment: const Alignment(.10, -.20),
        onPalette: onPalette,
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x19090D16), Color(0x00090D16), Color(0xF0090D16)],
            stops: [0, .54, 1],
          ),
        ),
      ),
    ],
  );

  Widget _copy(BuildContext context, bool compact) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${media.isMovie ? 'MOVIE' : 'TV SHOW'}  ·  ${media.year}',
        style: cineLabel(color: gold),
      ),
      const SizedBox(height: 5),
      Semantics(
        header: true,
        child: Text(
          media.title,
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: cineDisplay(compact ? 32 : 62),
        ),
      ),
      const SizedBox(height: 9),
      Wrap(
        spacing: 11,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (media.rating > 0) CineScore(media.rating),
          if (media.isMovie && media.runtime != null)
            Text('${media.runtime} min'),
          if (media.seasons case final seasons?)
            Text('$seasons ${seasons == 1 ? 'season' : 'seasons'}'),
          if (media.genres.isNotEmpty)
            Text(
              media.genres.take(2).join(' / '),
              style: const TextStyle(color: muted),
            ),
        ],
      ),
      if (!compact) ...[
        const SizedBox(height: 15),
        LibraryTitleAction(media: media, shortLabel: true),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = CineLayout.widthOf(context) == CineWidth.compact;
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      if (compact) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: ColoredBox(
            color: const Color(0xFF111A29),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.70,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _image(),
                      const Positioned(top: 9, left: 9, child: _DetailBack()),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (media.posterPath != null) ...[
                            _poster(context, 60),
                            const SizedBox(width: 13),
                          ],
                          Expanded(child: _copy(context, true)),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          LibraryTitleAction(media: media, shortLabel: true),
                          ?compactActions,
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      final height =
          (box.maxWidth * .418).clamp(350.0, 490.0) +
          math.max(0, (scale - 1) * 190);
      return ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _image(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xF10A0E18),
                      Color(0x9A0A0E18),
                      Colors.transparent,
                    ],
                    stops: [0, .38, .94],
                  ),
                ),
              ),
              Positioned(
                left: 25,
                right: 25,
                bottom: 26,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (media.posterPath != null) ...[
                      _poster(context, 122),
                      const SizedBox(width: 21),
                    ],
                    Expanded(child: _copy(context, false)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DetailOverview extends StatelessWidget {
  const _DetailOverview({
    required this.media,
    this.raw,
    required this.showStory,
  });
  final bool showStory;
  final Media media;
  final Json? raw;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = showStory && box.maxWidth >= 760;
      final primaryWidth = wide ? box.maxWidth * .63 - 10 : box.maxWidth;
      final secondaryWidth = wide
          ? box.maxWidth - primaryWidth - 19
          : box.maxWidth;
      return Wrap(
        spacing: 19,
        runSpacing: 15,
        children: [
          if (showStory)
            SizedBox(
              width: primaryWidth,
              child: DetailSection(
                title: 'Storyline',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (media.tagline case final String tagline)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          tagline,
                          style: const TextStyle(
                            color: gold,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    Text(
                      media.overview.isEmpty
                          ? 'No overview is available for this title.'
                          : media.overview,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: muted),
                    ),
                    if (media.genres.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (media.linkedGenres.isNotEmpty)
                              for (final genre in media.linkedGenres)
                                ActionChip(
                                  label: Text(genre.name),
                                  onPressed: () =>
                                      CineNavigation.of(context).open(
                                        context,
                                        GenreRoute((
                                          kind: media.isMovie
                                              ? MediaKind.movie
                                              : MediaKind.tv,
                                          id: genre.id,
                                        )),
                                        label: genre.name,
                                      ),
                                )
                            else
                              for (final name in media.genres)
                                Chip(label: Text(name)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SizedBox(
            width: secondaryWidth,
            child: DetailSection(
              title: 'Title information',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.isMovie
                        ? 'Release year: ${media.year}'
                        : 'First aired: ${media.year}',
                  ),
                  if (media.releaseStatus != null)
                    Text('Status: ${media.releaseStatus}'),
                  if (media.isMovie && media.runtime != null)
                    Text('Runtime: ${media.runtime} minutes'),
                  if (media.seasons != null) Text('Seasons: ${media.seasons}'),
                  if (media.episodes != null)
                    Text('Episodes: ${media.episodes}'),
                  if (media.episodeRuntime != null)
                    Text('Episode runtime: ${media.episodeRuntime} minutes'),
                  if (media.rating > 0)
                    Text(
                      'TMDB score: ${media.rating.toStringAsFixed(1)} / 10',
                      style: const TextStyle(color: gold),
                    ),
                  if (raw case final data?)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FactList([
                        ('Original title', _originalTitle(data)),
                        (
                          media.isMovie ? 'Release date' : 'First air date',
                          text(
                            data[media.isMovie
                                ? 'release_date'
                                : 'first_air_date'],
                          ),
                        ),
                        ('Last aired', text(data['last_air_date'])),
                        (
                          'Production status',
                          data['in_production'] == true
                              ? 'In production'
                              : null,
                        ),
                        ('Format', text(data['type'])),
                        (
                          'Countries',
                          joined(names(data['production_countries'], 'name')) ??
                              joined(strings(data['origin_country'])),
                        ),
                        ('Original language', text(data['original_language'])),
                        (
                          'Spoken languages',
                          joined(
                            names(data['spoken_languages'], 'english_name'),
                          ),
                        ),
                        ('Budget', _usd(data['budget'])),
                        ('Worldwide revenue', _usd(data['revenue'])),
                        (
                          'Votes',
                          media.voteCount > 0 ? '${media.voteCount}' : null,
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  String? _originalTitle(Json data) {
    final original = text(
      data[media.isMovie ? 'original_title' : 'original_name'],
    );
    return original == media.title ? null : original;
  }

  String? _usd(Object? value) {
    if (value is! int || value <= 0) return null;
    final digits = value.toString();
    final formatted = StringBuffer('USD ');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) formatted.write(',');
      formatted.write(digits[i]);
    }
    return formatted.toString();
  }
}

class DetailSection extends StatelessWidget {
  const DetailSection({required this.title, required this.child, super.key});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => CinePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: cineDisplay(25))),
        const SizedBox(height: 13),
        child,
      ],
    ),
  );
}
