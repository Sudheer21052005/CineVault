import 'package:provider/provider.dart';

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
import 'graph_widgets.dart';

String? joined(Iterable<String> values, {String separator = ', '}) =>
    values.isEmpty ? null : values.join(separator);

class GraphHeading extends StatelessWidget {
  const GraphHeading(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Semantics(header: true, child: Text(label, style: cineDisplay(24))),
  );
}

class FactList extends StatelessWidget {
  const FactList(this.facts, {super.key});
  final List<(String, String?)> facts;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (label, value) in facts)
        if (value != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(color: muted),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
    ],
  );
}

class SourceLinks extends StatelessWidget {
  const SourceLinks({
    required this.ref,
    required this.data,
    this.extra,
    this.path,
    super.key,
  });
  final EntityRef ref;
  final Json data;
  final Json? extra;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final imdb = text(extra?['imdb_id']) ?? text(data['imdb_id']);
    final links = <(String, Uri)>[
      (
        'TMDB',
        Uri.https('www.themoviedb.org', path ?? '/${ref.kind.name}/${ref.id}'),
      ),
      if (website(data['homepage']) case final home?)
        ('Official website', home),
      if (imdb != null && RegExp(r'^(tt|nm)\d+$').hasMatch(imdb))
        (
          'IMDb',
          Uri.https(
            'www.imdb.com',
            '/${imdb.startsWith('nm') ? 'name' : 'title'}/$imdb/',
          ),
        ),
      if (text(extra?['wikidata_id']) case final id?)
        if (RegExp(r'^Q[1-9]\d*$').hasMatch(id))
          ('Wikidata', Uri.https('www.wikidata.org', '/wiki/$id')),
      if (path == null && ref.kind == EntityKind.tv)
        if (text(extra?['tvdb_id']?.toString()) case final id?)
          if (RegExp(r'^\d+$').hasMatch(id))
            ('TheTVDB', Uri.https('thetvdb.com', '/dereferrer/series/$id')),
      for (final (key, label, host) in const [
        ('instagram_id', 'Instagram', 'www.instagram.com'),
        ('facebook_id', 'Facebook', 'www.facebook.com'),
        ('twitter_id', 'X', 'x.com'),
      ])
        if (text(extra?[key]) case final id?)
          if (RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(id))
            (label, Uri.https(host, '/$id')),
    ];
    return GraphPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GraphHeading('External links'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, uri) in links) ExternalLink(label, uri),
            ],
          ),
        ],
      ),
    );
  }
}

class Gallery extends StatelessWidget {
  const Gallery({required this.data, required this.groups, super.key});
  final Json data;
  final List<(String, String, ArtworkKind)> groups;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (field, label, kind) in groups)
        _GalleryGroup(
          key: ValueKey(field),
          label: label,
          kind: kind,
          source: data[field],
        ),
    ],
  );
}

class _GalleryGroup extends StatefulWidget {
  const _GalleryGroup({
    required this.label,
    required this.kind,
    required this.source,
    super.key,
  });
  final String label;
  final ArtworkKind kind;
  final Object? source;

  @override
  State<_GalleryGroup> createState() => _GalleryGroupState();
}

class _GalleryGroupState extends State<_GalleryGroup> {
  static const _pageSize = 8;
  int _page = 0;

  void _preview(String path, int position, int total) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 850,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('${widget.label} · $position of $total'),
              trailing: const CloseButton(),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: AspectRatio(
                  aspectRatio:
                      widget.kind == ArtworkKind.backdrop ||
                          widget.kind == ArtworkKind.still
                      ? 16 / 9
                      : 2 / 3,
                  child: CineArt(path: path, kind: widget.kind),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final images = [
      for (final entry in objects(widget.source)) ?text(entry['file_path']),
    ];
    if (widget.source is! List) {
      return GraphMessage('${widget.label} metadata is unavailable.');
    }
    if (images.isEmpty) {
      return GraphMessage('TMDB lists no ${widget.label.toLowerCase()}.');
    }
    final start = _page * _pageSize;
    final layout = CineLayout.widthOf(context);
    final wide =
        widget.kind == ArtworkKind.backdrop || widget.kind == ArtworkKind.still;
    final width = wide
        ? (layout == CineWidth.compact ? 108.0 : 168.0)
        : (layout == CineWidth.compact ? 83.0 : 102.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.label} · ${images.length}',
            style: cineLabel(size: 14, color: ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final (index, path)
                  in images.skip(start).take(_pageSize).indexed)
                SizedBox(
                  width: width,
                  height: width * (wide ? 9 / 16 : 1.45),
                  child: Material(
                    borderRadius: BorderRadius.circular(7),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () =>
                          _preview(path, start + index + 1, images.length),
                      child: Semantics(
                        label:
                            'View ${widget.label.toLowerCase()} ${start + index + 1}',
                        button: true,
                        child: CineArt(path: path, kind: widget.kind),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (images.length > _pageSize)
            Wrap(
              spacing: 6,
              children: [
                TextButton(
                  onPressed: _page == 0 ? null : () => setState(() => _page--),
                  child: const Text('Previous images'),
                ),
                TextButton(
                  onPressed: start + _pageSize >= images.length
                      ? null
                      : () => setState(() => _page++),
                  child: const Text('Next images'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class TitleGraph extends StatelessWidget {
  const TitleGraph({required this.knowledge, super.key});
  final TitleKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    final media = knowledge.media;
    final ref = media.ref;
    final repo = context.read<CatalogueRepository>();
    final data = knowledge.data;
    final collection = knowledge.collection;
    final companies = knowledge.companies;
    final networks = knowledge.networks;
    final keywords = knowledge.keywords;
    final creators = knowledge.creators;
    late final nextSeason = knowledge.seasons
        .where((entry) => integer(entry['season_number']) != null)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _remote(
          repo,
          ref,
          KnowledgeSection.credits,
          'Cast & crew',
          Icons.groups_outlined,
          (context, result) =>
              CreditPeople(people: readCredits(result['cast'], result['crew'])),
        ),
        if (collection != null ||
            creators.isNotEmpty ||
            companies.isNotEmpty ||
            networks.isNotEmpty ||
            keywords != null)
          GraphPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GraphHeading('Explore connections'),
                if (collection != null) _LinkGroup('Collection', [collection]),
                if (creators.isNotEmpty) _LinkGroup('Created by', creators),
                if (companies.isNotEmpty)
                  _LinkGroup('Production companies', companies),
                if (networks.isNotEmpty) _LinkGroup('TV networks', networks),
                if (keywords != null)
                  _LinkGroup('Keywords', keywords)
                else
                  const GraphMessage('Keyword metadata is unavailable.'),
              ],
            ),
          ),
        if (!media.isMovie) ...[
          const SizedBox(height: 12),
          GraphPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GraphHeading('Seasons & episodes'),
                if (nextSeason.isEmpty)
                  GraphMessage(
                    data['seasons'] is List
                        ? 'TMDB lists no seasons.'
                        : 'Season metadata is unavailable.',
                  )
                else
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final season in nextSeason)
                        GraphLink(
                          text(season['name']) ??
                              'Season ${season['season_number']}',
                          SeasonRoute((
                            seriesId: media.id,
                            seasonNumber: integer(season['season_number'])!,
                          )),
                          icon: Icons.video_library_outlined,
                        ),
                    ],
                  ),
                if (data['last_episode_to_air'] != null ||
                    data['next_episode_to_air'] != null)
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: [
                      for (final (field, label) in const [
                        ('last_episode_to_air', 'Last aired'),
                        ('next_episode_to_air', 'Next episode'),
                      ])
                        if (object(data[field]) case final episode?)
                          if (_episodeRef(media.id, episode) case final ref?)
                            GraphLink(
                              '$label · ${text(episode['name']) ?? 'Episode ${ref.episodeNumber}'}',
                              EpisodeRoute(ref),
                              icon: Icons.slow_motion_video_outlined,
                            ),
                    ],
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _remote(
          repo,
          ref,
          KnowledgeSection.providers,
          'Where to watch',
          Icons.ondemand_video_rounded,
          (context, result) => WatchAvailability(result: result),
        ),
        _remote(
          repo,
          ref,
          KnowledgeSection.videos,
          'Trailers & videos',
          Icons.play_circle_outline_rounded,
          (context, result) => _Videos(data: result),
        ),
        _remote(
          repo,
          ref,
          KnowledgeSection.images,
          'Image gallery',
          Icons.photo_library_outlined,
          (context, result) => Gallery(
            data: result,
            groups: const [
              ('backdrops', 'Backdrops', ArtworkKind.backdrop),
              ('posters', 'Posters', ArtworkKind.poster),
              ('logos', 'Logos', ArtworkKind.logo),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: GraphSection(
            key: const PageStorageKey('title-reviews'),
            title: 'Reviews',
            icon: Icons.rate_review_outlined,
            builder: (_) => _Reviews(ref: ref),
          ),
        ),
        _remote(
          repo,
          ref,
          media.isMovie ? KnowledgeSection.releases : KnowledgeSection.ratings,
          media.isMovie
              ? 'Release dates & certifications'
              : 'Regional content ratings',
          Icons.event_outlined,
          (context, result) =>
              _RegionalReleases(result: result, movie: media.isMovie),
        ),
        _remote(
          repo,
          ref,
          KnowledgeSection.alternateTitles,
          'Alternate titles',
          Icons.translate_rounded,
          (context, result) => _AlternateTitles(data: result),
        ),
        _remote(
          repo,
          ref,
          KnowledgeSection.translations,
          'Localized titles & summaries',
          Icons.language_outlined,
          (context, result) => _Translations(data: result),
        ),
        for (final recommended in [false, true])
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: GraphSection(
              key: PageStorageKey('title-related-$recommended'),
              title: recommended
                  ? 'Recommended titles'
                  : (media.isMovie ? 'Similar movies' : 'Similar TV shows'),
              icon: recommended
                  ? Icons.auto_awesome_outlined
                  : Icons.copy_all_outlined,
              builder: (_) => GraphLoad<List<Media>>(
                load: ({required refresh}) => repo.related(
                  ref,
                  recommended: recommended,
                  refresh: refresh,
                ),
                builder: (_, items) => items.isEmpty
                    ? const GraphMessage(
                        'TMDB lists no related titles in this section.',
                      )
                    : PosterShelf(
                        title: 'Explore titles',
                        shelfId: '${ref.id}-related-$recommended',
                        items: items,
                      ),
              ),
            ),
          ),
        SourceLinks(ref: ref, data: data, extra: knowledge.externalIds),
      ],
    );
  }

  Widget _remote(
    CatalogueRepository repo,
    EntityRef ref,
    KnowledgeSection section,
    String title,
    IconData icon,
    GraphBuilder<Json> paint,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: GraphSection(
      key: PageStorageKey('title-${section.name}'),
      title: title,
      icon: icon,
      builder: (_) => GraphLoad<Json>(
        load: ({required refresh}) =>
            repo.section(ref, section, refresh: refresh),
        builder: paint,
      ),
    ),
  );
}

EpisodeRef? _episodeRef(int series, Json item) {
  final season = integer(item['season_number']);
  final episode = integer(item['episode_number']);
  return season != null && season >= 0 && episode != null && episode > 0
      ? (seriesId: series, seasonNumber: season, episodeNumber: episode)
      : null;
}

class _LinkGroup extends StatelessWidget {
  const _LinkGroup(this.label, this.links);
  final String label;
  final List<EntityLink> links;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: cineLabel(color: muted)),
        if (links.isEmpty)
          const GraphMessage('TMDB lists none for this title.')
        else
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              for (final entity in links)
                GraphLink(entity.name, TitleRoute(entity.ref)),
            ],
          ),
      ],
    ),
  );
}

class WatchAvailability extends StatefulWidget {
  const WatchAvailability({required this.result, super.key});
  final Json result;

  @override
  State<WatchAvailability> createState() => _WatchAvailabilityState();
}

class _WatchAvailabilityState extends State<WatchAvailability> {
  late String _region =
      WidgetsBinding.instance.platformDispatcher.locale.countryCode
          ?.toUpperCase() ??
      'US';
  late final _markets = context.read<CatalogueRepository>().watchRegions();

  @override
  Widget build(BuildContext context) {
    final result = object(widget.result['results']);
    if (result == null) {
      return const GraphMessage('Watch availability metadata is unavailable.');
    }
    final offers = object(result[_region]);
    return FutureBuilder<Json>(
      future: _markets,
      builder: (context, snapshot) {
        final markets = <String, String>{
          _region: _region,
          for (final key in result.keys) key: key,
        };
        for (final country in objects(snapshot.data?['results'])) {
          final code = text(country['iso_3166_1']);
          if (code != null) {
            markets[code] = text(country['english_name']) ?? code;
          }
        }
        final codes = markets.keys.toList()
          ..sort((a, b) => markets[a]!.compareTo(markets[b]!));
        final groups = [
          for (final (key, label) in const [
            ('flatrate', 'Subscription'),
            ('free', 'Free'),
            ('ads', 'With ads'),
            ('rent', 'Rent'),
            ('buy', 'Buy'),
          ])
            if (objects(offers?[key]).isNotEmpty)
              (label, objects(offers?[key])),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 335),
              child: DropdownButtonFormField<String>(
                initialValue: _region,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Watch market'),
                items: [
                  for (final code in codes)
                    DropdownMenuItem(value: code, child: Text(markets[code]!)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _region = value);
                },
              ),
            ),
            const SizedBox(height: 10),
            const GraphMessage(
              'Availability data provided by JustWatch via TMDB.',
            ),
            if (groups.isEmpty)
              GraphMessage('No offers are listed for ${markets[_region]}.'),
            for (final (label, entries) in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: cineLabel(color: ink, size: 14)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final entry in entries)
                          if (text(entry['provider_name']) case final provider?)
                            Chip(
                              avatar: text(entry['logo_path']) == null
                                  ? null
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: SizedBox.square(
                                        dimension: 21,
                                        child: CineArt(
                                          path: text(entry['logo_path']),
                                          kind: ArtworkKind.logo,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                              label: Text(provider),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            if (website(offers?['link']) case final url?)
              ExternalLink('See watch options on TMDB', url),
          ],
        );
      },
    );
  }
}

Uri? _videoUrl(Json item) {
  final key = text(item['key']);
  if (key == null) return null;
  return switch (item['site']) {
    'YouTube' when RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(key) => Uri.https(
      'www.youtube.com',
      '/watch',
      {'v': key},
    ),
    'Vimeo' when RegExp(r'^\d+$').hasMatch(key) => Uri.https(
      'vimeo.com',
      '/$key',
    ),
    _ => null,
  };
}

class _Videos extends StatelessWidget {
  const _Videos({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    final videos = [
      for (final item in objects(data['results']))
        if (text(item['name']) case final name?)
          (
            name,
            text(item['type']) ?? 'Video',
            _videoUrl(item),
            item['official'] == true,
          ),
    ];
    if (data['results'] is! List) {
      return const GraphMessage('Video metadata is unavailable.');
    }
    if (videos.isEmpty) {
      return const GraphMessage('TMDB lists no trailers or videos.');
    }
    videos.sort((a, b) {
      int rank((String, String, Uri?, bool) value) =>
          (value.$2 == 'Trailer' ? 0 : (value.$2 == 'Teaser' ? 2 : 4)) +
          (value.$4 ? 0 : 1);
      return rank(a).compareTo(rank(b));
    });
    return _BatchedRows(
      count: videos.length,
      item: (index) {
        final (name, type, url, official) = videos[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.play_circle_outline, color: blue),
          title: Text(name),
          subtitle: Text('$type${official ? ' · Official' : ''}'),
          trailing: url == null ? null : ExternalLink('Play', url),
        );
      },
    );
  }
}

class _Reviews extends StatefulWidget {
  const _Reviews({required this.ref});
  final EntityRef ref;

  @override
  State<_Reviews> createState() => _ReviewsState();
}

class _ReviewsState extends State<_Reviews> {
  int _page = 1;

  @override
  Widget build(BuildContext context) => GraphLoad<Json>(
    key: ValueKey(_page),
    load: ({required refresh}) => context.read<CatalogueRepository>().section(
      widget.ref,
      KnowledgeSection.reviews,
      page: _page,
      refresh: refresh,
    ),
    builder: (context, data) {
      if (data['results'] is! List) {
        return const GraphMessage('Review metadata is unavailable.');
      }
      final list = objects(data['results']).toList();
      if (list.isEmpty) return const GraphMessage('TMDB lists no reviews.');
      final total = (integer(data['total_pages']) ?? _page).clamp(1, 500);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BatchedRows(
            key: ValueKey(_page),
            count: list.length,
            item: (index) {
              final review = list[index];
              final rating = object(review['author_details'])?['rating'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(text(review['author']) ?? 'TMDB user'),
                  subtitle: Text(
                    [
                      ?text(review['created_at'])?.split('T').first,
                      if (rating is num) '$rating / 10',
                    ].join(' · '),
                  ),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text(review['content']) ?? 'Review text is unavailable.',
                    ),
                    if (website(review['url']) case final url?)
                      ExternalLink('Read on TMDB', url),
                  ],
                ),
              );
            },
          ),
          if (total > 1)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: _page > 1 ? () => setState(() => _page--) : null,
                  child: const Text('Previous reviews'),
                ),
                Text('Page $_page of $total'),
                TextButton(
                  onPressed: _page < total
                      ? () => setState(() => _page++)
                      : null,
                  child: const Text('Next reviews'),
                ),
              ],
            ),
        ],
      );
    },
  );
}

class _BatchedRows extends StatefulWidget {
  const _BatchedRows({required this.count, required this.item, super.key});
  final int count;
  final Widget Function(int) item;
  @override
  State<_BatchedRows> createState() => _BatchedRowsState();
}

class _BatchedRowsState extends State<_BatchedRows> {
  static const size = 8;
  int batch = 0;
  @override
  Widget build(BuildContext context) {
    final start = batch * size;
    final end = (start + size).clamp(0, widget.count);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = start; index < end; index++)
          KeyedSubtree(key: ValueKey(index), child: widget.item(index)),
        if (widget.count > size)
          Wrap(
            spacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: batch > 0 ? () => setState(() => batch--) : null,
                child: const Text('Previous entries'),
              ),
              Text('${start + 1}–$end of ${widget.count}'),
              TextButton(
                onPressed: end < widget.count
                    ? () => setState(() => batch++)
                    : null,
                child: const Text('Next entries'),
              ),
            ],
          ),
      ],
    );
  }
}

class _RegionalReleases extends StatefulWidget {
  const _RegionalReleases({required this.result, required this.movie});
  final Json result;
  final bool movie;
  @override
  State<_RegionalReleases> createState() => _RegionalReleasesState();
}

class _RegionalReleasesState extends State<_RegionalReleases> {
  late String _region =
      WidgetsBinding.instance.platformDispatcher.locale.countryCode
          ?.toUpperCase() ??
      'US';

  @override
  Widget build(BuildContext context) {
    if (widget.result['results'] is! List) {
      return const GraphMessage('Regional release metadata is unavailable.');
    }
    final regions = <String, Json>{
      for (final group in objects(widget.result['results']))
        ?text(group['iso_3166_1']): group,
    };
    if (regions.isEmpty) {
      return const GraphMessage('TMDB lists no regional release information.');
    }
    final keys = {_region, ...regions.keys}.toList()..sort();
    final data = regions[_region];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 285),
          child: DropdownButtonFormField<String>(
            initialValue: _region,
            decoration: const InputDecoration(labelText: 'Release market'),
            items: [
              for (final iso in keys)
                DropdownMenuItem(value: iso, child: Text(iso)),
            ],
            onChanged: (iso) {
              if (iso != null) setState(() => _region = iso);
            },
          ),
        ),
        const SizedBox(height: 8),
        if (data == null)
          GraphMessage('No release information is listed for $_region.')
        else if (!widget.movie)
          GraphMessage(
            text(data['rating']) ?? 'No certification is listed for $_region.',
          )
        else ...[
          for (final entry in objects(data['release_dates']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                text(entry['release_date'])?.split('T').first ??
                    'Date unavailable',
              ),
              subtitle: Text(
                [
                  switch (entry['type']) {
                    1 => 'Premiere',
                    2 => 'Limited theatrical',
                    3 => 'Theatrical',
                    4 => 'Digital',
                    5 => 'Physical',
                    6 => 'TV',
                    _ => 'Release',
                  },
                  ?text(entry['certification']),
                  ?text(entry['note']),
                ].join(' · '),
              ),
            ),
          if (objects(data['release_dates']).isEmpty)
            GraphMessage('No release dates are listed for $_region.'),
        ],
      ],
    );
  }
}

class _AlternateTitles extends StatelessWidget {
  const _AlternateTitles({required this.data});
  final Json data;
  @override
  Widget build(BuildContext context) {
    final source = data['titles'] ?? data['results'];
    if (source is! List) {
      return const GraphMessage('Alternate-title metadata is unavailable.');
    }
    final titles = objects(source)
        .where((entry) => text(entry['title']) != null)
        .toList();
    if (titles.isEmpty) {
      return const GraphMessage('TMDB lists no alternate titles.');
    }
    return _BatchedRows(
      count: titles.length,
      item: (index) {
        final entry = titles[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(text(entry['title'])!),
          subtitle: Text(
            [?text(entry['iso_3166_1']), ?text(entry['type'])].join(' · '),
          ),
        );
      },
    );
  }
}

class _Translations extends StatelessWidget {
  const _Translations({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    final source = data['translations'];
    if (source is! List) {
      return const GraphMessage('Translation metadata is unavailable.');
    }
    final entries = objects(source).toList();
    if (entries.isEmpty) {
      return const GraphMessage('TMDB lists no localized metadata.');
    }
    return _BatchedRows(
      count: entries.length,
      item: (index) {
        final record = entries[index];
        final content = object(record['data']);
        final name =
            text(record['english_name']) ??
            text(record['name']) ??
            'Language unavailable';
        final localTitle = text(content?['title']) ?? text(content?['name']);
        final code = text(record['iso_3166_1']);
        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('$name${code == null ? '' : ' · $code'}'),
          subtitle: localTitle == null ? null : Text(localTitle),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GraphMessage(
              text(content?['overview']) ??
                  'No summary is listed for this translation.',
            ),
          ],
        );
      },
    );
  }
}
