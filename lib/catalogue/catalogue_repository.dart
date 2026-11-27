import '../core/network/tmdb_transport.dart';
import '../core/performance.dart';
import '../models/media.dart';
import 'entity_ref.dart';

enum SearchScope { all, movie, tv }

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
typedef PageLoader = Future<TmdbPage> Function(
  int page, {
  required bool refresh,
});

class TmdbPage {
  const TmdbPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalResults,
  });

  final List<Media> items;
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

  Future<Media> details(EntityRef ref, {bool refresh = false}) async {
    final kind = MediaKind.parse(ref.kind.name);
    if (kind == null) throw const TmdbException(TmdbErrorKind.rejected);
    final data = await transport.get(
      '/${kind.name}/${ref.id}',
      operation: PerfArea.titleDetails,
      ttl: _detailTtl,
      refresh: refresh,
    );
    final media = Media.fromJson(data, forcedType: kind.name);
    if (media.ref != ref) {
      throw const TmdbException(TmdbErrorKind.invalidResponse);
    }
    return media;
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
