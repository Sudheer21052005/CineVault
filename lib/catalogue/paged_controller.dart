import 'dart:async';

import 'package:flutter/foundation.dart';

import 'catalogue_repository.dart';
import 'entity_ref.dart';

enum PageStatus { idle, loading, ready, refreshing, failed }

typedef PageState<T extends CatalogueItem> = ({
  List<T> items,
  PageStatus status,
  Object? error,
  bool loadingNext,
  Object? nextError,
  bool hasMore,
});

class PagedController<T extends CatalogueItem> extends ChangeNotifier {
  PagedController({this.onFirstPage});

  final void Function(bool success)? onFirstPage;
  final _items = <String, T>{};
  List<T> _snapshot = const [];
  PageStatus _status = PageStatus.idle;
  Object? _error;
  Object? _nextError;
  bool _loadingNext = false;
  bool _disposed = false;
  CataloguePage<T>? _page;
  Timer? _debounce;
  int _generation = 0;
  CatalogueLoader<T>? _load;

  PageState<T> get state => (
    items: _snapshot,
    status: _status,
    error: _error,
    loadingNext: _loadingNext,
    nextError: _nextError,
    hasMore: _page?.hasMore ?? false,
  );

  void setQuery(CatalogueLoader<T>? load, {Duration debounce = Duration.zero}) {
    _debounce?.cancel();
    _generation++;
    _load = load;
    _items.clear();
    _snapshot = const [];
    _page = null;
    _resetErrors();
    _status = load == null ? PageStatus.idle : PageStatus.loading;
    notifyListeners();
    if (load == null) return;
    if (debounce == Duration.zero) {
      unawaited(_first(refresh: false));
    } else {
      _debounce = Timer(debounce, () => unawaited(_first(refresh: false)));
    }
  }

  Future<void> refresh() => _first(refresh: true);

  bool canLoadNext({bool retry = false}) =>
      !_disposed &&
      _load != null &&
      (_page?.hasMore ?? false) &&
      !_loadingNext &&
      (_status == PageStatus.ready || _status == PageStatus.failed) &&
      (_nextError == null || retry);

  Future<void> _first({required bool refresh}) async {
    final load = _load;
    if (load == null) return;
    _debounce?.cancel();
    final generation = ++_generation;
    _resetErrors();
    _status = _items.isEmpty ? PageStatus.loading : PageStatus.refreshing;
    notifyListeners();
    try {
      final page = await load(1, refresh: refresh);
      if (!_current(generation)) return;
      _items.clear();
      _append(page);
      _status = PageStatus.ready;
      onFirstPage?.call(true);
    } catch (error) {
      if (!_current(generation)) return;
      _status = PageStatus.failed;
      _error = error;
      onFirstPage?.call(false);
    }
    if (_current(generation)) notifyListeners();
  }

  Future<void> loadNext({bool retry = false}) async {
    if (!canLoadNext(retry: retry)) return;
    final load = _load!;
    final page = _page!;
    final generation = _generation;
    _loadingNext = true;
    _nextError = null;
    notifyListeners();
    try {
      final next = await load(page.page + 1, refresh: retry);
      if (!_current(generation)) return;
      _append(next);
    } catch (error) {
      if (!_current(generation)) return;
      _nextError = error;
    }
    if (_current(generation)) {
      _loadingNext = false;
      notifyListeners();
    }
  }

  void _append(CataloguePage<T> page) {
    _page = page;
    for (final item in page.items) {
      _items.putIfAbsent(item.key, () => item);
    }
    _snapshot = List.unmodifiable(_items.values);
  }

  void _resetErrors() {
    _error = null;
    _nextError = null;
    _loadingNext = false;
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
