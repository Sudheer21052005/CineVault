import 'dart:convert';

import 'package:hive/hive.dart';

abstract interface class CatalogueCache {
  Future<StoredResponse?> read(String key, DateTime now);
  Future<void> write(String key, StoredResponse response, DateTime now);
}

typedef StoredResponse = ({String json, int bytes, DateTime expires});

class HiveCatalogueCache implements CatalogueCache {
  HiveCatalogueCache({
    required this._initialize,
    required this.maxBytes,
    this.maxEntries = 350,
    this.boxName = 'cinevault_catalogue_v1',
  });

  final Future<void> Function() _initialize;
  final int maxBytes;
  final int maxEntries;
  final String boxName;
  Future<Box<dynamic>>? _opening;
  Future<void> _writes = Future.value();
  final _index = <String, StoredResponse>{};
  int _size = 0;

  Future<Box<dynamic>> _box() => _opening ??= _open();

  Future<Box<dynamic>> _open() async {
    await _initialize();
    final box = await Hive.openBox<dynamic>(
      boxName,
      compactionStrategy: (entries, removed) =>
          removed >= 100 && removed * 4 >= entries,
    );
    final oldKeys = <dynamic>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (key is! String ||
          raw is! List ||
          raw.length != 3 ||
          raw[0] is! String ||
          raw[1] is! int ||
          raw[2] is! int) {
        oldKeys.add(key);
        continue;
      }
      final response = (
        json: raw[0] as String,
        bytes: raw[1] as int,
        expires: DateTime.fromMillisecondsSinceEpoch(raw[2] as int),
      );
      if (response.bytes <= 0 || response.bytes > maxBytes) {
        oldKeys.add(key);
        continue;
      }
      _index[key] = response;
      _size += response.bytes;
    }
    oldKeys.addAll(_evict(DateTime.now()));
    if (oldKeys.isNotEmpty) await box.deleteAll(oldKeys);
    return box;
  }

  @override
  Future<StoredResponse?> read(String key, DateTime now) async {
    await _box();
    final entry = _index[key];
    return entry != null && now.isBefore(entry.expires) ? entry : null;
  }

  @override
  Future<void> write(String key, StoredResponse response, DateTime now) {
    if (response.bytes <= 0 || response.bytes > maxBytes) return Future.value();
    final next = _writes.then((_) async {
      final box = await _box();
      await box.put(key, [
        response.json,
        response.bytes,
        response.expires.millisecondsSinceEpoch,
      ]);
      _size -= _index.remove(key)?.bytes ?? 0;
      _index[key] = response;
      _size += response.bytes;
      final evicted = _evict(now);
      if (evicted.isNotEmpty) await box.deleteAll(evicted);
    });
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  List<String> _evict(DateTime now) {
    final removed = _index.entries
        .where((entry) => !now.isBefore(entry.value.expires))
        .map((entry) => entry.key)
        .toList();
    for (final key in removed) {
      _size -= _index.remove(key)!.bytes;
    }
    while (_index.length > maxEntries || _size > maxBytes) {
      final key = _index.keys.first;
      _size -= _index.remove(key)!.bytes;
      removed.add(key);
    }
    return removed;
  }
}

Map<String, dynamic>? decodeStoredResponse(StoredResponse response) {
  try {
    final decoded = jsonDecode(response.json);
    return decoded is Map<String, dynamic> ? Map.unmodifiable(decoded) : null;
  } on FormatException {
    return null;
  }
}
