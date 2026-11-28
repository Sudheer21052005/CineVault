import 'dart:async';

import 'package:cinevault/library/library_repository.dart';
import 'package:cinevault/models/watchlist_item.dart';

class MemoryLibraryStore implements LibraryStore {
  final titles = <String, WatchlistItem>{};
  final unlocked = <String>{};
  int puts = 0;
  bool failOpen = false;
  bool failPut = false;
  bool failDelete = false;
  bool failUnlock = false;
  Completer<void>? blockPut;

  @override
  Future<LibrarySnapshot> open() async {
    if (failOpen) throw StateError('Open failed');
    return (items: titles.values.toList(), achievements: {...unlocked});
  }

  @override
  Future<void> put(WatchlistItem item) async {
    puts++;
    await blockPut?.future;
    if (failPut) throw StateError('Write failed');
    titles[item.key] = item;
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('Delete failed');
    titles.remove(key);
  }

  @override
  Future<void> unlock(String id) async {
    if (failUnlock) throw StateError('Achievement write failed');
    unlocked.add(id);
  }
}
