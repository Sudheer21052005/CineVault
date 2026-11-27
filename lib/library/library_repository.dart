import '../models/media.dart';
import '../models/watchlist_item.dart';

typedef LibraryEdit = ({
  WatchStatus status,
  double? rating,
  String notes,
  String review,
  DateTime? watchedDate,
});

typedef LibrarySnapshot = ({
  List<WatchlistItem> items,
  Set<String> achievements,
});

abstract interface class LibraryStore {
  Future<LibrarySnapshot> open();
  Future<void> put(WatchlistItem item);
  Future<void> delete(String key);
  Future<void> unlock(String id);
}

class LibraryRepository {
  LibraryRepository(this._store);

  final LibraryStore _store;
  final _items = <String, WatchlistItem>{};
  final _achievements = <String>{};
  Future<void> _queued = Future.value();
  bool ready = false;
  bool achievementsNeedRetry = false;

  List<WatchlistItem> get items => List.unmodifiable(_items.values);
  Set<String> get achievements => Set.unmodifiable(_achievements);
  WatchlistItem? find(int id, String type) => _items['$type-$id'];

  // A failed mutation must complete for its caller without breaking the queue.
  Future<void> _serialize(Future<void> Function() operation) {
    final next = _queued.then((_) => operation());
    _queued = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> initialize() => _serialize(() async {
    if (!ready) {
      final snapshot = await _store.open();
      _items
        ..clear()
        ..addEntries(snapshot.items.map((item) => MapEntry(item.key, item)));
      _achievements
        ..clear()
        ..addAll(snapshot.achievements);
      ready = true;
    }
    await _reconcileAchievements();
  });

  Future<void> save(Media media) => _serialize(() async {
    _requireReady();
    if (!_items.containsKey(media.key)) {
      final item = WatchlistItem(
        id: media.id,
        type: media.type,
        title: media.title,
        posterPath: media.posterPath,
        rating: media.rating,
        genres: media.genres,
      );
      await _store.put(item);
      _items[item.key] = item;
    }
    await _reconcileAchievements();
  });

  Future<void> update(WatchlistItem original, LibraryEdit edit) => _serialize(
    () async {
      _requireReady();
      final current = _items[original.key];
      if (current == null || current.addedAt != original.addedAt) {
        throw const LibraryEditConflict();
      }
      // Merge changed fields from the edit with the latest persisted snapshot.
      // Nullable fields are compared by value so an explicit clear is retained.
      final next = WatchlistItem(
        id: current.id,
        type: current.type,
        title: current.title,
        posterPath: current.posterPath,
        rating: current.rating,
        genres: current.genres,
        addedAt: current.addedAt,
        status: edit.status == original.status ? current.status : edit.status,
        userRating: edit.rating == original.userRating
            ? current.userRating
            : edit.rating,
        notes: edit.notes == original.notes ? current.notes : edit.notes,
        review: edit.review == original.review ? current.review : edit.review,
        dateWatched: edit.watchedDate == original.dateWatched
            ? current.dateWatched
            : edit.watchedDate,
      );
      await _store.put(next);
      _items[next.key] = next;
      await _reconcileAchievements();
    },
  );

  Future<void> remove(WatchlistItem item) => _serialize(() async {
    _requireReady();
    if (_items[item.key]?.addedAt != item.addedAt) return;
    await _store.delete(item.key);
    _items.remove(item.key);
    await _reconcileAchievements();
  });

  void _requireReady() {
    if (!ready) throw StateError('The watchlist is not available.');
  }

  Future<void> _reconcileAchievements() async {
    final watched = _items.values
        .where((item) => item.status == WatchStatus.watched)
        .toList();
    final rules = {
      'first-watch': watched.isNotEmpty,
      'ten-watched': watched.length >= 10,
      'genre-explorer':
          watched.expand((item) => item.genres).toSet().length >= 5,
      'movie-marathon':
          watched
              .where((item) => item.type == 'movie' && item.dateWatched != null)
              .length >=
          3,
      'tv-completion': watched.any((item) => item.type == 'tv'),
    };
    achievementsNeedRetry = false;
    for (final entry in rules.entries) {
      if (!entry.value || _achievements.contains(entry.key)) continue;
      try {
        await _store.unlock(entry.key);
        _achievements.add(entry.key);
      } catch (_) {
        // The title write has already committed. Repair the derived index on
        // explicit retry, the next mutation, or the next startup.
        achievementsNeedRetry = true;
      }
    }
  }
}

class LibraryEditConflict implements Exception {
  const LibraryEditConflict();
}
