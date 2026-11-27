import 'package:provider/provider.dart';

import '../app/navigation_scope.dart';
import '../app/route_contract.dart';
import '../catalogue/artwork_policy.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/entity_ref.dart';
import '../catalogue/knowledge_models.dart';
import '../catalogue/paged_controller.dart';
import '../core/material.dart';
import '../models/media.dart';
import 'artwork.dart';
import 'catalogue_widgets.dart';
import 'design_system.dart';
import 'graph_widgets.dart';
import 'media_sections.dart';

class PersonPage extends StatelessWidget {
  const PersonPage({required this.ref, super.key});
  final EntityRef ref;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CatalogueRepository>();
    return GraphLoad<Json>(
      fullPage: true,
      load: ({required refresh}) => repository.entity(ref, refresh: refresh),
      builder: (context, person) {
        final name = text(person['name']) ?? 'Person';
        return CinePage(
          scrollKey: const PageStorageKey('person'),
          slivers: [
            CineSliver(
              top: 23,
              bottom: 17,
              child: GraphHeader(
                title: name,
                category: 'Person',
                image: text(person['profile_path']),
                artKind: ArtworkKind.profile,
                subtitle: text(person['known_for_department']),
                actions: [
                  GraphLink(
                    'Full filmography',
                    FilmographyRoute(ref.id),
                    icon: Icons.movie_filter_outlined,
                  ),
                ],
              ),
            ),
            CineSliver(
              bottom: 16,
              child: GraphPanel(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final biography = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GraphHeading('Biography'),
                        GraphMessage(
                          text(person['biography']) ??
                              'Biography is unavailable on TMDB.',
                        ),
                      ],
                    );
                    final facts = FactList([
                      ('Born', text(person['birthday'])),
                      ('Died', text(person['deathday'])),
                      ('Place of birth', text(person['place_of_birth'])),
                      (
                        'Also known as',
                        joined(strings(person['also_known_as'])),
                      ),
                    ]);
                    if (box.maxWidth < 750) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [biography, facts],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: biography),
                        const SizedBox(width: 24),
                        Expanded(child: facts),
                      ],
                    );
                  },
                ),
              ),
            ),
            CineSliver(
              bottom: 16,
              child: GraphLoad<Json>(
                load: ({required refresh}) =>
                    repository.filmography(ref.id, refresh: refresh),
                builder: (context, data) {
                  final films = readFilmography(data);
                  if (films == null || films.isEmpty) {
                    return GraphMessage(
                      films == null
                          ? 'Filmography metadata is unavailable.'
                          : 'TMDB lists no known credits.',
                    );
                  }
                  final popular = const FilmographyFilter()
                      .apply(films)
                      .take(12);
                  return PosterShelf(
                    title: 'Known for',
                    shelfId: 'person-${ref.id}-known',
                    items: popular.map((credit) => credit.title).toList(),
                    trailing: GraphLink(
                      'Filmography',
                      FilmographyRoute(ref.id),
                    ),
                  );
                },
              ),
            ),
            CineSliver(
              bottom: 10,
              child: GraphSection(
                key: const PageStorageKey('person-images'),
                title: 'Photographs',
                icon: Icons.photo_library_outlined,
                builder: (_) => GraphLoad<Json>(
                  load: ({required refresh}) => repository.section(
                    ref,
                    KnowledgeSection.images,
                    refresh: refresh,
                  ),
                  builder: (_, data) => Gallery(
                    data: data,
                    groups: const [
                      ('profiles', 'Photographs', ArtworkKind.profile),
                    ],
                  ),
                ),
              ),
            ),
            CineSliver(
              child: SourceLinks(
                ref: ref,
                data: person,
                extra: object(person['external_ids']),
              ),
            ),
          ],
        );
      },
    );
  }
}

class FilmographyPage extends StatelessWidget {
  const FilmographyPage({required this.route, super.key});
  final FilmographyRoute route;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CatalogueRepository>();
    final ref = (kind: EntityKind.person, id: route.personId);
    return GraphLoad<(Json, Json)>(
      fullPage: true,
      load: ({required refresh}) async {
        final results = await Future.wait([
          repo.entity(ref, refresh: refresh),
          repo.filmography(ref.id, refresh: refresh),
        ]);
        return (results[0], results[1]);
      },
      builder: (context, result) => _FilmographyView(
        route: route,
        person: result.$1,
        credits: readFilmography(result.$2),
      ),
    );
  }
}

class _FilmographyView extends StatefulWidget {
  const _FilmographyView({
    required this.route,
    required this.person,
    required this.credits,
  });
  final FilmographyRoute route;
  final Json person;
  final List<FilmCredit>? credits;

  @override
  State<_FilmographyView> createState() => _FilmographyViewState();
}

class _FilmographyViewState extends State<_FilmographyView> {
  final _scroll = ScrollController();
  late final _genres = _loadGenres();

  Future<List<(GenreRef, String)>> _loadGenres() async {
    final repo = context.read<CatalogueRepository>();
    final dictionaries = await Future.wait([
      repo.genres(MediaKind.movie),
      repo.genres(MediaKind.tv),
    ]);
    return [
      for (final kind in MediaKind.values)
        for (final genre in dictionaries[kind.index])
          (
            (kind: kind, id: genre.id),
            '${genre.name} · ${kind == MediaKind.movie ? 'Movie' : 'TV'}',
          ),
    ];
  }

  void _select(FilmographyFilter filter) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    CineNavigation.of(
      context,
    ).replace(context, FilmographyRoute(widget.route.personId, filter: filter));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = widget.route.filter;
    final all = widget.credits;
    final visible = all == null
        ? const <FilmCredit>[]
        : filter.apply(all).toList();
    final name = text(widget.person['name']) ?? 'Person';
    final person = (kind: EntityKind.person, id: widget.route.personId);
    final roles = <String>{
      for (final credit in all ?? const <FilmCredit>[])
        for (final role in credit.roles)
          if (!role.cast && role.role != 'crew' && role.role != 'cast')
            role.role,
    }.toList()..sort();
    final years = <int>{
      for (final credit in all ?? const <FilmCredit>[])
        ?credit.title.releaseDate?.year,
    }.toList()..sort((a, b) => b.compareTo(a));
    return CinePage(
      controller: _scroll,
      scrollKey: const PageStorageKey('filmography'),
      slivers: [
        CineSliver(
          top: 23,
          bottom: 16,
          child: GraphHeader(
            title: 'Filmography',
            category: name,
            subtitle:
                '${visible.length} of ${all?.length ?? 0} credited titles',
            image: text(widget.person['profile_path']),
            artKind: ArtworkKind.profile,
            actions: [
              GraphLink(name, TitleRoute(person), icon: Icons.person_outline),
            ],
          ),
        ),
        CineSliver(
          bottom: 16,
          child: GraphPanel(
            child: FutureBuilder<List<(GenreRef, String)>>(
              future: _genres,
              builder: (context, snapshot) => Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _facet<MediaKind>(
                    'Media',
                    filter.kind,
                    const [
                      (null, 'All media'),
                      (MediaKind.movie, 'Movies'),
                      (MediaKind.tv, 'TV shows'),
                    ],
                    (kind) => _select(
                      FilmographyFilter(
                        kind: kind,
                        role: filter.role,
                        genre: kind != null && filter.genre?.kind != kind
                            ? null
                            : filter.genre,
                        year: filter.year,
                        minimumVotes: filter.minimumVotes,
                        sort: filter.sort,
                      ),
                    ),
                  ),
                  _facet<String>(
                    'Role',
                    filter.role,
                    [
                      (null, 'All roles'),
                      ('cast', 'Acting'),
                      ('crew', 'All crew'),
                      for (final role in roles) (role, role),
                    ],
                    (role) => _select(
                      FilmographyFilter(
                        kind: filter.kind,
                        role: role,
                        genre: filter.genre,
                        year: filter.year,
                        minimumVotes: filter.minimumVotes,
                        sort: filter.sort,
                      ),
                    ),
                  ),
                  _facet<GenreRef>(
                    'Genre',
                    filter.genre,
                    [
                      (null, 'All genres'),
                      for (final (genre, label)
                          in snapshot.data ?? const <(GenreRef, String)>[])
                        if (filter.kind == null || genre.kind == filter.kind)
                          (genre, label),
                    ],
                    (genre) => _select(
                      FilmographyFilter(
                        kind: filter.kind,
                        role: filter.role,
                        genre: genre,
                        year: filter.year,
                        minimumVotes: filter.minimumVotes,
                        sort: filter.sort,
                      ),
                    ),
                  ),
                  _facet<int>(
                    'Year',
                    filter.year,
                    [
                      (null, 'All years'),
                      for (final year in years) (year, '$year'),
                    ],
                    (year) => _select(
                      FilmographyFilter(
                        kind: filter.kind,
                        role: filter.role,
                        genre: filter.genre,
                        year: year,
                        minimumVotes: filter.minimumVotes,
                        sort: filter.sort,
                      ),
                    ),
                  ),
                  _facet<int>(
                    'Minimum votes',
                    filter.minimumVotes,
                    [
                      (0, 'Any vote count'),
                      for (final votes in {
                        10,
                        50,
                        100,
                        500,
                        1000,
                        if (filter.minimumVotes > 0) filter.minimumVotes,
                      })
                        (votes, '$votes+ votes'),
                    ],
                    (votes) => _select(
                      FilmographyFilter(
                        kind: filter.kind,
                        role: filter.role,
                        genre: filter.genre,
                        year: filter.year,
                        minimumVotes: votes ?? 0,
                        sort: filter.sort,
                      ),
                    ),
                  ),
                  _facet<FilmSort>(
                    'Sort by',
                    filter.sort,
                    [for (final sort in FilmSort.values) (sort, sort.label)],
                    (sort) => _select(
                      FilmographyFilter(
                        kind: filter.kind,
                        role: filter.role,
                        genre: filter.genre,
                        year: filter.year,
                        minimumVotes: filter.minimumVotes,
                        sort: sort ?? FilmSort.popularity,
                      ),
                    ),
                  ),
                  if (snapshot.hasError)
                    const GraphMessage('Genre names are unavailable.'),
                  TextButton(
                    onPressed: () => _select(const FilmographyFilter()),
                    child: const Text('Clear filters'),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (visible.isEmpty)
          CineSliver(
            child: MessageState(
              message: all == null
                  ? 'Filmography metadata is unavailable.'
                  : all.isEmpty
                  ? 'TMDB lists no credited titles.'
                  : 'No credits match these filters.',
            ),
          ),
        if (visible.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: CineLayout.gutterOf(context),
            ),
            sliver: SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) => _FilmRow(credit: visible[index]),
            ),
          ),
      ],
    );
  }

  Widget _facet<T>(
    String label,
    T? value,
    List<(T?, String)> options,
    ValueChanged<T?> update,
  ) {
    final available = <(T?, String)>[
      ...options,
      if (!options.any((entry) => entry.$1 == value) && value != null)
        (value, 'Current selection'),
    ];
    return SizedBox(
      width: 177,
      child: DropdownButtonFormField<T>(
        key: ValueKey((label, value)),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final (value, name) in available)
            DropdownMenuItem(
              value: value,
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: update,
      ),
    );
  }
}

class _FilmRow extends StatelessWidget {
  const _FilmRow({required this.credit});
  final FilmCredit credit;

  @override
  Widget build(BuildContext context) {
    final item = credit.title;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 7,
            horizontal: 12,
          ),
          leading: SizedBox(
            width: 35,
            height: 50,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: CineArt(path: item.posterPath),
            ),
          ),
          title: Text(
            item.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            '${item.isMovie ? 'Film' : 'TV'} · ${item.year}'
            '${item.voteCount > 0 ? ' · ${item.rating.toStringAsFixed(1)} / 10 (${item.voteCount} votes)' : ''}'
            '\n${credit.roles.map(creditLabel).join(' · ')}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: blue),
          onTap: () => CineNavigation.of(context).openTitle(context, item),
        ),
      ),
    );
  }
}

class CatalogueEntityPage extends StatelessWidget {
  const CatalogueEntityPage({required this.ref, super.key});
  final EntityRef ref;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CatalogueRepository>();
    return GraphLoad<Json>(
      fullPage: true,
      load: ({required refresh}) => repo.entity(ref, refresh: refresh),
      builder: (context, data) {
        final name = text(data['name']) ?? entityLabel(ref.kind);
        final heading = GraphHeader(
          title: name,
          category: entityLabel(ref.kind),
          image: text(data['poster_path']) ?? text(data['logo_path']),
          artKind: ref.kind == EntityKind.collection
              ? ArtworkKind.poster
              : ArtworkKind.logo,
          subtitle: joined([
            ?text(data['headquarters']),
            ?text(data['origin_country']),
          ], separator: ' · '),
          actions: [
            if (website(data['homepage']) case final url?)
              ExternalLink('Official site', url),
            ExternalLink(
              'View on TMDB',
              Uri.https('www.themoviedb.org', '/${ref.kind.name}/${ref.id}'),
            ),
          ],
        );
        if (ref.kind == EntityKind.collection) {
          final parts =
              [
                for (final item in objects(data['parts']))
                  if (item['adult'] != true && (integer(item['id']) ?? 0) > 0)
                    Media.fromJson(item, forcedType: 'movie'),
              ]..sort((a, b) {
                final aDate = a.releaseDate;
                final bDate = b.releaseDate;
                if (aDate == null) {
                  return bDate == null ? a.id.compareTo(b.id) : 1;
                }
                return bDate == null ? -1 : aDate.compareTo(bDate);
              });
          return CinePage(
            scrollKey: const PageStorageKey('collection'),
            slivers: [
              CineSliver(top: 23, bottom: 16, child: heading),
              if (text(data['overview']) case final overview?)
                CineSliver(
                  bottom: 16,
                  child: GraphPanel(child: Text(overview)),
                ),
              CineSliver(
                bottom: 14,
                child: GraphHeading('Films in this collection'),
              ),
              if (parts.isNotEmpty)
                PosterGrid(heroPrefix: 'collection-${ref.id}', items: parts)
              else
                CineSliver(
                  child: MessageState(
                    message: data['parts'] is List
                        ? 'TMDB lists no titles in this collection.'
                        : 'Collection membership is unavailable.',
                  ),
                ),
            ],
          );
        }
        final parent = EntityLink.read(
          object(data['parent_company']),
          EntityKind.company,
        );
        return _AssociatedTitles(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (text(data['description']) case final description?)
                GraphMessage(description),
              if (parent != null)
                GraphLink(
                  'Parent company · ${parent.name}',
                  TitleRoute(parent.ref),
                ),
            ],
          ),
          initialKind: ref.kind == EntityKind.network
              ? MediaKind.tv
              : MediaKind.movie,
          canSwitch: ref.kind != EntityKind.network,
          loader: (kind) => repo.associated(kind, entity: ref),
        );
      },
    );
  }
}

class GenrePage extends StatelessWidget {
  const GenrePage({required this.ref, super.key});
  final GenreRef ref;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CatalogueRepository>();
    return GraphLoad<List<Genre>>(
      fullPage: true,
      load: ({required refresh}) => repo.genres(ref.kind, refresh: refresh),
      builder: (context, values) {
        final genre = values.where((genre) => genre.id == ref.id).firstOrNull;
        if (genre == null) {
          return CinePage(
            slivers: [
              CineSliver(
                top: 23,
                child: GraphHeader(
                  title: 'Genre unavailable',
                  category: 'Genre',
                  subtitle:
                      'TMDB does not list this genre for ${ref.kind == MediaKind.movie ? 'movies' : 'TV shows'}.',
                ),
              ),
            ],
          );
        }
        return _AssociatedTitles(
          header: GraphHeader(
            title: genre.name,
            category: ref.kind == MediaKind.movie ? 'Movie genre' : 'TV genre',
          ),
          loader: (kind) => repo.associated(kind, genre: ref),
          initialKind: ref.kind,
        );
      },
    );
  }
}

class _AssociatedTitles extends StatefulWidget {
  const _AssociatedTitles({
    required this.header,
    required this.loader,
    required this.initialKind,
    this.canSwitch = false,
  });
  final Widget header;
  final PageLoader Function(MediaKind) loader;
  final MediaKind initialKind;
  final bool canSwitch;

  @override
  State<_AssociatedTitles> createState() => _AssociatedTitlesState();
}

class _AssociatedTitlesState extends State<_AssociatedTitles> {
  final _pages = <MediaKind, PagedController<Media>>{};
  late MediaKind _kind = widget.initialKind;
  bool _restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored || !widget.canSwitch) return;
    _restored = true;
    final saved = PageStorage.maybeOf(context)
        ?.readState(context, identifier: 'associated media');
    if (saved is MediaKind) _kind = saved;
  }

  PagedController<Media> get _current => _pages.putIfAbsent(
    _kind,
    () => PagedController<Media>()..setQuery(widget.loader(_kind)),
  );

  @override
  void dispose() {
    for (final pages in _pages.values) {
      pages.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PagedBrowseView(
    key: ValueKey(_kind),
    pages: _current,
    scrollKey: PageStorageKey('associated-${_kind.name}'),
    heroPrefix: 'associated-${_kind.name}',
    results: (items) =>
        PosterGrid(heroPrefix: 'associated-${_kind.name}', items: items),
    emptyMessage: 'TMDB lists no associated titles.',
    header: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.header,
        const SizedBox(height: 18),
        const GraphHeading('Associated titles'),
        if (widget.canSwitch)
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final kind in MediaKind.values)
                ChoiceChip(
                  label: Text(kind == MediaKind.movie ? 'Movies' : 'TV shows'),
                  selected: _kind == kind,
                  onSelected: (_) {
                    setState(() => _kind = kind);
                    PageStorage.maybeOf(context)?.writeState(
                      context,
                      kind,
                      identifier: 'associated media',
                    );
                  },
                ),
            ],
          ),
      ],
    ),
  );
}
