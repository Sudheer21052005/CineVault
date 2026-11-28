import '../core/network/tmdb_transport.dart';
import '../core/performance.dart';
import '../models/media.dart';
import 'entity_ref.dart';
import 'knowledge_models.dart';

enum SearchScope { all, movie, tv, person, collection, company, keyword }

enum KnowledgeSection {
  credits('credits'),
  videos('videos'),
  images('images'),
  reviews('reviews'),
  providers('watch/providers'),
  releases('release_dates'),
  ratings('content_ratings'),
  translations('translations'),
  alternateTitles('alternative_titles');

  const KnowledgeSection(this.path);
  final String path;
}

enum CatalogueSort {
  popularity('Popularity', 'popularity.desc'),
  rating('Rating', 'vote_average.desc'),
  release('Release date', 'primary_release_date.desc');

  const CatalogueSort(this.label, this.movieValue);
  final String label;
  final String movieValue;

  String valueFor(MediaKind kind) => kind == MediaKind.tv && this == release
      ? 'first_air_date.desc'
      : movieValue;
}

typedef DiscoveryQuery = ({
  MediaKind kind,
  int? genre,
  int? year,
  double? minimumRating,
  CatalogueSort sort,
});

const defaultDiscovery = (
  kind: MediaKind.movie,
  genre: null,
  year: null,
  minimumRating: null,
  sort: CatalogueSort.popularity,
);

enum CatalogueFeed {
  trending(
    'Trending this week',
    '/trending/movie/week',
    MediaKind.movie,
    PerfArea.trending,
  ),
  popular(
    'Popular movies',
    '/movie/popular',
    MediaKind.movie,
    PerfArea.popular,
  ),
  nowPlaying(
    'Now playing',
    '/movie/now_playing',
    MediaKind.movie,
    PerfArea.releaseFeed,
  ),
  recent(
    'Recently released',
    '/discover/movie',
    MediaKind.movie,
    PerfArea.releaseFeed,
  ),
  upcoming(
    'Upcoming releases',
    '/discover/movie',
    MediaKind.movie,
    PerfArea.releaseFeed,
  ),
  topRated(
    'Top rated movies',
    '/movie/top_rated',
    MediaKind.movie,
    PerfArea.releaseFeed,
  ),
  tvPopular('Popular TV shows', '/tv/popular', MediaKind.tv, PerfArea.tvFeed),
  tvToday('Airing today', '/tv/airing_today', MediaKind.tv, PerfArea.tvFeed),
  tvOnAir('On the air', '/tv/on_the_air', MediaKind.tv, PerfArea.tvFeed),
  tvTopRated('Top rated', '/tv/top_rated', MediaKind.tv, PerfArea.tvFeed);

  const CatalogueFeed(this.label, this.path, this.kind, this.operation);
  final String label;
  final String path;
  final MediaKind kind;
  final PerfArea operation;
}

typedef Genre = ({int id, String name});
typedef PageLoader = CatalogueLoader<Media>;
typedef CatalogueLoader<T extends CatalogueItem> =
    Future<CataloguePage<T>> Function(int page, {required bool refresh});

typedef TmdbPage = CataloguePage<Media>;

class CataloguePage<T extends CatalogueItem> {
  const CataloguePage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalResults,
  });

  final List<T> items;
  final int page;
  final int totalPages;
  final int totalResults;

  bool get hasMore => page < totalPages && page < 500;
}

class CatalogueRepository {
  CatalogueRepository(this.transport, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final TmdbTransport transport;
  final DateTime Function() _now;
  static const imageBase = 'https://image.tmdb.org/t/p/w500';
  static const backdropBase = 'https://image.tmdb.org/t/p/w1280';
  static const _detailTtl = Duration(hours: 24);

  PageLoader feedLoader(CatalogueFeed feed) =>
      (page, {required refresh}) =>
          browseFeed(feed, page: page, refresh: refresh);

  Future<TmdbPage> browseFeed(
    CatalogueFeed feed, {
    int page = 1,
    bool refresh = false,
  }) async {
    final today = _now();
    final query = switch (feed) {
      CatalogueFeed.recent => {
        'sort_by': 'primary_release_date.desc',
        'primary_release_date.gte': _date(
          today.subtract(const Duration(days: 90)),
        ),
        'primary_release_date.lte': _date(today),
        'region': 'IN',
        'vote_count.gte': '20',
      },
      CatalogueFeed.upcoming => {
        'sort_by': 'primary_release_date.asc',
        'primary_release_date.gte': _date(today),
        'primary_release_date.lte': _date(today.add(const Duration(days: 180))),
        'vote_count.gte': '20',
      },
      _ => const <String, String>{},
    };
    if (feed == CatalogueFeed.upcoming) {
      // Page one selects the source for the feed. Subsequent raw/Discover
      // pages use the same dataset even if a later page happens to be empty.
      final first = await _page(
        feed.path,
        feed.operation,
        1,
        kind: feed.kind,
        query: query,
        refresh: page == 1 && refresh,
      );
      if (first.items.isEmpty) {
        return _page(
          '/movie/upcoming',
          feed.operation,
          page,
          kind: feed.kind,
          refresh: refresh,
        );
      }
      if (page == 1) return first;
    }
    return _page(
      feed.path,
      feed.operation,
      page,
      kind: feed.kind,
      query: query,
      refresh: refresh,
    );
  }

  Future<TmdbPage> search(
    String text,
    SearchScope scope, {
    int page = 1,
    bool refresh = false,
  }) => _page(
    '/search/${scope == SearchScope.all ? 'multi' : scope.name}',
    PerfArea.textSearch,
    page,
    kind: MediaKind.parse(scope.name),
    query: {'query': text.trim(), 'include_adult': 'false'},
    ttl: const Duration(minutes: 5),
    refresh: refresh,
  );

  Future<CataloguePage<SearchHit>> universalSearch(
    String term,
    SearchScope scope, {
    int page = 1,
    bool refresh = false,
  }) async {
    final lookup = externalReference(term);
    if (lookup != null) {
      final result = await transport.get(
        '/find/${lookup.value}',
        operation: PerfArea.textSearch,
        query: {'external_source': lookup.source},
        ttl: const Duration(minutes: 5),
        refresh: refresh,
      );
      final hits = <SearchHit>[
        for (final kind in [EntityKind.movie, EntityKind.tv, EntityKind.person])
          if (scope == SearchScope.all || scope.name == kind.name)
            for (final entry in objects(result['${kind.name}_results']))
              ?_searchHit(entry, kind.name),
        if (scope == SearchScope.all || scope == SearchScope.tv) ...[
          for (final entry in objects(result['tv_season_results']))
            ?_findTv(entry, episode: false),
          for (final entry in objects(result['tv_episode_results']))
            ?_findTv(entry, episode: true),
        ],
      ];
      return CataloguePage(
        items: hits,
        page: 1,
        totalPages: 1,
        totalResults: hits.length,
      );
    }
    final result = await transport.get(
      '/search/${scope == SearchScope.all ? 'multi' : scope.name}',
      operation: PerfArea.textSearch,
      query: {
        'query': term.trim(),
        'page': '$page',
        if (scope != SearchScope.company && scope != SearchScope.keyword)
          'include_adult': 'false',
      },
      ttl: const Duration(minutes: 5),
      refresh: refresh,
    );
    final hits = [
      for (final entry in _array(result['results']))
        ?_searchHit(
          entry,
          scope == SearchScope.all ? text(entry['media_type']) : scope.name,
        ),
    ];
    return CataloguePage(
      items: hits,
      page: integer(result['page']) ?? page,
      totalPages: integer(result['total_pages']) ?? page,
      totalResults: integer(result['total_results']) ?? hits.length,
    );
  }

  SearchHit? _searchHit(Json entry, String? type) {
    if (entry['adult'] == true) return null;
    final kind = EntityKind.values
        .where((value) => value.name == type)
        .firstOrNull;
    if (kind == null) return null;
    if (kind == EntityKind.movie || kind == EntityKind.tv) {
      final media = Media.fromJson(entry, forcedType: kind.name);
      return media.id > 0 ? SearchHit.title(media) : null;
    }
    final link = EntityLink.read(entry, kind);
    return link == null ? null : SearchHit.entity(link);
  }

  SearchHit? _findTv(Json entry, {required bool episode}) {
    final show = integer(entry['show_id']);
    final season = integer(entry['season_number']);
    final number = integer(entry['episode_number']);
    final name = text(entry['name']);
    if (show == null ||
        show <= 0 ||
        season == null ||
        season < 0 ||
        name == null) {
      return null;
    }
    final link = EntityLink(
      (kind: EntityKind.tv, id: show),
      name,
      caption: episode ? 'Season $season · Episode $number' : 'Season $season',
      image: text(entry[episode ? 'still_path' : 'poster_path']),
    );
    if (!episode) {
      return SearchHit.season(link, (seriesId: show, seasonNumber: season));
    }
    return number == null || number <= 0
        ? null
        : SearchHit.episode(link, (
            seriesId: show,
            seasonNumber: season,
            episodeNumber: number,
          ));
  }

  Future<TmdbPage> discover(
    DiscoveryQuery filters, {
    int page = 1,
    bool refresh = false,
  }) {
    final kind = filters.kind;
    return _page(
      '/discover/${kind.name}',
      PerfArea.discover,
      page,
      kind: kind,
      query: {
        'include_adult': 'false',
        'sort_by': filters.sort.valueFor(kind),
        'vote_count.gte': '20',
        if (filters.genre != null) 'with_genres': '${filters.genre}',
        if (filters.year != null)
          (kind == MediaKind.tv
                  ? 'first_air_date_year'
                  : 'primary_release_year'):
              '${filters.year}',
        if (filters.minimumRating != null)
          'vote_average.gte': '${filters.minimumRating}',
      },
      refresh: refresh,
    );
  }

  Future<List<Genre>> genres(MediaKind kind, {bool refresh = false}) async {
    final data = await transport.get(
      '/genre/${kind.name}/list',
      operation: PerfArea.genres,
      ttl: const Duration(days: 7),
      refresh: refresh,
    );
    return [
      for (final genre in _array(data['genres']))
        if (genre['id'] case final int id when id > 0)
          if (genre['name'] case final String name when name.isNotEmpty)
            (id: id, name: name),
    ];
  }

  Future<Media> details(EntityRef ref, {bool refresh = false}) async =>
      (await titleKnowledge(ref, refresh: refresh)).media;

  Future<TitleKnowledge> titleKnowledge(
    EntityRef ref, {
    bool refresh = false,
  }) async {
    final kind = MediaKind.parse(ref.kind.name);
    if (kind == null) throw const TmdbException(TmdbErrorKind.rejected);
    final data = await transport.get(
      '/${kind.name}/${ref.id}',
      operation: PerfArea.titleDetails,
      query: const {'append_to_response': 'external_ids,keywords'},
      ttl: _detailTtl,
      refresh: refresh,
    );
    final media = Media.fromJson(data, forcedType: kind.name);
    if (media.ref != ref) {
      throw const TmdbException(TmdbErrorKind.invalidResponse);
    }
    return TitleKnowledge(media, data);
  }

  Future<Json> entity(EntityRef ref, {bool refresh = false}) => _knowledge(
    '/${ref.kind.name}/${ref.id}',
    query: ref.kind == EntityKind.person
        ? const {'append_to_response': 'external_ids'}
        : const {},
    refresh: refresh,
  );

  Future<Json> filmography(int personId, {bool refresh = false}) =>
      _knowledge('/person/$personId/combined_credits', refresh: refresh);

  Future<Json> season(SeasonRef ref, {bool refresh = false}) => _knowledge(
    '/tv/${ref.seriesId}/season/${ref.seasonNumber}',
    query: const {'append_to_response': 'external_ids'},
    refresh: refresh,
  );

  Future<Json> episode(EpisodeRef ref, {bool refresh = false}) => _knowledge(
    '/tv/${ref.seriesId}/season/${ref.seasonNumber}/episode/${ref.episodeNumber}',
    query: const {'append_to_response': 'external_ids'},
    refresh: refresh,
  );

  Future<Json> seasonCredits(SeasonRef ref, {bool refresh = false}) =>
      _knowledge(
        '/tv/${ref.seriesId}/season/${ref.seasonNumber}/aggregate_credits',
        refresh: refresh,
      );

  Future<Json> section(
    EntityRef ref,
    KnowledgeSection section, {
    int page = 1,
    bool refresh = false,
  }) => _knowledge(
    '/${ref.kind.name}/${ref.id}/${section == KnowledgeSection.credits && ref.kind == EntityKind.tv ? 'aggregate_credits' : section.path}',
    ttl: section == KnowledgeSection.providers
        ? const Duration(hours: 6)
        : _detailTtl,
    query: {
      if (section == KnowledgeSection.reviews) 'page': '$page',
      if (section == KnowledgeSection.images)
        'include_image_language': 'en,null',
    },
    refresh: refresh,
  );

  Future<Json> episodeImages(
    EpisodeRef ref, {
    bool refresh = false,
  }) => _knowledge(
    '/tv/${ref.seriesId}/season/${ref.seasonNumber}/episode/${ref.episodeNumber}/images',
    query: const {'include_image_language': 'en,null'},
    refresh: refresh,
  );

  Future<Json> watchRegions({bool refresh = false}) => _knowledge(
    '/watch/providers/regions',
    ttl: const Duration(days: 7),
    refresh: refresh,
  );

  Future<Json> _knowledge(
    String path, {
    Map<String, String> query = const {},
    Duration ttl = _detailTtl,
    required bool refresh,
  }) => transport.get(
    path,
    operation: PerfArea.entity,
    query: query,
    ttl: ttl,
    refresh: refresh,
  );

  PageLoader associated(MediaKind kind, {EntityRef? entity, GenreRef? genre}) {
    final filter = switch (entity?.kind) {
      EntityKind.company => 'with_companies',
      EntityKind.network => 'with_networks',
      EntityKind.keyword => 'with_keywords',
      _ => 'with_genres',
    };
    final id = entity?.id ?? genre!.id;
    return (page, {required refresh}) => _page(
      '/discover/${kind.name}',
      PerfArea.entity,
      page,
      kind: kind,
      query: {
        filter: '$id',
        'include_adult': 'false',
        'sort_by': 'popularity.desc',
      },
      refresh: refresh,
    );
  }

  Future<List<Media>> related(
    EntityRef ref, {
    bool recommended = false,
    bool refresh = false,
  }) async {
    final kind = MediaKind.parse(ref.kind.name);
    if (kind == null) throw const TmdbException(TmdbErrorKind.rejected);
    final operation = recommended ? PerfArea.recommendations : PerfArea.similar;
    final result = await _page(
      '/${kind.name}/${ref.id}/${operation.name}',
      operation,
      1,
      kind: null,
      defaultKind: kind,
      ttl: _detailTtl,
      refresh: refresh,
    );
    return result.items;
  }

  Future<List<Media>> upcomingFor({int? person, int? genre}) async {
    if (person == null && genre == null) return const [];
    final today = _now();
    final page = await _page(
      '/discover/movie',
      PerfArea.releaseFeed,
      1,
      kind: MediaKind.movie,
      query: {
        'include_adult': 'false',
        'sort_by': 'primary_release_date.asc',
        'primary_release_date.gte': _date(today),
        'primary_release_date.lte': _date(today.add(const Duration(days: 120))),
        if (person != null) 'with_people': '$person',
        if (genre != null) 'with_genres': '$genre',
      },
      refresh: false,
    );
    return page.items;
  }

  Future<TmdbPage> _page(
    String path,
    PerfArea operation,
    int page, {
    required MediaKind? kind,
    MediaKind? defaultKind,
    Map<String, String> query = const {},
    Duration ttl = const Duration(minutes: 15),
    required bool refresh,
  }) async {
    final data = await transport.get(
      path,
      operation: operation,
      query: {'page': '$page', ...query},
      ttl: ttl,
      refresh: refresh,
    );
    final items = <Media>[];
    for (final json in _array(data['results'])) {
      final itemKind =
          kind ??
          MediaKind.parse(
            json['media_type'] is String ? json['media_type'] as String : null,
          ) ??
          (json['media_type'] == null ? defaultKind : null);
      if (itemKind == null) continue;
      final media = Media.fromJson(json, forcedType: itemKind.name);
      if (media.id > 0) items.add(media);
    }
    return TmdbPage(
      items: List.unmodifiable(items),
      page: _int(data['page']) ?? page,
      totalPages: _int(data['total_pages']) ?? page,
      totalResults: _int(data['total_results']) ?? items.length,
    );
  }
}

Iterable<Map<String, dynamic>> _array(Object? value) {
  if (value is! List) throw const TmdbException(TmdbErrorKind.invalidResponse);
  return value.whereType<Map<String, dynamic>>();
}

int? _int(Object? value) => value is int ? value : null;

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
