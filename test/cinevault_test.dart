import 'package:flutter_test/flutter_test.dart';
import 'package:cinevault/models/media.dart';
import 'package:cinevault/models/watchlist_item.dart';
import 'package:cinevault/services/tmdb_service.dart';

void main() {
  test('TMDB media parsing preserves movie identity and optional fields', () {
    final media = Media.fromJson({
      'id': 42,
      'title': 'CineVault Test',
      'release_date': '2026-01-01',
      'vote_average': 8.5,
      'media_type': 'movie',
      'runtime': 120,
    });
    expect(media.key, 'movie-42');
    expect(media.title, 'CineVault Test');
    expect(media.rating, 8.5);
    expect(media.runtime, 120);
  });

  test('TV parsing preserves TV-specific metadata', () {
    final show = Media.fromJson({
      'id': 7,
      'name': 'Test Show',
      'first_air_date': '2025-02-03',
      'number_of_seasons': 3,
      'number_of_episodes': 24,
      'episode_run_time': [45],
      'media_type': 'tv',
    });
    expect(show.key, 'tv-7');
    expect(show.seasons, 3);
    expect(show.episodes, 24);
    expect(show.episodeRuntime, 45);
  });

  test('watchlist identity prevents movie and TV ID collisions', () {
    final movie = WatchlistItem(id: 10, type: 'movie', title: 'Movie');
    final show = WatchlistItem(id: 10, type: 'tv', title: 'Show');
    expect(movie.key, 'movie-10');
    expect(show.key, 'tv-10');
    expect(movie.key, isNot(show.key));
  });

  test('watch status parsing safely defaults unknown values', () {
    expect(watchStatusFromString('watched'), WatchStatus.watched);
    expect(watchStatusFromString('unknown'), WatchStatus.planToWatch);
  });

  test('diary fields retain watched date, review, and genres', () {
    final watchedAt = DateTime(2026, 11, 4);
    final item = WatchlistItem(
      id: 8,
      type: 'movie',
      title: 'Diary title',
      status: WatchStatus.watched,
      dateWatched: watchedAt,
      review: 'A thoughtful film.',
      genres: const ['Drama', 'History'],
    );
    expect(item.dateWatched, watchedAt);
    expect(item.review, 'A thoughtful film.');
    expect(item.genres, contains('Drama'));
  });

  test('TMDB pagination stops at the reported page limit', () {
    const page = TmdbPage(items: [], page: 3, totalPages: 3, totalResults: 60);
    expect(page.hasMore, isFalse);
  });
}
