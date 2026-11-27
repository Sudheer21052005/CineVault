import 'dart:math' as math;

import 'package:provider/provider.dart';

import '../app/navigation_scope.dart';
import '../app/route_contract.dart';
import '../catalogue/artwork_policy.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/entity_ref.dart';
import '../catalogue/knowledge_models.dart';
import '../core/material.dart';
import '../models/media.dart';
import 'artwork.dart';
import 'catalogue_widgets.dart';
import 'design_system.dart';
import 'library.dart';
import 'media_sections.dart';

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
  late Future<TitleKnowledge> _request;
  TitleKnowledge? _lastGood;

  @override
  void initState() {
    super.initState();
    _request = _fetch();
  }

  Future<TitleKnowledge> _fetch({bool refresh = false}) async =>
      _lastGood = await _catalogue.titleKnowledge(widget.ref, refresh: refresh);

  @override
  Widget build(BuildContext context) => FutureBuilder<TitleKnowledge>(
    future: _request,
    builder: (context, snapshot) {
      final knowledge = snapshot.data ?? _lastGood;
      final item = knowledge?.media ?? widget.summary;
      return Material(
        color: canvas,
        child: CinePage(
          scrollKey: PageStorageKey(
            'details-${widget.ref.kind.name}-${widget.ref.id}',
          ),
          slivers: [
            if (item == null)
              CineSliver(
                top: 20,
                bottom: 15,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (CineLayout.widthOf(context) == CineWidth.compact) ...[
                      const _DetailBack(),
                      const SizedBox(height: 12),
                    ],
                    if (!snapshot.hasError)
                      const CineSkeleton(height: 345, radius: 22),
                  ],
                ),
              )
            else
              CineSliver(
                top: 20,
                bottom: 25,
                child: _DetailBillboard(media: item, heroTag: widget.heroTag),
              ),
            if (snapshot.hasError)
              CineSliver(
                bottom: 17,
                child: MessageState(
                  icon: Icons.cloud_off_rounded,
                  message: catalogueError(snapshot.error),
                  onRetry: () =>
                      setState(() => _request = _fetch(refresh: true)),
                ),
              ),
            if (item != null)
              CineSliver(
                bottom: 20,
                child: _DetailOverview(media: item, raw: knowledge?.data),
              ),
            if (knowledge != null)
              CineSliver(child: TitleGraph(knowledge: knowledge)),
          ],
        ),
      );
    },
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
  const _DetailBillboard({required this.media, this.heroTag});
  final Media media;
  final String? heroTag;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = CineLayout.widthOf(context) == CineWidth.compact;
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final height =
          (compact ? 353.0 : (box.maxWidth * .41).clamp(340.0, 455.0)) +
          math.max(0, (scale - 1) * 182);
      final poster = ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: CineArt(path: media.posterPath),
      );
      return SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 18 : 24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CineArt(
                path: media.backdropPath ?? media.posterPath,
                kind: media.backdropPath == null
                    ? ArtworkKind.poster
                    : ArtworkKind.backdrop,
                alignment: const Alignment(.10, -.28),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x20090C13),
                      Color(0x49090C13),
                      Color(0xFF090C13),
                    ],
                    stops: [0, .30, .99],
                  ),
                ),
              ),
              if (!compact)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xE9090C13),
                        Color(0x8E090C13),
                        Colors.transparent,
                      ],
                      stops: [0, .29, .85],
                    ),
                  ),
                ),
              if (compact)
                const Positioned(top: 13, left: 13, child: _DetailBack()),
              Positioned(
                left: compact ? 16 : 30,
                right: compact ? 16 : 30,
                bottom: compact ? 19 : 28,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!compact)
                      Container(
                        width: 138,
                        height: 207,
                        margin: const EdgeInsets.only(right: 22),
                        child: heroTag == null
                            ? poster
                            : Hero(tag: heroTag!, child: poster),
                      ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            media.isMovie ? 'MOVIE' : 'TV SHOW',
                            style: cineLabel(color: gold),
                          ),
                          const SizedBox(height: 7),
                          Semantics(
                            header: true,
                            child: Text(
                              media.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: cineDisplay(compact ? 38 : 61),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 13,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                media.year,
                                style: const TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (media.runtime != null)
                                Text(
                                  '${media.runtime} min',
                                  style: const TextStyle(color: ink),
                                ),
                              if (media.seasons != null)
                                Text(
                                  '${media.seasons} ${media.seasons == 1 ? 'season' : 'seasons'}',
                                  style: const TextStyle(color: ink),
                                ),
                              if (media.rating > 0) CineScore(media.rating),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LibraryTitleAction(media: media),
                        ],
                      ),
                    ),
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
  const _DetailOverview({required this.media, this.raw});
  final Media media;
  final Json? raw;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 760;
      final primaryWidth = wide ? box.maxWidth * .63 - 10 : box.maxWidth;
      final secondaryWidth = wide
          ? box.maxWidth - primaryWidth - 19
          : box.maxWidth;
      return Wrap(
        spacing: 19,
        runSpacing: 15,
        children: [
          SizedBox(
            width: primaryWidth,
            child: DetailSection(
              title: 'Overview',
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
