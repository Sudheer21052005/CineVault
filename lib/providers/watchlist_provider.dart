import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/media.dart';
import '../models/watchlist_item.dart';

class WatchlistProvider extends ChangeNotifier {
  static const boxName = 'cinevault_watchlist';
  static const achievementsBoxName = 'cinevault_achievements';
  Box<WatchlistItem>? _box;
  Box<String>? _achievementsBox;
  List<WatchlistItem> _items = [];
  bool initialized = false;
  List<WatchlistItem> get items => List.unmodifiable(_items);
  List<String> get unlockedAchievements => _achievementsBox?.values.toList() ?? [];

  Future<void> initialize() async {
    if (_box != null) return;
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WatchlistItemAdapter());
    _box = await Hive.openBox<WatchlistItem>(boxName);
    _achievementsBox = await Hive.openBox<String>(achievementsBoxName);
    if (_box!.isEmpty) {
      final now = DateTime.now();
      final sampleItems = [
        WatchlistItem(
          id: 27205,
          type: 'movie',
          title: 'Inception',
          posterPath: '/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg',
          rating: 8.4,
          status: WatchStatus.watched,
          userRating: 5.0,
          notes: 'Masterpiece direction by Christopher Nolan.',
          review: 'Mind-bending dream architecture and Hans Zimmer score. Incredible experience from start to finish.',
          genres: const ['Action', 'Sci-Fi', 'Adventure'],
          dateWatched: now.subtract(const Duration(days: 2)),
          addedAt: now.subtract(const Duration(days: 10)),
        ),
        WatchlistItem(
          id: 1396,
          type: 'tv',
          title: 'Breaking Bad',
          posterPath: '/ztkUQFLlC19CCMYHW9o1zWhJRNq.jpg',
          rating: 8.9,
          status: WatchStatus.watched,
          userRating: 5.0,
          notes: 'Finished all 5 seasons.',
          review: 'The ultimate character transformation of Walter White. Best television writing in modern history.',
          genres: const ['Drama', 'Crime'],
          dateWatched: now.subtract(const Duration(days: 1)),
          addedAt: now.subtract(const Duration(days: 14)),
        ),
        WatchlistItem(
          id: 693134,
          type: 'movie',
          title: 'Dune: Part Two',
          posterPath: '/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg',
          rating: 8.3,
          status: WatchStatus.watching,
          userRating: 4.5,
          notes: 'Watching in IMAX theater this weekend.',
          review: 'Denis Villeneuve delivers pure cinematic grandeur.',
          genres: const ['Sci-Fi', 'Adventure'],
          addedAt: now.subtract(const Duration(days: 3)),
        ),
        WatchlistItem(
          id: 157336,
          type: 'movie',
          title: 'Interstellar',
          posterPath: '/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
          rating: 8.4,
          status: WatchStatus.watched,
          userRating: 5.0,
          notes: 'Watched with friends.',
          review: 'Visually stunning and deeply emotional. The docking sequence alone makes it a classic.',
          genres: const ['Sci-Fi', 'Drama'],
          dateWatched: now.subtract(const Duration(days: 4)),
          addedAt: now.subtract(const Duration(days: 12)),
        ),
        WatchlistItem(
          id: 872585,
          type: 'movie',
          title: 'Oppenheimer',
          posterPath: '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
          rating: 8.1,
          status: WatchStatus.watched,
          userRating: 4.5,
          notes: 'Phenomenal audio mixing and editing.',
          review: 'Cillian Murphy gives a career-defining performance as J. Robert Oppenheimer.',
          genres: const ['Drama', 'History'],
          dateWatched: now.subtract(const Duration(days: 5)),
          addedAt: now.subtract(const Duration(days: 15)),
        ),
        WatchlistItem(
          id: 126308,
          type: 'tv',
          title: 'Shōgun',
          posterPath: '/7O4iVfOMQmdCSxhOg1WNzG1AgYT.jpg',
          rating: 8.5,
          status: WatchStatus.watching,
          userRating: 4.5,
          notes: 'Currently on Episode 7. Superb historical accuracy.',
          review: '',
          genres: const ['Drama', 'Action', 'History'],
          addedAt: now.subtract(const Duration(days: 5)),
        ),
        WatchlistItem(
          id: 66732,
          type: 'tv',
          title: 'Stranger Things',
          posterPath: '/49WJfeN0moxb9IPfGn8AIqMGskD.jpg',
          rating: 8.6,
          status: WatchStatus.planToWatch,
          userRating: 4.0,
          notes: 'Need to catch up before the new season releases.',
          review: '',
          genres: const ['Sci-Fi', 'Horror', 'Drama'],
          addedAt: now.subtract(const Duration(days: 7)),
        ),
        WatchlistItem(
          id: 155,
          type: 'movie',
          title: 'The Dark Knight',
          posterPath: '/qJ2tW6WMUDux911r6m7haRef0WH.jpg',
          rating: 8.5,
          status: WatchStatus.watched,
          userRating: 5.0,
          notes: 'Rewatched for the 10th time.',
          review: 'Heath Ledger as the Joker remains unmatched in modern superhero cinema.',
          genres: const ['Action', 'Crime', 'Drama'],
          dateWatched: now.subtract(const Duration(days: 6)),
          addedAt: now.subtract(const Duration(days: 20)),
        ),
      ];
      for (final item in sampleItems) {
        await _box!.put(item.key, item);
      }
      await _refreshAchievements();
    }
    _items = _box!.values.toList();
    initialized = true;
    notifyListeners();
  }

  WatchlistItem? find(int id, String type) {
    for (final item in _items) {
      if (item.id == id && item.type == type) return item;
    }
    return null;
  }

  Future<void> save(Media media, {WatchStatus? status, double? userRating, String? notes}) async {
    final item = find(media.id, media.type) ??
        WatchlistItem(id: media.id, type: media.type, title: media.title, posterPath: media.posterPath, rating: media.rating, genres: media.genres);
    if (status != null) item.status = status;
    if (userRating != null) item.userRating = userRating;
    if (notes != null) item.notes = notes;
    if (status == WatchStatus.watched && item.dateWatched == null) item.dateWatched = DateTime.now();
    await _box!.put(item.key, item);
    _items = _box!.values.toList();
    await _refreshAchievements();
    notifyListeners();
  }

  Future<void> update(
    WatchlistItem item, {
    WatchStatus? status,
    double? userRating,
    String? notes,
    String? review,
    DateTime? dateWatched,
  }) async {
    if (status != null) item.status = status;
    if (userRating != null) item.userRating = userRating;
    if (notes != null) item.notes = notes;
    if (review != null) item.review = review;
    if (dateWatched != null) item.dateWatched = dateWatched;
    if (status == WatchStatus.watched && item.dateWatched == null) item.dateWatched = DateTime.now();
    await _box!.put(item.key, item);
    _items = _box!.values.toList();
    await _refreshAchievements();
    notifyListeners();
  }

  Future<void> remove(WatchlistItem item) async {
    await _box?.delete(item.key);
    _items = _box?.values.toList() ?? [];
    notifyListeners();
  }

  Map<WatchStatus, int> get statusCounts => {
        for (final status in WatchStatus.values) status: _items.where((item) => item.status == status).length,
      };
  int countType(String type) => _items.where((item) => item.type == type).length;

  Map<DateTime, int> get activityByDay {
    final counts = <DateTime, int>{};
    for (final item in _items.where((item) => item.dateWatched != null)) {
      final date = DateTime(item.dateWatched!.year, item.dateWatched!.month, item.dateWatched!.day);
      counts[date] = (counts[date] ?? 0) + 1;
    }
    return counts;
  }

  Set<String> get watchedGenres => _items
      .where((item) => item.status == WatchStatus.watched)
      .expand((item) => item.genres)
      .toSet();

  Future<void> _refreshAchievements() async {
    final watchedItems = _items.where((item) => item.status == WatchStatus.watched).toList();
    final rules = <String, bool>{
      'first-watch': watchedItems.isNotEmpty,
      'ten-watched': watchedItems.length >= 10,
      'genre-explorer': watchedItems.expand((item) => item.genres).toSet().length >= 5,
      'movie-marathon': watchedItems.where((item) => item.dateWatched != null).length >= 3,
      'tv-completion': watchedItems.any((item) => item.type == 'tv'),
    };
    for (final entry in rules.entries) {
      if (entry.value && !(_achievementsBox?.values.contains(entry.key) ?? false)) {
        await _achievementsBox?.add(entry.key);
      }
    }
  }
}
