import 'package:hive_flutter/hive_flutter.dart';

import '../models/watchlist_item.dart';
import 'library_repository.dart';

class HiveLibraryStore implements LibraryStore {
  HiveLibraryStore({
    HiveInterface? hive,
    Future<void> Function()? initializeHive,
  }) : _hive = hive ?? Hive,
       _initializeHive = initializeHive ?? Hive.initFlutter;

  static const watchlistBox = 'cinevault_watchlist';
  static const achievementsBox = 'cinevault_achievements';
  final HiveInterface _hive;
  final Future<void> Function() _initializeHive;
  late Box<WatchlistItem> _items;
  late Box<String> _achievements;

  @override
  Future<LibrarySnapshot> open() async {
    await _initializeHive();
    if (!_hive.isAdapterRegistered(1)) {
      _hive.registerAdapter(WatchlistItemAdapter());
    }
    _items = await _hive.openBox<WatchlistItem>(watchlistBox);
    _achievements = await _hive.openBox<String>(achievementsBox);
    return (
      items: _items.values.toList(),
      achievements: _achievements.values.toSet(),
    );
  }

  @override
  Future<void> put(WatchlistItem item) => _items.put(item.key, item);

  @override
  Future<void> delete(String key) => _items.delete(key);

  @override
  Future<void> unlock(String id) => _achievements.put(id, id);
}
