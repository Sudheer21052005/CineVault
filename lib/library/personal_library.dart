import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../app/route_contract.dart';
import '../catalogue/knowledge_models.dart';
import 'personal_models.dart';

abstract interface class PersonalStore {
  Future<String?> read();
  Future<void> write(String snapshot);
}

class HivePersonalStore implements PersonalStore {
  HivePersonalStore({required this.initialize, HiveInterface? hive})
    : _hive = hive ?? Hive;
  final HiveInterface _hive;
  final Future<void> Function() initialize;
  Future<Box<String>>? _opening;

  Future<Box<String>> _open() async {
    await initialize();
    return _hive.openBox<String>('cinevault_personal_v1');
  }

  Future<Box<String>> get _box async {
    try {
      return await (_opening ??= _open());
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  @override
  Future<String?> read() async => (await _box).get('snapshot');

  @override
  Future<void> write(String snapshot) =>
      _box.then((box) => box.put('snapshot', snapshot));
}

class PersonalLibrary extends ChangeNotifier {
  PersonalLibrary(this.store, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  final PersonalStore store;
  final DateTime Function() now;
  final _random = Random.secure();
  PersonalState state = PersonalState();
  bool ready = false;
  bool failed = false;
  bool _disposed = false;
  Future<void>? _opening;
  Future<void> _tail = Future.value();

  Future<void> initialize() => ready ? Future.value() : _opening ??= _open();

  Future<void> _open() async {
    try {
      final raw = await store.read();
      if (raw != null) {
        final record = object(jsonDecode(raw));
        final payload = object(record?['personal']);
        if (record?['version'] != 1 || payload == null) {
          throw const FormatException('Unsupported personal storage.');
        }
        state = PersonalState.fromJson(payload);
      }
      ready = true;
      failed = false;
    } catch (_) {
      failed = true;
    } finally {
      _opening = null;
      if (!_disposed) notifyListeners();
    }
  }

  String newId() =>
      '${now().microsecondsSinceEpoch}-'
      '${_random.nextInt(1 << 30).toRadixString(16)}${_random.nextInt(1 << 30).toRadixString(16)}';

  Future<void> _commit(PersonalState Function(PersonalState) update) {
    final next = _tail.then((_) async {
      await initialize();
      if (!ready) throw StateError('Personal library is unavailable.');
      final updated = update(state);
      if (identical(state, updated)) return;
      await store.write(
        jsonEncode({'version': 1, 'personal': updated.toJson()}),
      );
      state = updated;
      if (!_disposed) notifyListeners();
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> favorite(PersonalTitle title) => _commit((current) {
    final items = {...current.favorites};
    if (items.remove(title.key) == null) items[title.key] = title;
    return current.copy(favorites: items);
  });

  Future<void> hide(PersonalTitle title, {bool hidden = true}) =>
      _commit((current) {
        final items = {...current.hidden};
        if (hidden) {
          items[title.key] = title;
        } else {
          items.remove(title.key);
        }
        return current.copy(hidden: items);
      });

  Future<void> recordVisit(PersonalTitle title) => _commit((current) {
    final existing = current.history[title.key];
    final time = now();
    if (existing != null &&
        time.difference(existing.time) < const Duration(minutes: 10) &&
        existing.title.name == title.name) {
      return current;
    }
    return current.copy(
      history: PersonalState.trimHistory({
        ...current.history,
        title.key: (
          title: existing?.title.enrichedWith(title) ?? title,
          time: time,
        ),
      }),
    );
  });

  Future<void> clearHistory() =>
      _commit((current) => current.copy(history: {}));

  Future<void> saveViewing(Viewing event) => _commit(
    (current) => current.copy(diary: {...current.diary, event.id: event}),
  );

  Future<void> enrichViewing(String id, List<EntityLink> credits) =>
      _commit((current) {
        final event = current.diary[id];
        if (event == null || credits.isEmpty) return current;
        final title = event.title.enrichedWith(
          PersonalTitle(event.title.route, event.title.name, people: credits),
        );
        return current.copy(
          diary: {
            ...current.diary,
            id: Viewing(
              id,
              title,
              event.day,
              rating: event.rating,
              review: event.review,
              notes: event.notes,
            ),
          },
        );
      });

  Future<void> removeViewing(String id) =>
      _commit((current) => current.copy(diary: {...current.diary}..remove(id)));

  Future<void> saveList(
    String id,
    String name,
    String description, {
    PersonalTitle? initial,
  }) => _commit(
    (current) => current.copy(
      lists: {
        ...current.lists,
        id: PersonalCollection(
          id,
          name,
          description,
          current.lists[id]?.titles ??
              (initial == null ? const [] : List.unmodifiable([initial])),
        ),
      },
    ),
  );

  Future<void> removeList(String id) =>
      _commit((current) => current.copy(lists: {...current.lists}..remove(id)));

  Future<void> toggleListMember(
    String id,
    PersonalTitle title, {
    bool? included,
  }) => _commit((current) {
    final list = current.lists[id];
    if (list == null) return current;
    final titles = {for (final entry in list.titles) entry.key: entry};
    if (included ?? !titles.containsKey(title.key)) {
      titles[title.key] = title;
    } else {
      titles.remove(title.key);
    }
    return current.copy(
      lists: {
        ...current.lists,
        id: PersonalCollection(
          id,
          list.name,
          list.description,
          List.unmodifiable(titles.values),
        ),
      },
    );
  });

  Future<void> saveSeason(SeriesSeason season) => _commit(
    (current) =>
        current.copy(seasons: {...current.seasons, season.key: season}),
  );

  Future<void> mark(PersonalTitle episode, {required bool watched}) =>
      _commit((current) {
        if (episode.route is! EpisodeRoute) {
          throw ArgumentError('Expected an episode.');
        }
        final marked = {...current.marked};
        if (watched) {
          marked.putIfAbsent(episode.key, () => (episode: episode, day: now()));
        } else {
          marked.remove(episode.key);
        }
        return current.copy(marked: marked);
      });

  Future<void> merge(PersonalState incoming) => _commit((current) {
    final history = {...current.history};
    for (final entry in incoming.history.entries) {
      final existing = history[entry.key];
      if (existing == null || entry.value.time.isAfter(existing.time)) {
        history[entry.key] = entry.value;
      }
    }
    return PersonalState(
      diary: {...incoming.diary, ...current.diary},
      lists: {...incoming.lists, ...current.lists},
      favorites: {...incoming.favorites, ...current.favorites},
      hidden: {...incoming.hidden, ...current.hidden},
      marked: {...incoming.marked, ...current.marked},
      seasons: {...incoming.seasons, ...current.seasons},
      history: PersonalState.trimHistory(history),
    );
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
