import 'package:provider/provider.dart';

import '../app/navigation_scope.dart';
import '../app/route_contract.dart';
import '../catalogue/artwork_policy.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/entity_ref.dart';
import '../catalogue/knowledge_models.dart';
import '../core/material.dart';
import '../library/personal_library.dart';
import '../library/personal_models.dart';
import 'artwork.dart';
import 'design_system.dart';
import 'graph_widgets.dart';
import 'media_sections.dart';
import 'personal_actions.dart';

String _seasonLabel(int season) => season == 0 ? 'Specials' : 'Season $season';

class SeasonPage extends StatelessWidget {
  const SeasonPage({required this.ref, super.key});
  final SeasonRef ref;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CatalogueRepository>();
    final series = (kind: EntityKind.tv, id: ref.seriesId);
    return GraphLoad<Json>(
      fullPage: true,
      load: ({required refresh}) => repo.season(ref, refresh: refresh),
      builder: (context, data) {
        final episodes = [
          for (final entry in objects(data['episodes']))
            if ((integer(entry['episode_number']) ?? 0) > 0) entry,
        ];
        return CinePage(
          scrollKey: const PageStorageKey('season'),
          slivers: [
            CineSliver(
              top: 23,
              bottom: 15,
              child: GraphHeader(
                title: text(data['name']) ?? _seasonLabel(ref.seasonNumber),
                category: _seasonLabel(ref.seasonNumber),
                image: text(data['poster_path']),
                subtitle: joined([
                  if (data['episodes'] is List) '${episodes.length} episodes',
                  ?text(data['air_date']),
                ], separator: ' · '),
                actions: [
                  if (context.watch<PersonalLibrary?>()?.ready == true)
                    OutlinedButton(
                      child: const Text('Save season schedule'),
                      onPressed: () async {
                        final library = context.read<PersonalLibrary>();
                        final title = await _seriesTitle(repo, library, series);
                        if (context.mounted) {
                          await personalWrite(
                            context,
                            library.saveSeason(
                              seasonFromJson(
                                title,
                                ref.seriesId,
                                ref.seasonNumber,
                                data,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  GraphLink(
                    'View series',
                    TitleRoute(series),
                    icon: Icons.tv_rounded,
                  ),
                ],
              ),
            ),
            if (text(data['overview']) case final overview?)
              CineSliver(bottom: 14, child: GraphPanel(child: Text(overview))),
            CineSliver(
              bottom: 14,
              child: GraphSection(
                key: const PageStorageKey('season-credits'),
                title: 'Season cast & crew',
                icon: Icons.groups_outlined,
                builder: (_) => GraphLoad<Json>(
                  load: ({required refresh}) =>
                      repo.seasonCredits(ref, refresh: refresh),
                  builder: (_, result) => CreditPeople(
                    people: readCredits(result['cast'], result['crew']),
                  ),
                ),
              ),
            ),
            const CineSliver(bottom: 8, child: GraphHeading('Episodes')),
            if (episodes.isEmpty)
              CineSliver(
                bottom: 12,
                child: GraphMessage(
                  data['episodes'] is List
                      ? 'TMDB lists no episodes for this season.'
                      : 'Episode metadata is unavailable.',
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: CineLayout.gutterOf(context),
              ),
              sliver: SliverList.builder(
                itemCount: episodes.length,
                itemBuilder: (context, index) =>
                    _EpisodeRow(ref: ref, data: episodes[index]),
              ),
            ),
            CineSliver(
              top: 12,
              child: SourceLinks(
                ref: series,
                data: data,
                extra: object(data['external_ids']),
                path: SeasonRoute(ref).uri.path,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.ref, required this.data});
  final SeasonRef ref;
  final Json data;
  @override
  Widget build(BuildContext context) {
    final episode = integer(data['episode_number'])!;
    final title = text(data['name']) ?? 'Episode $episode';
    final route = EpisodeRoute((
      seriesId: ref.seriesId,
      seasonNumber: ref.seasonNumber,
      episodeNumber: episode,
    ));
    final details = [
      'Episode $episode',
      ?text(data['air_date']),
      if (integer(data['runtime']) case final runtime? when runtime > 0)
        '$runtime min',
      ?_rating(data),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () =>
              CineNavigation.of(context).open(context, route, label: title),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: CineLayout.widthOf(context) == CineWidth.compact
                      ? 86
                      : 162,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CineArt(
                        path: text(data['still_path']),
                        kind: ArtworkKind.still,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        details.join(' · '),
                        style: const TextStyle(color: muted),
                      ),
                      if (text(data['overview']) case final overview?)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            overview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: blue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EpisodePage extends StatelessWidget {
  const EpisodePage({required this.ref, super.key});
  final EpisodeRef ref;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CatalogueRepository>();
    final season = (seriesId: ref.seriesId, seasonNumber: ref.seasonNumber);
    final series = (kind: EntityKind.tv, id: ref.seriesId);
    return GraphLoad<Json>(
      fullPage: true,
      load: ({required refresh}) => repo.episode(ref, refresh: refresh),
      builder: (context, data) => CinePage(
        scrollKey: const PageStorageKey('episode'),
        slivers: [
          CineSliver(
            top: 23,
            bottom: 15,
            child: GraphHeader(
              title: text(data['name']) ?? 'Episode ${ref.episodeNumber}',
              category:
                  '${_seasonLabel(ref.seasonNumber)} · Episode ${ref.episodeNumber}',
              image: text(data['still_path']),
              artKind: ArtworkKind.still,
              subtitle: joined([
                ?text(data['air_date']),
                if (integer(data['runtime']) case final runtime?
                    when runtime > 0)
                  '$runtime min',
                ?_rating(data),
              ], separator: ' · '),
              actions: [
                EpisodeWatchAction(PersonalTitle.episode(ref, data)),
                PersonalActions(title: PersonalTitle.episode(ref, data)),
                GraphLink(
                  _seasonLabel(ref.seasonNumber),
                  SeasonRoute(season),
                  icon: Icons.video_library_outlined,
                ),
                GraphLink(
                  'View series',
                  TitleRoute(series),
                  icon: Icons.tv_rounded,
                ),
              ],
            ),
          ),
          CineSliver(
            bottom: 13,
            child: GraphPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GraphHeading('Overview'),
                  Text(
                    text(data['overview']) ??
                        'Episode overview is unavailable.',
                  ),
                  const SizedBox(height: 8),
                  FactList([
                    ('Production code', text(data['production_code'])),
                    ('Episode type', text(data['episode_type'])),
                  ]),
                ],
              ),
            ),
          ),
          CineSliver(
            bottom: 10,
            child: GraphSection(
              key: const PageStorageKey('episode-guests'),
              title: 'Guest stars',
              icon: Icons.person_add_alt_rounded,
              builder: (_) => CreditPeople(
                people: readCredits(data['guest_stars'], null),
                showRoleFilters: false,
              ),
            ),
          ),
          CineSliver(
            bottom: 10,
            child: GraphSection(
              key: const PageStorageKey('episode-crew'),
              title: 'Episode crew',
              icon: Icons.groups_outlined,
              builder: (_) => CreditPeople(
                people: readCredits(null, data['crew']),
                showRoleFilters: false,
              ),
            ),
          ),
          CineSliver(
            bottom: 10,
            child: GraphSection(
              key: const PageStorageKey('episode-stills'),
              title: 'Episode stills',
              icon: Icons.photo_library_outlined,
              builder: (_) => GraphLoad<Json>(
                load: ({required refresh}) =>
                    repo.episodeImages(ref, refresh: refresh),
                builder: (_, data) => Gallery(
                  title: text(data['name']) ?? 'Episode ${ref.episodeNumber}',
                  data: data,
                  groups: const [('stills', 'Stills', ArtworkKind.still)],
                ),
              ),
            ),
          ),
          CineSliver(
            child: SourceLinks(
              ref: series,
              data: data,
              extra: object(data['external_ids']),
              path: EpisodeRoute(ref).uri.path,
            ),
          ),
        ],
      ),
    );
  }
}

Future<PersonalTitle> _seriesTitle(
  CatalogueRepository repo,
  PersonalLibrary library,
  EntityRef ref,
) async {
  final known = library.state.seasons.values
      .where((season) => season.series.key == '/tv/${ref.id}')
      .firstOrNull
      ?.series;
  if (known != null) return known;
  try {
    final title = await repo.titleKnowledge(ref);
    return PersonalTitle.media(title.media, data: title.data);
  } catch (_) {
    return PersonalTitle(TitleRoute(ref), 'Series ${ref.id}');
  }
}

String? _rating(Json entry) {
  final average = entry['vote_average'];
  final votes = integer(entry['vote_count']);
  return average is num && votes != null && votes > 0
      ? 'TMDB ${average.toStringAsFixed(1)} / 10 ($votes votes)'
      : null;
}
