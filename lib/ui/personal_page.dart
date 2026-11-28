import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../app/navigation_scope.dart';
import '../app/route_contract.dart';
import '../catalogue/artwork_policy.dart';
import '../catalogue/entity_ref.dart';
import '../core/material.dart';
import '../library/personal_insights.dart';
import '../library/personal_library.dart';
import '../library/personal_models.dart';
import '../models/media.dart';
import '../providers/watchlist_provider.dart';
import 'artwork.dart';
import 'design_system.dart';
import 'graph_widgets.dart';
import 'personal_actions.dart';

const personalViews = {
  PersonalView.diary: 'Diary',
  PersonalView.progress: 'TV progress',
  PersonalView.favorites: 'Favorites',
  PersonalView.lists: 'Lists',
  PersonalView.recent: 'Recently explored',
  PersonalView.data: 'Backup & export',
};

class PersonalPage extends StatelessWidget {
  const PersonalPage({required this.view, super.key});
  final PersonalView view;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<PersonalLibrary?>();
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (CineLayout.widthOf(context) == CineWidth.compact)
          BackButton(onPressed: () => CineNavigation.of(context).back(context)),
        const CineHeading('Personal library'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final entry in personalViews.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: view == entry.key,
                onSelected: (_) => CineNavigation.of(
                  context,
                ).open(context, PersonalRoute(entry.key), label: entry.value),
              ),
          ],
        ),
      ],
    );
    return CinePage(
      scrollKey: PageStorageKey('personal-${view.name}'),
      slivers: [
        CineSliver(top: 20, bottom: 18, child: header),
        if (library == null || !library.ready)
          CineSliver(
            child: library?.failed == true
                ? MessageState(
                    message: 'Unable to open your personal library.',
                    onRetry: library!.initialize,
                  )
                : const CineSkeleton(height: 90),
          )
        else
          ..._content(context, library),
      ],
    );
  }

  List<Widget> _content(BuildContext context, PersonalLibrary library) {
    final state = library.state;
    List<Widget> empty(String label) => [
      CineSliver(child: MessageState(message: label)),
    ];
    switch (view) {
      case PersonalView.diary:
        final events = state.diary.values.toList()
          ..sort((a, b) {
            final date = b.day.compareTo(a.day);
            return date == 0 ? b.id.compareTo(a.id) : date;
          });
        return [
          const CineSliver(
            bottom: 10,
            child: GraphMessage(
              'Use Log viewing on a film or saved movie to add a diary entry.',
            ),
          ),
          if (events.isEmpty)
            ...empty('Your diary is empty.')
          else
            _rows(context, events.length, (_, index) {
              final event = events[index];
              return PersonalTile(
                title: event.title,
                subtitle: [
                  calendarDay(event.day),
                  if (event.rating != null) '${event.rating} stars',
                  if (event.review.isNotEmpty) event.review,
                  if (event.notes.isNotEmpty) event.notes,
                ].join(' · '),
                trailing: PopupMenuButton<int>(
                  tooltip: 'Viewing options',
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 0, child: Text('Edit viewing')),
                    PopupMenuItem(value: 1, child: Text('Delete viewing')),
                  ],
                  onSelected: (choice) async {
                    if (choice == 0) {
                      await showViewingEditor(
                        context,
                        library,
                        event.title,
                        original: event,
                      );
                    } else if (await _confirm(
                          context,
                          'Delete this viewing?',
                        ) &&
                        context.mounted) {
                      await personalWrite(
                        context,
                        library.removeViewing(event.id),
                      );
                    }
                  },
                ),
              );
            }),
        ];
      case PersonalView.progress:
        final progress = seasonProgress(state, library.now());
        final standalone = state.marked.values
            .where(
              (mark) => !progress.any(
                (row) => row.season.episodes.any(
                  (episode) => episode.key == mark.episode.key,
                ),
              ),
            )
            .toList();
        return [
          const CineSliver(
            bottom: 9,
            child: GraphMessage(
              'Track a series or save a season schedule to see progress and the next aired episode.',
            ),
          ),
          if (progress.isEmpty && standalone.isEmpty)
            ...empty('No episode progress yet.'),
          _rows(
            context,
            progress.length,
            (_, index) => _SeasonPanel(progress[index]),
          ),
          _rows(
            context,
            standalone.length,
            (_, index) => PersonalTile(
              title: standalone[index].episode,
              subtitle: 'Watched · ${calendarDay(standalone[index].day)}',
              trailing: EpisodeWatchAction(standalone[index].episode),
            ),
          ),
        ];
      case PersonalView.favorites:
        final favorites = state.favorites.values.toList().reversed.toList();
        return favorites.isEmpty
            ? empty('Favorite a title, person or franchise to find it here.')
            : [
                _rows(
                  context,
                  favorites.length,
                  (_, index) => PersonalTile(
                    title: favorites[index],
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite),
                      tooltip: 'Remove favorite',
                      onPressed: () => personalWrite(
                        context,
                        library.favorite(favorites[index]),
                      ),
                    ),
                  ),
                ),
              ];
      case PersonalView.lists:
        final lists = state.lists.values.toList();
        return [
          CineSliver(
            bottom: 13,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Create a list'),
                onPressed: () => editPersonalList(context, library),
              ),
            ),
          ),
          if (lists.isEmpty)
            ...empty(
              'Create a collection for the titles you want to keep together.',
            ),
          _rows(
            context,
            lists.length,
            (_, index) => _ListPanel(lists[index], library),
          ),
        ];
      case PersonalView.recent:
        final visits = state.history.values.toList();
        return [
          if (visits.isNotEmpty)
            CineSliver(
              bottom: 13,
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () async {
                    if (await _confirm(
                          context,
                          'Clear your exploration history?',
                        ) &&
                        context.mounted) {
                      await personalWrite(context, library.clearHistory());
                    }
                  },
                  child: const Text('Clear history'),
                ),
              ),
            ),
          if (visits.isEmpty)
            ...empty('Your recent destinations will appear here.'),
          _rows(
            context,
            visits.length,
            (_, index) => PersonalTile(
              title: visits[index].title,
              subtitle: calendarDay(visits[index].time.toLocal()),
            ),
          ),
        ];
      case PersonalView.data:
        return [const CineSliver(child: _DataPanel())];
    }
  }

  Widget _rows(BuildContext context, int count, IndexedWidgetBuilder builder) =>
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: CineLayout.gutterOf(context)),
        sliver: SliverList.builder(itemCount: count, itemBuilder: builder),
      );
}

class PersonalTile extends StatelessWidget {
  const PersonalTile({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });
  final PersonalTitle title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        isThreeLine: false,
        leading: SizedBox(
          width: 36,
          height: 50,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CineArt(
              path: title.image,
              kind: switch (title.route) {
                TitleRoute(ref: (kind: EntityKind.person, id: _)) =>
                  ArtworkKind.profile,
                EpisodeRoute() => ArtworkKind.still,
                _ => ArtworkKind.poster,
              },
            ),
          ),
        ),
        title: Text(title.name),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: () => openPersonalTitle(context, title),
      ),
    ),
  );
}

void openPersonalTitle(BuildContext context, PersonalTitle title) {
  final route = title.route;
  final summary = switch (route) {
    TitleRoute(ref: (kind: final kind, id: final id))
        when kind == EntityKind.movie || kind == EntityKind.tv =>
      Media(
        id: id,
        type: kind.name,
        title: title.name,
        posterPath: title.image,
        runtime: title.minutes,
        releaseDate: title.date,
        genres: title.genres,
        genreIds: title.genreIds,
      ),
    _ => null,
  };
  CineNavigation.of(context)
      .open(context, route, summary: summary, label: title.name);
}

class _ListPanel extends StatelessWidget {
  const _ListPanel(this.list, this.library);
  final PersonalCollection list;
  final PersonalLibrary library;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: GraphSection(
      key: PageStorageKey(list.id),
      title: '${list.name} · ${list.titles.length}',
      icon: Icons.collections_bookmark_outlined,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (list.description.isNotEmpty) GraphMessage(list.description),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => editPersonalList(context, library, list: list),
                child: const Text('Edit list'),
              ),
              TextButton(
                onPressed: () => _chooseSaved(context),
                child: const Text('Add from Watchlist'),
              ),
              TextButton(
                onPressed: () async {
                  if (await _confirm(context, 'Delete “${list.name}”?') &&
                      context.mounted) {
                    await personalWrite(context, library.removeList(list.id));
                  }
                },
                child: const Text('Delete list'),
              ),
            ],
          ),
          if (list.titles.isEmpty) const GraphMessage('This list is empty.'),
          _EntryWindow(
            length: list.titles.length,
            builder: (_, index) => PersonalTile(
              title: list.titles[index],
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Remove from list',
                onPressed: () => personalWrite(
                  context,
                  library.toggleListMember(list.id, list.titles[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _chooseSaved(BuildContext context) async {
    final watchlist = context.read<WatchlistProvider>();
    final existing = {for (final title in list.titles) title.key};
    final titles = watchlist.items
        .where(
          (item) =>
              MediaKind.parse(item.type) != null &&
              !existing.contains('/${item.type}/${item.id}'),
        )
        .map(PersonalTitle.saved)
        .toList();
    final chosen = await showDialog<PersonalTitle>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a saved title'),
        content: SizedBox(
          width: 450,
          height: 340,
          child: titles.isEmpty
              ? const Text('No more saved titles to add.')
              : ListView.builder(
                  itemCount: titles.length,
                  itemBuilder: (_, index) => ListTile(
                    title: Text(titles[index].name),
                    onTap: () => Navigator.pop(context, titles[index]),
                  ),
                ),
        ),
      ),
    );
    if (chosen != null && context.mounted) {
      await personalWrite(context, library.toggleListMember(list.id, chosen));
    }
  }
}

class _EntryWindow extends StatefulWidget {
  const _EntryWindow({required this.length, required this.builder});
  final int length;
  final IndexedWidgetBuilder builder;
  @override
  State<_EntryWindow> createState() => _EntryWindowState();
}

class _EntryWindowState extends State<_EntryWindow> {
  static const size = 12;
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final maximum = widget.length == 0 ? 0 : (widget.length - 1) ~/ size;
    final selected = page.clamp(0, maximum);
    final end = ((selected + 1) * size).clamp(0, widget.length);
    return Column(
      children: [
        for (var i = selected * size; i < end; i++) widget.builder(context, i),
        if (maximum > 0)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: selected == 0
                    ? null
                    : () => setState(() => page = selected - 1),
                child: const Text('Previous'),
              ),
              Text('${selected + 1} / ${maximum + 1}'),
              TextButton(
                onPressed: selected == maximum
                    ? null
                    : () => setState(() => page = selected + 1),
                child: const Text('Next'),
              ),
            ],
          ),
      ],
    );
  }
}

class _SeasonPanel extends StatelessWidget {
  const _SeasonPanel(this.entry);
  final SeasonProgress entry;
  @override
  Widget build(BuildContext context) {
    final season = entry.season;
    final series = (season.series.route as TitleRoute).ref.id;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GraphSection(
        key: PageStorageKey(season.key),
        title:
            '${season.series.name} · ${season.number == 0 ? 'Specials' : 'Season ${season.number}'} · ${entry.watched}/${season.episodes.length}',
        icon: Icons.tv_rounded,
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (entry.next case final next?)
              PersonalTile(
                title: next,
                subtitle: 'Next unwatched episode',
                trailing: EpisodeWatchAction(
                  next,
                  schedule: season,
                  compact: compact,
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                GraphLink(
                  'Open season',
                  SeasonRoute((seriesId: series, seasonNumber: season.number)),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _EntryWindow(
              length: season.episodes.length,
              builder: (_, index) {
                final episode = season.episodes[index];
                return PersonalTile(
                  title: episode,
                  subtitle: episode.date == null
                      ? 'Air date unavailable'
                      : calendarDay(episode.date!),
                  trailing: EpisodeWatchAction(
                    episode,
                    schedule: season,
                    compact: compact,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DataPanel extends StatefulWidget {
  const _DataPanel();
  @override
  State<_DataPanel> createState() => _DataPanelState();
}

class _DataPanelState extends State<_DataPanel> {
  bool _busy = false;
  String? _message;
  static const _maxBackup = 20 * 1024 * 1024;

  Future<void> _operate(String operation) async {
    final personal = context.read<PersonalLibrary>();
    final watchlist = context.read<WatchlistProvider>();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (operation == 'restore') {
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (file == null) return;
        final builder = BytesBuilder(copy: false);
        await for (final bytes in file.readAsByteStream()) {
          if (builder.length + bytes.length > _maxBackup) {
            throw const FormatException('The backup is larger than 20 MiB.');
          }
          builder.add(bytes);
        }
        final backup = LibraryBackup.fromJson(
          jsonDecode(utf8.decode(builder.takeBytes())),
        );
        if (!mounted ||
            !await _confirm(context, 'Merge this backup into your library?')) {
          return;
        }
        await watchlist.mergeBackup((
          items: backup.watchlist,
          achievements: backup.achievements,
        ));
        await personal.merge(backup.personal);
        _message = 'Backup restored.';
      } else {
        final backup = LibraryBackup(
          personal.state,
          watchlist.items,
          watchlist.unlockedAchievements,
        );
        final json = operation == 'json';
        final output = json
            ? const JsonEncoder.withIndent('  ').convert(backup.toJson())
            : backup.toCsv();
        final target = await FilePicker.saveFile(
          fileName:
              'cinevault-library-${calendarDay(personal.now())}.$operation',
          bytes: Uint8List.fromList(utf8.encode(output)),
          mimeType: json ? 'application/json' : 'text/csv',
        );
        if (target != null) _message = json ? 'Backup saved.' : 'CSV exported.';
      }
    } on FormatException catch (error) {
      _message = error.message;
    } catch (_) {
      _message = 'The file operation could not finish. You can retry safely.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = context.watch<WatchlistProvider>().initialized;
    return GraphPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Back up your library', style: cineDisplay(25)),
          const GraphMessage(
            'JSON keeps your complete library. Restore merges records and keeps existing entries when IDs match. Backup files contain your private notes and history.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: ready && !_busy ? () => _operate('json') : null,
                child: const Text('Save JSON backup'),
              ),
              OutlinedButton(
                onPressed: !_busy ? () => _operate('restore') : null,
                child: const Text('Restore JSON'),
              ),
              OutlinedButton(
                onPressed: ready && !_busy ? () => _operate('csv') : null,
                child: const Text('Export CSV'),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message case final message?) GraphMessage(message),
        ],
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;
