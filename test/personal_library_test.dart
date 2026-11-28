import 'dart:convert';
import 'dart:io';

import 'package:cinevault/app/route_contract.dart';
import 'package:cinevault/catalogue/catalogue_repository.dart';
import 'package:cinevault/catalogue/entity_ref.dart';
import 'package:cinevault/core/network/tmdb_transport.dart';
import 'package:cinevault/core/performance.dart';
import 'package:cinevault/library/hive_library_store.dart';
import 'package:cinevault/library/library_repository.dart';
import 'package:cinevault/library/personal_insights.dart';
import 'package:cinevault/library/personal_library.dart';
import 'package:cinevault/library/personal_models.dart';
import 'package:cinevault/models/watchlist_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const film = PersonalTitle(
  TitleRoute((kind: EntityKind.movie, id: 11)),
  'Film',
  minutes: 104,
  language: 'en',
  genres: ['Drama'],
  countries: ['United States'],
);
const series = PersonalTitle(
  TitleRoute((kind: EntityKind.tv, id: 22)),
  'Series',
);
const first = PersonalTitle(
  EpisodeRoute((seriesId: 22, seasonNumber: 1, episodeNumber: 1)),
  'First episode',
  minutes: 42,
);
final day = DateTime(2026, 5, 5);

class MemoryPersonalStore implements PersonalStore {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String snapshot) async {
    if (fail) throw StateError('Mock write failed');
    value = snapshot;
  }
}

void main() {
  test('repeat views, nullable fields, lists, marks and recent entities survive reopening', () async {
    final store = MemoryPersonalStore();
    final library = PersonalLibrary(store, now: () => day);
    final firstId = library.newId();
    final secondId = library.newId();
    await Future.wait([
      library.saveViewing(
        Viewing(firstId, film, day, rating: 4.5, review: 'Excellent'),
      ),
      library.saveViewing(
        Viewing(secondId, film, day, notes: 'Second screening'),
      ),
      library.favorite(film),
      library.mark(first, watched: true),
      library.recordVisit(film),
    ]);
    await library.saveList('list', 'One', 'Saved group');
    await library.toggleListMember('list', film);
    await library.saveViewing(Viewing(firstId, film, day, notes: 'Revised'));
    final restored = PersonalLibrary(store);
    await restored.initialize();
    expect(
      restored.state.diary.values.map((entry) => entry.title.key),
      everyElement(film.key),
    );
    expect(restored.state.diary, hasLength(2));
    expect(restored.state.diary[firstId]?.rating, isNull);
    expect(restored.state.diary[firstId]?.review, isEmpty);
    expect(restored.state.marked[first.key]?.day, day);
    expect(restored.state.lists['list']?.titles.single.key, film.key);
    expect(restored.state.history.values.single.title.key, film.key);
    expect(restored.state.favorites.containsKey(film.key), true);
    final stats = PersonalStats(restored.state, []);
    expect(stats.minutes, 250);
    expect(stats.repeats, 1);
    expect(stats.achievements, contains('Encore'));
    final planned = PersonalTitle(
      const EpisodeRoute((seriesId: 22, seasonNumber: 1, episodeNumber: 2)),
      'Second episode',
      date: day.subtract(const Duration(days: 1)),
    );
    await restored.saveSeason(SeriesSeason(series, 1, [first, planned]));
    expect(seasonProgress(restored.state, day).single.next?.key, planned.key);
  });

  test(
    'failed writes leave the last good snapshot and allow later mutations',
    () async {
      final store = MemoryPersonalStore();
      final library = PersonalLibrary(store);
      await library.favorite(film);
      store.fail = true;
      await expectLater(library.favorite(film), throwsStateError);
      expect(library.state.favorites.containsKey(film.key), true);
      store.fail = false;
      await library.favorite(film);
      expect(library.state.favorites, isEmpty);
    },
  );

  test('1,000-title offline Hive installation upgrades, edits, exports and restores without duplicates', () async {
    final scratch = await Directory.systemTemp.createTemp(
      'cinevault-personal-test',
    );
    final newInstall = await Directory.systemTemp.createTemp(
      'cinevault-restore-test',
    );
    addTearDown(() async {
      await Hive.close();
      await scratch.delete(recursive: true);
      await newInstall.delete(recursive: true);
    });
    Hive.init(scratch.path);
    final legacy = HiveLibraryStore(initializeHive: () async {});
    await legacy.open();
    final started = Stopwatch()..start();
    for (var id = 1; id <= 1000; id++) {
      await legacy.put(
        WatchlistItem(
          id: id,
          type: 'movie',
          title: 'Fixture $id',
          status: WatchStatus.watched,
          notes: id == 1 ? '=keep my notes' : '',
          review: 'Review',
          userRating: 4.5,
          rating: 8.1,
          dateWatched: day,
          addedAt: day,
          genres: ['Drama'],
        ),
      );
    }
    await legacy.unlock('preserved-legacy-id');
    started.reset();
    final oldRepo = LibraryRepository(legacy);
    final person = PersonalLibrary(HivePersonalStore(initialize: () async {}));
    await oldRepo.initialize();
    await person.initialize();
    final opened = started.elapsedMicroseconds;
    expect(oldRepo.items, hasLength(1000));
    expect(person.state.diary, isEmpty);
    final original = oldRepo.items.first;
    await oldRepo.update(original, (
      status: original.status,
      rating: original.userRating,
      notes: original.notes,
      review: 'Updated offline',
      watchedDate: original.dateWatched,
    ));
    final edited = started.elapsedMicroseconds - opened;
    await person.saveViewing(
      Viewing('added', film, day, review: '"Second, viewing"'),
    );
    await person.mark(first, watched: true);
    final compute = Stopwatch()..start();
    final seeds = PersonalDiscovery.sources(person.state, oldRepo.items);
    final stats = PersonalStats(person.state, oldRepo.items);
    final computed = compute.elapsedMicroseconds;
    expect(seeds, hasLength(3));
    expect(stats.years[day.year], 1001);
    final backup = LibraryBackup.fromJson(
      jsonDecode(
        jsonEncode(
          LibraryBackup(
            person.state,
            oldRepo.items,
            oldRepo.achievements,
          ).toJson(),
        ),
      ),
    );
    expect(backup.toCsv(), contains("'=keep my notes"));
    expect(backup.toCsv(), contains('""Second, viewing""'));
    await Hive.close();
    Hive.init(newInstall.path);
    final incoming = LibraryRepository(
      HiveLibraryStore(initializeHive: () async {}),
    );
    final restored = PersonalLibrary(
      HivePersonalStore(initialize: () async {}),
    );
    await incoming.initialize();
    final restore = Stopwatch()..start();
    for (var i = 0; i < 2; i++) {
      await incoming.mergeBackup((
        items: backup.watchlist,
        achievements: backup.achievements,
      ));
      await restored.merge(backup.personal);
    }
    stdout.writeln(
      'Phase 4 offline fixture µs: open=$opened edit=$edited '
      'seeds+stats=$computed merge+repeat=${restore.elapsedMicroseconds}',
    );
    expect(incoming.items, hasLength(1000));
    expect(incoming.find(1, 'movie')?.notes, '=keep my notes');
    expect(incoming.find(1, 'movie')?.review, 'Updated offline');
    expect(incoming.find(1, 'movie')?.dateWatched, day);
    expect(
      incoming.achievements,
      containsAll(['preserved-legacy-id', 'first-watch']),
    );
    expect(restored.state.diary, hasLength(1));
    expect(restored.state.marked, hasLength(1));
    await Hive.close();
    Hive.init(newInstall.path);
    final restarted = PersonalLibrary(
      HivePersonalStore(initialize: () async {}),
    );
    await restarted.initialize();
    expect(restarted.state.diary['added']?.review, '"Second, viewing"');
    expect(restarted.state.marked.containsKey(first.key), true);
  });

  test(
    'ranking is bounded and explains each candidate with the actual source',
    () async {
      final requested = <String>[];
      final transport = TmdbTransport(
        credential: () async => 'fixture',
        performance: AppPerformance(),
        client: MockClient((request) async {
          requested.add(request.url.path);
          return http.Response(
            jsonEncode({
              'results': [
                for (final id in [11, 99, 100, 101])
                  {'id': id, 'title': 'Fixture $id', 'media_type': 'movie'},
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(transport.close);
      final state = PersonalState(
        diary: {'event': Viewing('event', film, day, rating: 5)},
        hidden: {
          '/movie/99': const PersonalTitle(
            TitleRoute((kind: EntityKind.movie, id: 99)),
            'Hidden',
          ),
        },
      );
      final saved = [WatchlistItem(id: 100, type: 'movie', title: 'Saved')];
      final seeds = PersonalDiscovery.sources(state, saved);
      final results = await PersonalDiscovery(CatalogueRepository(transport))
          .picks(state, saved, seeds);
      expect(seeds.first.title.key, film.key);
      expect(requested.length, lessThanOrEqualTo(3));
      expect(results.single.media.id, 101);
      expect(
        results.single.sources.map((source) => source.title.key),
        contains(film.key),
      );
    },
  );
}
