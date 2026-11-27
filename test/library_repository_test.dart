import 'dart:async';
import 'dart:io';

import 'package:cinevault/library/hive_library_store.dart';
import 'package:cinevault/library/library_repository.dart';
import 'package:cinevault/models/media.dart';
import 'package:cinevault/models/watchlist_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'support/memory_library_store.dart';

void main() {
  const movie = Media(id: 42, type: 'movie', title: 'Fixture title');
  const show = Media(id: 42, type: 'tv', title: 'Fixture series');

  test('reads positional Hive records of each historic length and writes current data', () async {
    final temp = await Directory.systemTemp.createTemp('cinevault-hive-');
    addTearDown(() async {
      await Hive.close();
      Hive.resetAdapters();
      await temp.delete(recursive: true);
    });
    Hive.init(temp.path);
    Hive.registerAdapter(_LegacyAdapter());
    final box = await Hive.openBox<WatchlistItem>(
      HiveLibraryStore.watchlistBox,
    );
    final achievements = await Hive.openBox<String>(
      HiveLibraryStore.achievementsBox,
    );
    final date = DateTime(2026, 11, 27);
    for (var id = 1; id <= 4; id++) {
      await box.put(
        'movie-$id',
        WatchlistItem(
          id: id,
          type: 'movie',
          title: 'Fixture $id',
          status: WatchStatus.watched,
          userRating: 4.5,
          notes: 'Legacy note',
          review: 'Legacy review',
          genres: const ['Drama'],
          dateWatched: date,
          addedAt: date,
        ),
      );
    }
    await achievements.add('historic-unlock');
    await Hive.close();
    Hive.resetAdapters();

    LibraryRepository reopen() =>
        LibraryRepository(HiveLibraryStore(initializeHive: () async {}));
    final repository = reopen();
    await repository.initialize();
    expect(repository.items.map((item) => item.key), [
      'movie-1',
      'movie-2',
      'movie-3',
      'movie-4',
    ]);
    expect(repository.items.map((item) => item.review), [
      '',
      'Legacy review',
      'Legacy review',
      'Legacy review',
    ]);
    expect(repository.items.map((item) => item.genres.length), [0, 0, 1, 1]);
    expect(repository.items.map((item) => item.dateWatched), [
      null,
      null,
      null,
      date,
    ]);
    expect(repository.items.last.notes, 'Legacy note');
    expect(repository.items.last.rating, 0);
    expect(repository.items.last.addedAt, date);
    expect(repository.items.last.status, WatchStatus.watched);
    expect(repository.achievements, {'historic-unlock', 'first-watch'});
    await repository.update(repository.items.last, (
      status: WatchStatus.watched,
      rating: null,
      notes: 'Updated',
      review: 'Kept',
      watchedDate: null,
    ));
    await repository.save(movie);
    await repository.save(show);
    await Hive.close();
    final reloaded = reopen();
    await reloaded.initialize();
    final current = reloaded.find(4, 'movie')!;
    expect((current.userRating, current.dateWatched), (null, null));
    expect((current.notes, current.review), ('Updated', 'Kept'));
    expect(current.genres, ['Drama']);
    expect(reloaded.find(42, 'movie')?.title, movie.title);
    expect(reloaded.find(42, 'tv')?.title, show.title);
    expect(reloaded.achievements, {'historic-unlock', 'first-watch'});
    expect(
      Hive.box<String>(HiveLibraryStore.achievementsBox).values.toList(),
      hasLength(2),
    );
  });

  test(
    'does not reseed an empty library after deleting the final title',
    () async {
      final store = MemoryLibraryStore();
      final first = LibraryRepository(store);
      await first.initialize();
      expect(first.items, isEmpty);
      await first.save(movie);
      await first.remove(first.items.single);
      final reopened = LibraryRepository(store);
      await reopened.initialize();
      expect(reopened.items, isEmpty);
      expect(store.puts, 1);
    },
  );

  test(
    'publishes only committed item writes and recovers after staged failures',
    () async {
      final store = MemoryLibraryStore()..failOpen = true;
      final repository = LibraryRepository(store);
      await expectLater(repository.initialize(), throwsStateError);
      expect(repository.ready, isFalse);
      store.failOpen = false;
      await repository.initialize();
      store.failPut = true;
      await expectLater(repository.save(movie), throwsStateError);
      expect(repository.items, isEmpty);
      store.failPut = false;
      await repository.save(movie);
      final original = repository.items.single;
      store.failPut = true;
      await expectLater(
        repository.update(original, _edit(original, notes: 'Failed edit')),
        throwsStateError,
      );
      expect(repository.items.single.notes, '');
      store.failDelete = true;
      await expectLater(repository.remove(original), throwsStateError);
      expect(repository.items.single, same(original));
      store.failPut = false;
      store.failUnlock = true;
      await repository.update(
        original,
        _edit(original, status: WatchStatus.watched),
      );
      expect(repository.items.single.status, WatchStatus.watched);
      expect(repository.achievementsNeedRetry, isTrue);
      expect(repository.achievements, isEmpty);
      store.failUnlock = false;
      await repository.initialize();
      expect(repository.achievementsNeedRetry, isFalse);
      expect(repository.achievements, {'first-watch'});
    },
  );

  test('serializes racing saves, merges disjoint concurrent edits and cannot resurrect old entries', () async {
    final store = MemoryLibraryStore();
    final repository = LibraryRepository(store);
    await repository.initialize();
    final blocked = store.blockPut = Completer<void>();
    final first = repository.save(movie);
    final second = repository.save(movie);
    await Future<void>.delayed(Duration.zero);
    expect(store.puts, 1);
    expect(repository.items, isEmpty);
    blocked.complete();
    await Future.wait([first, second]);
    expect(store.puts, 1);
    final original = repository.items.single;
    await Future.wait([
      repository.update(original, _edit(original, notes: 'New notes')),
      repository.update(original, _edit(original, review: 'New review')),
    ]);
    expect(
      (repository.items.single.notes, repository.items.single.review),
      ('New notes', 'New review'),
    );
    final deletion = repository.remove(original);
    await expectLater(
      repository.update(original, _edit(original, review: 'Too late')),
      throwsA(isA<LibraryEditConflict>()),
    );
    await deletion;
    expect(repository.items, isEmpty);
  });
}

LibraryEdit _edit(
  WatchlistItem item, {
  WatchStatus? status,
  String? notes,
  String? review,
}) => (
  status: status ?? item.status,
  rating: item.userRating,
  notes: notes ?? item.notes,
  review: review ?? item.review,
  watchedDate: item.dateWatched,
);

/// Writes the original prefix and the append-only formats deployed since.
class _LegacyAdapter extends TypeAdapter<WatchlistItem> {
  @override
  final typeId = 1;

  @override
  WatchlistItem read(BinaryReader reader) =>
      throw UnsupportedError('Fixture writer');

  @override
  void write(BinaryWriter writer, WatchlistItem item) {
    writer
      ..writeInt(item.id)
      ..writeString(item.type)
      ..writeString(item.title)
      ..writeString('')
      ..writeDouble(item.rating)
      ..writeString(item.status.name)
      ..write(item.userRating)
      ..writeString(item.notes)
      ..writeInt(item.addedAt.millisecondsSinceEpoch);
    if (item.id >= 2) writer.writeString(item.review);
    if (item.id >= 3) writer.write(item.genres);
    if (item.id >= 4) writer.write(item.dateWatched?.millisecondsSinceEpoch);
  }
}
