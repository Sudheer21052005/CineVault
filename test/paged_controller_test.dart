import 'dart:async';

import 'package:cinevault/catalogue/catalogue_repository.dart';
import 'package:cinevault/catalogue/paged_controller.dart';
import 'package:cinevault/core/network/tmdb_transport.dart';
import 'package:cinevault/models/media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const first = Media(id: 1, type: 'movie', title: 'First');
  const second = Media(id: 2, type: 'tv', title: 'Second');

  testWidgets('clear and debounce invalidate an old result immediately', (
    tester,
  ) async {
    final pages = PagedController<Media>();
    addTearDown(pages.dispose);
    final old = Completer<TmdbPage>();
    pages.setQuery((_, {required refresh}) => old.future);
    pages.setQuery(null);
    old.complete(_page([first]));
    await tester.pump();
    expect(pages.state.status, PageStatus.idle);
    expect(pages.state.items, isEmpty);
    var calls = 0;
    pages.setQuery((_, {required refresh}) async {
      calls++;
      return _page([first]);
    }, debounce: const Duration(milliseconds: 300));
    pages.setQuery((_, {required refresh}) async {
      calls++;
      return _page([second]);
    }, debounce: const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 301));
    expect(calls, 1);
    expect(pages.state.items, [second]);
  });

  testWidgets('a late old next page cannot append or lock the next query', (
    tester,
  ) async {
    final pages = PagedController<Media>();
    addTearDown(pages.dispose);
    final late = Completer<TmdbPage>();
    pages.setQuery(
      (page, {required refresh}) async =>
          page == 1 ? _page([first]) : late.future,
    );
    await tester.pump();
    unawaited(pages.loadNext());
    expect(pages.state.loadingNext, isTrue);
    pages.setQuery(
      (page, {required refresh}) async =>
          _page(page == 1 ? [second] : [second, first], number: page),
    );
    late.complete(_page([first], number: 2));
    await tester.pump();
    expect(pages.state.items, [second]);
    expect(pages.state.loadingNext, isFalse);
    await pages.loadNext();
    expect(pages.state.items, [second, first]);
    expect(pages.state.hasMore, isFalse);
  });

  testWidgets(
    'failed refresh keeps previous items and next-page retry is fresh',
    (tester) async {
      final pages = PagedController<Media>();
      addTearDown(pages.dispose);
      final fresh = <(int, bool)>[];
      var fail = false;
      pages.setQuery((page, {required refresh}) async {
        fresh.add((page, refresh));
        if (fail) throw const TmdbException(TmdbErrorKind.rateLimited);
        return _page(page == 1 ? [first] : [second], number: page);
      });
      await tester.pump();
      fail = true;
      await pages.refresh();
      expect(pages.state.status, PageStatus.failed);
      expect(pages.state.items, [first]);
      await pages.loadNext();
      expect(pages.state.nextError, isA<TmdbException>());
      fail = false;
      await pages.loadNext(retry: true);
      expect(pages.state.items, [first, second]);
      expect(fresh, [(1, false), (1, true), (2, false), (2, true)]);
    },
  );
}

TmdbPage _page(List<Media> items, {int number = 1}) =>
    TmdbPage(items: items, page: number, totalPages: 2, totalResults: 2);
