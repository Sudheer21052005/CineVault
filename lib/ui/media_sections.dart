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
import 'artwork_gallery.dart';
import 'catalogue_widgets.dart';
import 'design_system.dart';
import 'graph_widgets.dart';

export 'artwork_gallery.dart' show Gallery;

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

enum TitleSection {
  overview('Overview'),
  credits('Cast & crew'),
  seasons('Seasons'),
  related('Related'),
  media('Media'),
  details('Details'),
  reviews('Reviews');

  const TitleSection(this.label);
  final String label;
}

List<WidgetBuilder> titleSectionBlocks(
  TitleKnowledge knowledge,
  TitleSection section,
) {
  final media = knowledge.media;
  final ref = media.ref;
  final data = knowledge.data;

  WidgetBuilder remote(
    KnowledgeSection field,
    String label,
    GraphBuilder<Json> build,
  ) =>
      (context) => _SectionGroup(
        label,
        child: GraphLoad<Json>(
          load: ({required refresh}) => context
              .read<CatalogueRepository>()
              .section(ref, field, refresh: refresh),
          builder: build,
        ),
      );

  WidgetBuilder related(bool recommended) =>
      (context) => GraphLoad<List<Media>>(
        load: ({required refresh}) => context
            .read<CatalogueRepository>()
            .related(ref, recommended: recommended, refresh: refresh),
        builder: (_, items) {
          final label = recommended
              ? 'Recommended titles'
              : media.isMovie
              ? 'Similar movies'
              : 'Similar TV shows';
          return items.isEmpty
              ? _SectionGroup(
                  label,
                  child: const GraphMessage(
                    'TMDB lists no related titles here.',
                  ),
                )
              : PosterShelf(
                  title: label,
                  shelfId: '${ref.id}-${section.name}-$recommended',
                  items: items,
                );
        },
      );

  final availability = remote(
    KnowledgeSection.providers,
    'Where to watch',
    (_, result) => WatchAvailability(result: result),
  );
  Widget connections(BuildContext _) => _SectionGroup(
    'Explore connections',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (knowledge.collection case final collection?)
          _LinkGroup('Collection', [collection]),
        if (knowledge.creators.isNotEmpty)
          _LinkGroup('Created by', knowledge.creators),
        if (knowledge.companies.isNotEmpty)
          _LinkGroup('Production companies', knowledge.companies),
        if (knowledge.networks.isNotEmpty)
          _LinkGroup('TV networks', knowledge.networks),
        if (knowledge.keywords case final keywords?)
          _LinkGroup('Keywords', keywords)
        else
          const GraphMessage('Keyword metadata is unavailable.'),
      ],
    ),
  );

  return switch (section) {
    TitleSection.overview => [
      (context) => GraphLoad<Json>(
        load: ({required refresh}) => context
            .read<CatalogueRepository>()
            .section(ref, KnowledgeSection.credits, refresh: refresh),
        builder: (_, result) => _CreditSpotlight(
          knowledge: knowledge,
          people: readCredits(result['cast'], result['crew']),
        ),
      ),
      if (!media.isMovie) (_) => _SeasonSections(knowledge, compactList: true),
      availability,
      related(true),
      related(false),
    ],
    TitleSection.credits => [
      remote(
        KnowledgeSection.credits,
        'Full credits',
        (_, result) =>
            CreditPeople(people: readCredits(result['cast'], result['crew'])),
      ),
    ],
    TitleSection.seasons => [(_) => _SeasonSections(knowledge)],
    TitleSection.related => [related(true), related(false), connections],
    TitleSection.media => [
      remote(
        KnowledgeSection.images,
        'Artwork',
        (_, result) => Gallery(
          title: media.title,
          data: result,
          groups: const [
            ('backdrops', 'Backdrops', ArtworkKind.backdrop),
            ('posters', 'Posters', ArtworkKind.poster),
          ],
        ),
      ),
      remote(
        KnowledgeSection.videos,
        'Trailers & videos',
        (_, result) => _Videos(data: result),
      ),
    ],
    TitleSection.details => [
      connections,
      remote(
        media.isMovie ? KnowledgeSection.releases : KnowledgeSection.ratings,
        media.isMovie
            ? 'Release dates & certifications'
            : 'Regional content ratings',
        (_, result) => _RegionalReleases(result: result, movie: media.isMovie),
      ),
      remote(
        KnowledgeSection.alternateTitles,
        'Alternate titles',
        (_, result) => _AlternateTitles(data: result),
      ),
      remote(
        KnowledgeSection.translations,
        'Localized titles & summaries',
        (_, result) => _Translations(data: result),
      ),
      (_) => SourceLinks(ref: ref, data: data, extra: knowledge.externalIds),
    ],
    TitleSection.reviews => [
      (_) => _SectionGroup('Viewer reviews', child: _Reviews(ref: ref)),
    ],
  };
}

class _SectionGroup extends StatelessWidget {
  const _SectionGroup(this.title, {required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => GraphPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [GraphHeading(title), child],
    ),
  );
}

class _CreditSpotlight extends StatelessWidget {
  const _CreditSpotlight({required this.knowledge, required this.people});
  final TitleKnowledge knowledge;
  final List<PersonCredit>? people;

  @override
  Widget build(BuildContext context) {
    final directors = [
      for (final credit in people ?? const <PersonCredit>[])
        if (credit.roles.any((role) => !role.cast && role.role == 'Director'))
          credit.person,
    ];
    final cast = (people ?? const <PersonCredit>[])
        .where((credit) => credit.roles.any((role) => role.cast))
        .take(10)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (directors.isNotEmpty) _LinkGroup('Director', directors),
        if (knowledge.creators.isNotEmpty)
          _LinkGroup('Created by', knowledge.creators),
        const GraphHeading('Top cast'),
        if (cast.isEmpty)
          GraphMessage(
            people == null
                ? 'Cast data is unavailable.'
                : 'No cast credits are listed.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth / 3.1).clamp(100.0, 154.0);
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              return SizedBox(
                height: width * 1.5 + 73 * scale,
                child: ListView.separated(
                  key: const PageStorageKey('spotlight-cast'),
                  scrollDirection: Axis.horizontal,
                  itemCount: cast.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 11),
                  itemBuilder: (_, index) {
                    final credit = cast[index];
                    return SizedBox(
                      width: width,
                      child: EntityResultCard(
                        link: EntityLink(
                          credit.person.ref,
                          credit.person.name,
                          image: credit.person.image,
                          caption: credit.roles
                              .firstWhere((role) => role.cast)
                              .role,
                        ),
                        heroTag:
                            'spotlight-${knowledge.media.key}-${credit.person.ref.id}',
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

class _SeasonSections extends StatelessWidget {
  const _SeasonSections(this.knowledge, {this.compactList = false});
  final TitleKnowledge knowledge;
  final bool compactList;

  @override
  Widget build(BuildContext context) {
    final media = knowledge.media;
    final data = knowledge.data;
    final seasons = knowledge.seasons.where(
      (entry) => (integer(entry['season_number']) ?? -1) >= 0,
    );
    return _SectionGroup(
      'Seasons & episodes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (seasons.isEmpty)
            GraphMessage(
              data['seasons'] is List
                  ? 'TMDB lists no seasons.'
                  : 'Season metadata is unavailable.',
            )
          else if (compactList)
            Wrap(
              spacing: 7,
              runSpacing: 5,
              children: [
                for (final season in seasons.take(6))
                  GraphLink(
                    text(season['name']) ?? 'Season ${season['season_number']}',
                    SeasonRoute((
                      seriesId: media.id,
                      seasonNumber: integer(season['season_number'])!,
                    )),
                    icon: Icons.video_library_outlined,
                  ),
              ],
            )
          else
            _BatchedRows(
              count: seasons.length,
              item: (index) {
                final season = seasons.elementAt(index);
                final number = integer(season['season_number'])!;
                final name = text(season['name']) ?? 'Season $number';
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: SizedBox(
                    width: 39,
                    height: 54,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: CineArt(path: text(season['poster_path'])),
                    ),
                  ),
                  title: Text(name),
                  subtitle: Text(
                    [
                      if (integer(season['episode_count']) case final count?)
                        '$count episodes',
                      ?text(season['air_date']),
                    ].join('  ·  '),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => CineNavigation.of(context).open(
                    context,
                    SeasonRoute((seriesId: media.id, seasonNumber: number)),
                    label: name,
                  ),
                );
              },
            ),
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
    );
  }
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
