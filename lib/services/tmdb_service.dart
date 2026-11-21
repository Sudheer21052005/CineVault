import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/media.dart';

class TmdbException implements Exception {
  const TmdbException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TmdbPage {
  const TmdbPage({required this.items, required this.page, required this.totalPages, required this.totalResults});
  final List<Media> items;
  final int page;
  final int totalPages;
  final int totalResults;
  bool get hasMore => page < totalPages && page < 500;
}

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime expiry;
  const _CacheEntry({required this.data, required this.expiry});
  bool get isExpired => DateTime.now().isAfter(expiry);
}

class TmdbService {
  static final http.Client _defaultClient = http.Client();
  static final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};
  static final Map<String, Future<Map<String, dynamic>>> _inFlight =
      <String, Future<Map<String, dynamic>>>{};

  static void clearCache() => _cache.clear();

  TmdbService({http.Client? client}) : _client = client ?? _defaultClient;
  final http.Client _client;
  static const _base = 'https://api.themoviedb.org/3';
  static const imageBase = 'https://image.tmdb.org/t/p/w500';
  static const backdropBase = 'https://image.tmdb.org/t/p/w1280';

  String get _apiKey => dotenv.env['TMDB_API_KEY']?.trim() ?? '';

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    if (_apiKey.isEmpty || _apiKey == 'YOUR_TMDB_API_KEY') {
      throw const TmdbException('Add your TMDB API key to the local .env file.');
    }
    final params = <String, String>{'api_key': _apiKey, 'language': 'en-US', ...?query};
    final uri = Uri.parse('$_base$path').replace(queryParameters: params);
    final cacheKey = uri.toString();

    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    if (_inFlight.containsKey(cacheKey)) {
      return _inFlight[cacheKey]!;
    }

    final future = _fetchWithRetry(uri, cacheKey);
    _inFlight[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Future<Map<String, dynamic>> _fetchWithRetry(Uri uri, String cacheKey) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final response =
            await _client.get(uri).timeout(const Duration(seconds: 15));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is! Map<String, dynamic>) {
            throw const TmdbException('TMDB returned invalid data.');
          }
          _cache[cacheKey] = _CacheEntry(
            data: data,
            expiry: DateTime.now().add(const Duration(minutes: 5)),
          );
          return data;
        } else if (response.statusCode == 429 || response.statusCode >= 500) {
          if (attempts >= 3) {
            throw TmdbException('TMDB service busy (${response.statusCode}). Please retry.');
          }
          await Future<void>.delayed(Duration(milliseconds: 300 * attempts));
          continue;
        } else {
          throw TmdbException('TMDB request failed (${response.statusCode}).');
        }
      } on TimeoutException {
        if (attempts >= 3) {
          throw const TmdbException('TMDB request timed out. Check your connection and retry.');
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * attempts));
      } on http.ClientException {
        if (attempts >= 3) {
          throw const TmdbException('Unable to connect to TMDB. Check your connection and retry.');
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * attempts));
      } catch (e) {
        if (e is TmdbException) rethrow;
        if (attempts >= 3) {
          throw const TmdbException('Unable to connect to TMDB. Check your connection and retry.');
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * attempts));
      }
    }
  }

  Future<List<Media>> list(String path, {String type = 'movie', int page = 1, Map<String, String>? query}) async {
    return (await pageResults(path, type: type, page: page, query: query)).items;
  }

  Future<TmdbPage> pageResults(String path, {String type = 'movie', int page = 1, Map<String, String>? query}) async {
    final data = await _get(path, {'page': '$page', ...?query});
    final items = (data['results'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((item) => Media.fromJson(item, forcedType: type))
        .where((item) => item.id > 0)
        .toList();
    return TmdbPage(
      items: items,
      page: (data['page'] as num?)?.toInt() ?? page,
      totalPages: (data['total_pages'] as num?)?.toInt() ?? (items.isEmpty ? page : page + 1),
      totalResults: (data['total_results'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<Media> details(Media media) async =>
      Media.fromJson(await _get('/${media.type}/${media.id}'), forcedType: media.type);
  Future<List<Media>> similar(Media media) => list('/${media.type}/${media.id}/similar', type: media.type);
  Future<List<Media>> recommendations(Media media) =>
      list('/${media.type}/${media.id}/recommendations', type: media.type);

  Future<List<Media>> search(String query, {int page = 1}) async {
    return (await searchPage(query, page: page)).items;
  }

  Future<TmdbPage> searchPage(String query, {int page = 1}) async {
    final data = await _get('/search/multi', {'query': query, 'page': '$page', 'include_adult': 'false'});
    final items = (data['results'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .where((item) => item['media_type'] == 'movie' || item['media_type'] == 'tv')
        .map(Media.fromJson)
        .where((item) => item.id > 0)
        .toList();
    return TmdbPage(
      items: items,
      page: (data['page'] as num?)?.toInt() ?? page,
      totalPages: (data['total_pages'] as num?)?.toInt() ?? (items.isEmpty ? page : page + 1),
      totalResults: (data['total_results'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<List<Media>> popularMovies() => list('/movie/popular');
  Future<List<Media>> upcomingMovies() => list('/movie/upcoming');
  Future<List<Media>> nowPlaying() => list('/movie/now_playing');
  Future<List<Media>> topRatedMovies() => list('/movie/top_rated');
  Future<List<Media>> trendingMovies() => list('/trending/movie/week');
  Future<List<Media>> popularShows() => list('/tv/popular', type: 'tv');
  Future<List<Media>> airingToday() => list('/tv/airing_today', type: 'tv');
  Future<List<Media>> onTheAirShows() => list('/tv/on_the_air', type: 'tv');
  Future<List<Media>> topRatedShows() => list('/tv/top_rated', type: 'tv');

  Future<List<Media>> recentMovies({int page = 1}) {
    return recentMoviesPage(page: page).then((result) => result.items);
  }

  Future<TmdbPage> recentMoviesPage({int page = 1}) {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 90));
    return discoverPage(
      page: page,
      sortBy: 'primary_release_date.desc',
      query: {
        'primary_release_date.gte': _date(start),
        'primary_release_date.lte': _date(today),
        'region': 'IN',
      },
    );
  }

  Future<List<Media>> upcomingMoviesWindow({int page = 1}) async {
    return (await upcomingMoviesPage(page: page)).items;
  }

  Future<TmdbPage> upcomingMoviesPage({int page = 1}) async {
    final today = DateTime.now();
    final end = today.add(const Duration(days: 180));
    final window = await discoverPage(
      page: page,
      sortBy: 'primary_release_date.asc',
      query: {
        'primary_release_date.gte': _date(today),
        'primary_release_date.lte': _date(end),
      },
    );
    if (window.items.isNotEmpty) return window;

    // TMDB's curated upcoming feed remains useful when the regional
    // discovery window has no sufficiently voted titles.
    return upcomingMoviesPageRaw(page: page);
  }

  Future<TmdbPage> upcomingMoviesPageRaw({int page = 1}) => pageResults('/movie/upcoming', page: page);

  Future<List<Media>> discover({
    String type = 'movie',
    int? genreId,
    int? year,
    double? minimumRating,
    String sortBy = 'popularity.desc',
    int page = 1,
    Map<String, String>? query,
  }) async {
    final filters = <String, String>{
      'page': '$page',
      'sort_by': type == 'tv' && sortBy.startsWith('primary_release') ? sortBy.replaceFirst('primary_release', 'first_air') : sortBy,
      'vote_count.gte': '20',
    };
    if (genreId != null) filters['with_genres'] = '$genreId';
    if (year != null) filters[type == 'tv' ? 'first_air_date_year' : 'primary_release_year'] = '$year';
    if (minimumRating != null) filters['vote_average.gte'] = '$minimumRating';
    filters.addAll(query ?? const {});
    return list('/discover/$type', type: type, page: page, query: filters);
  }

  Future<TmdbPage> discoverPage({
    String type = 'movie',
    int? genreId,
    int? year,
    double? minimumRating,
    String sortBy = 'popularity.desc',
    int page = 1,
    Map<String, String>? query,
  }) async {
    final filters = <String, String>{
      'sort_by': type == 'tv' && sortBy.startsWith('primary_release') ? sortBy.replaceFirst('primary_release', 'first_air') : sortBy,
      'vote_count.gte': '20',
    };
    if (genreId != null) filters['with_genres'] = '$genreId';
    if (year != null) filters[type == 'tv' ? 'first_air_date_year' : 'primary_release_year'] = '$year';
    if (minimumRating != null) filters['vote_average.gte'] = '$minimumRating';
    filters.addAll(query ?? const {});
    return pageResults('/discover/$type', type: type, page: page, query: filters);
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
