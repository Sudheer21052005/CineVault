import 'package:flutter/foundation.dart';

import '../core/performance.dart';
import '../library/library_repository.dart';
import '../models/media.dart';
import '../models/watchlist_item.dart';

class WatchlistProvider extends ChangeNotifier {
  WatchlistProvider(this._library, this._performance);

  final LibraryRepository _library;
  final AppPerformance _performance;
  Future<void>? _initializing;
  bool _disposed = false;
  bool openFailed = false;
  bool get initialized => _library.ready;
  bool get achievementsNeedRetry => _library.achievementsNeedRetry;
  List<WatchlistItem> get items => _items;
  List<WatchlistItem> _items = const [];
  Set<String> get unlockedAchievements => _library.achievements;

  Future<void> initialize() => _initializing ??= _load();

  Future<void> _load() async {
    final watch = Stopwatch()..start();
    openFailed = false;
    _notify();
    try {
      await _library.initialize();
    } catch (_) {
      openFailed = true;
    } finally {
      _initializing = null;
      _performance.record(
        PerfSample(
          PerfEvent.libraryOpen,
          watch.elapsed,
          outcome: openFailed ? PerfOutcome.failure : PerfOutcome.success,
        ),
      );
      _notify();
    }
  }

  WatchlistItem? find(int id, String type) => _library.find(id, type);

  Future<void> save(Media media) => _mutate(() => _library.save(media));

  Future<void> update(WatchlistItem item, LibraryEdit edit) =>
      _mutate(() => _library.update(item, edit));

  Future<void> remove(WatchlistItem item) =>
      _mutate(() => _library.remove(item));

  Future<void> _mutate(Future<void> Function() operation) async {
    await operation();
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    _items = _library.items;
    notifyListeners();
  }

  Map<WatchStatus, int> get statusCounts => {
    for (final status in WatchStatus.values)
      status: items.where((item) => item.status == status).length,
  };

  int countType(String type) => items.where((item) => item.type == type).length;

  Map<DateTime, int> get activityByDay {
    final counts = <DateTime, int>{};
    for (final item in items) {
      final date = item.dateWatched;
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
