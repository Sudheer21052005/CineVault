import 'package:provider/provider.dart';

import '../app/navigation_scope.dart';
import '../app/route_contract.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/entity_ref.dart';
import '../catalogue/knowledge_models.dart';
import '../catalogue/paged_controller.dart';
import '../core/material.dart';
import '../core/performance.dart';
import 'catalogue_widgets.dart';
import 'design_system.dart';
import 'graph_widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({required this.location, super.key});
  final TabRoute location;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _text = TextEditingController();
  final _focus = FocusNode(debugLabel: 'title search');
  final _scroll = ScrollController();
  late final _pages = PagedController<SearchHit>(
    onFirstPage: (success) {
      _outcome = success ? PerfOutcome.success : PerfOutcome.failure;
    },
  );
  late TabRoute _location;
  Stopwatch? _started;
  PerfOutcome? _outcome;
  ValueNotifier<int>? _searchRequests;

  @override
  void initState() {
    super.initState();
    _setLocation(widget.location, immediate: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final requests = CineNavigation.of(context).searchRequests;
    if (identical(requests, _searchRequests)) return;
    _searchRequests?.removeListener(_focusSearch);
    _searchRequests = requests..addListener(_focusSearch);
  }

  void _focusSearch() {
    if (_scroll.hasClients && _scroll.offset > 0) _scroll.jumpTo(0);
    _focus.requestFocus();
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.location.uri != _location.uri) {
      _setLocation(widget.location, immediate: true);
    }
  }

  void _setLocation(
    TabRoute location, {
    required bool immediate,
    bool synchronize = true,
  }) {
    _location = location;
    if (synchronize && _text.text != location.text) {
      _text.value = TextEditingValue(
        text: location.text,
        selection: TextSelection.collapsed(offset: location.text.length),
      );
    }
    final repository = context.read<CatalogueRepository>();
    final filters = location.discovery;
    final term = location.text.trim();
    _outcome = null;
    if (filters == null && term.isEmpty) {
      _started = null;
      _pages.setQuery(null);
      return;
    }
    _started = Stopwatch()..start();
    context.read<AppPerformance>().record(
      const PerfSample(
        PerfEvent.searchInput,
        Duration.zero,
        area: PerfArea.search,
      ),
    );
    if (filters != null) {
      _pages.setQuery((page, {required refresh}) async {
        final result = await repository.discover(
          filters,
          page: page,
          refresh: refresh,
        );
        return CataloguePage(
          items: result.items.map(SearchHit.title).toList(),
          page: result.page,
          totalPages: result.totalPages,
          totalResults: result.totalResults,
        );
      });
    } else {
      _pages.setQuery(
        (page, {required refresh}) => repository.universalSearch(
          term,
          location.scope,
          page: page,
          refresh: refresh,
        ),
        debounce: immediate ? Duration.zero : const Duration(milliseconds: 300),
      );
    }
  }

  void _apply(
    TabRoute location, {
    bool immediate = true,
    bool synchronize = true,
  }) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(
      () => _setLocation(
        location,
        immediate: immediate,
        synchronize: synchronize,
      ),
    );
    CineNavigation.of(context).updateSearch(context, location);
  }

  void _search(String value, {bool immediate = false}) {
    final location = TabRoute(
      AppTab.search,
      text: value.trim(),
      scope: _location.scope,
    );
    if (!immediate && location.uri == _location.uri) return;
    _apply(location, immediate: immediate, synchronize: false);
  }

  void _markFirstPaint() {
    final started = _started;
    final outcome = _outcome;
    if (!mounted || started == null || outcome == null) return;
    _started = null;
    context.read<AppPerformance>().record(
      PerfSample(
        _location.discovery == null
            ? PerfEvent.searchResults
            : PerfEvent.searchDiscovery,
        started.elapsed,
        area: PerfArea.search,
        outcome: outcome,
      ),
    );
  }

  Future<void> _openFilters() async {
    final original = _location.discovery ?? defaultDiscovery;
    _focus.unfocus();
    final filters = CineLayout.widthOf(context) == CineWidth.compact
        ? await showModalBottomSheet<DiscoveryQuery>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => _FilterForm(initial: original),
          )
        : await showDialog<DiscoveryQuery>(
            context: context,
            builder: (_) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 525),
                child: _FilterForm(initial: original),
              ),
            ),
          );
    if (!mounted || filters == null) return;
    _apply(TabRoute(AppTab.search, scope: _location.scope, discovery: filters));
  }

  @override
  void dispose() {
    _searchRequests?.removeListener(_focusSearch);
    _focus.dispose();
    _text.dispose();
    _scroll.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = _location.discovery;
    final hint = switch (_location.scope) {
      SearchScope.all => 'Search movies and TV shows, and people',
      SearchScope.movie => 'Search movies',
      SearchScope.tv => 'Search TV shows',
      SearchScope.person => 'Search people',
      SearchScope.collection => 'Search collections',
      SearchScope.company => 'Search production companies',
      SearchScope.keyword => 'Search keywords',
    };
    return PagedBrowseView(
      pages: _pages,
      results: (hits) => CatalogueGrid(
        count: hits.length,
        itemBuilder: (_, index) {
          final hit = hits[index];
          final title = hit.media;
          if (title != null) {
            return PosterCard(media: title, heroTag: 'search-${title.key}');
          }
          final season = hit.season;
          final episode = hit.episode;
          return EntityResultCard(
            link: hit.entity!,
            route: episode != null
                ? EpisodeRoute(episode)
                : season != null
                ? SeasonRoute(season)
                : null,
          );
        },
      ),
      scroll: _scroll,
      onFirstPaint: _markFirstPaint,
      heroPrefix: 'search',
      idle: const MessageState(
        icon: Icons.search_rounded,
        message: 'Search the TMDB catalogue to find your next story.',
      ),
      emptyMessage: filters == null
          ? (_location.scope == SearchScope.movie ||
                    _location.scope == SearchScope.tv
                ? 'No matching titles found.'
                : 'No matching results found.')
          : 'No titles match these discovery filters.',
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CineHeading('Search'),
          const SizedBox(height: 19),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: TextField(
              focusNode: _focus,
              controller: _text,
              onChanged: _search,
              onSubmitted: (value) => _search(value, immediate: true),
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: const Icon(Icons.search_rounded, color: blue),
                suffixIcon: IconButton(
                  tooltip: 'Clear search',
                  onPressed: () =>
                      _apply(TabRoute(AppTab.search, scope: _location.scope)),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (scope, label) in const [
                (SearchScope.all, 'Titles & people'),
                (SearchScope.movie, 'Movies'),
                (SearchScope.tv, 'TV Shows'),
                (SearchScope.person, 'People'),
                (SearchScope.collection, 'Collections'),
                (SearchScope.company, 'Companies'),
                (SearchScope.keyword, 'Keywords'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: filters == null && _location.scope == scope,
                  onSelected: (_) => _apply(
                    TabRoute(
                      AppTab.search,
                      text: _text.text.trim(),
                      scope: scope,
                    ),
                  ),
                ),
              ActionChip(
                avatar: Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: filters == null ? muted : blue,
                ),
                label: const Text('Discovery filters'),
                onPressed: _openFilters,
              ),
            ],
          ),
          if (externalReference(_location.text) case (
            source: final source,
            value: _,
          ))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'External ID lookup · ${source.split('_').first.toUpperCase()}',
                style: cineLabel(color: blue),
              ),
            )
          else if (_location.text.isEmpty && filters == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: GraphMessage(
                'Search by name or paste an IMDb ID such as tt1375666.',
              ),
            ),
          if (filters != null)
            Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Text(
                'Browsing ${filters.kind == MediaKind.movie ? 'movies' : 'TV shows'}'
                '${filters.year == null ? '' : ' · ${filters.year}'}'
                '${filters.minimumRating == null ? '' : ' · ${filters.minimumRating}+ TMDB'}'
                ' · ${filters.sort.label}',
                style: const TextStyle(
                  color: blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterForm extends StatefulWidget {
  const _FilterForm({required this.initial});
  final DiscoveryQuery initial;

  @override
  State<_FilterForm> createState() => _FilterFormState();
}

class _FilterFormState extends State<_FilterForm> {
  late MediaKind _kind = widget.initial.kind;
  late int? _genre = widget.initial.genre;
  late int? _year = widget.initial.year;
  late double? _rating = widget.initial.minimumRating;
  late CatalogueSort _sort = widget.initial.sort;
  late Future<List<Genre>> _genres;

  @override
  void initState() {
    super.initState();
    _genres = context.read<CatalogueRepository>().genres(_kind);
  }

  void _selectKind(MediaKind kind) {
    if (_kind == kind) return;
    _kind = kind;
    _genre = null;
    _genres = context.read<CatalogueRepository>().genres(kind);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Discovery filters', style: cineDisplay(29)),
        const SizedBox(height: 8),
        const Text('Browse the catalogue by type, genre, year, or score.'),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 5,
          children: [
            ChoiceChip(
              label: const Text('Movies'),
              selected: _kind == MediaKind.movie,
              onSelected: (_) => setState(() => _selectKind(MediaKind.movie)),
            ),
            ChoiceChip(
              label: const Text('TV Shows'),
              selected: _kind == MediaKind.tv,
              onSelected: (_) => setState(() => _selectKind(MediaKind.tv)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Genre>>(
          future: _genres,
          builder: (context, snapshot) {
            final list = snapshot.connectionState == ConnectionState.done
                ? snapshot.data ?? const <Genre>[]
                : const <Genre>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SelectField<int>(
                  label: 'Genre',
                  selected: _genre,
                  any: 'All genres',
                  values: {
                    if (_genre != null &&
                        !list.any((genre) => genre.id == _genre))
                      _genre!: 'Selected genre',
                    for (final genre in list) genre.id: genre.name,
                  },
                  onChanged: (value) => setState(() => _genre = value),
                ),
                if (snapshot.hasError)
                  TextButton(
                    onPressed: () => setState(() {
                      _genres = context.read<CatalogueRepository>().genres(
                        _kind,
                        refresh: true,
                      );
                    }),
                    child: const Text('Retry loading genres'),
                  ),
              ],
            );
          },
        ),
        _SelectField<int>(
          label: _kind == MediaKind.movie ? 'Release year' : 'First air year',
          selected: _year,
          any: 'Any year',
          values: {
            for (final year in {
              ...List.generate(30, (index) => DateTime.now().year - index),
              ?_year,
            })
              year: '$year',
          },
          onChanged: (value) => setState(() => _year = value),
        ),
        _SelectField<double>(
          label: 'Minimum TMDB score',
          selected: _rating,
          any: 'Any score',
          values: {
            for (final score in {6.0, 7.0, 8.0, 9.0, ?_rating})
              score: '$score+',
          },
          onChanged: (value) => setState(() => _rating = value),
        ),
        _SelectField<CatalogueSort>(
          label: 'Sort by',
          selected: _sort,
          values: {for (final sort in CatalogueSort.values) sort: sort.label},
          onChanged: (value) =>
              setState(() => _sort = value ?? CatalogueSort.popularity),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: () => Navigator.pop(context, (
                kind: _kind,
                genre: _genre,
                year: _year,
                minimumRating: _rating,
                sort: _sort,
              )),
              child: const Text('Apply filters'),
            ),
            TextButton(
              onPressed: () => setState(() {
                _selectKind(MediaKind.movie);
                _genre = null;
                _year = null;
                _rating = null;
                _sort = CatalogueSort.popularity;
              }),
              child: const Text('Reset'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SelectField<T> extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.selected,
    required this.values,
    required this.onChanged,
    this.any,
  });

  final String label;
  final T? selected;
  final String? any;
  final Map<T, String> values;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: DropdownButtonFormField<T?>(
      key: ValueKey((label, selected)),
      initialValue: selected,
      isExpanded: true,
      itemHeight: null,
      decoration: InputDecoration(labelText: label),
      items: [
        if (any != null) DropdownMenuItem<T?>(value: null, child: Text(any!)),
        for (final item in values.entries)
          DropdownMenuItem<T?>(
            value: item.key,
            child: Text(item.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    ),
  );
}
