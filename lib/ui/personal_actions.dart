import 'dart:async';

import 'package:provider/provider.dart';

import '../app/route_contract.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/entity_ref.dart';
import '../catalogue/knowledge_models.dart';
import '../core/material.dart';
import '../library/personal_library.dart';
import '../library/personal_models.dart';
import 'design_system.dart';

Future<void> personalWrite(BuildContext context, Future<void> task) async {
  try {
    await task;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The library change could not be saved.')),
      );
    }
  }
}

class PersonalActions extends StatefulWidget {
  const PersonalActions({
    required this.title,
    this.details,
    this.compact = false,
    super.key,
  });
  final PersonalTitle title;
  final TitleKnowledge? details;
  final bool compact;
  @override
  State<PersonalActions> createState() => _PersonalActionsState();
}

class _PersonalActionsState extends State<PersonalActions> {
  bool _recorded = false;
  bool _tracking = false;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<PersonalLibrary?>();
    if (library == null) return const SizedBox.shrink();
    final title = widget.title;
    if (!_recorded && library.ready) {
      _recorded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            TickerMode.valuesOf(context).enabled &&
            ModalRoute.of(context)?.isCurrent == true) {
          unawaited(library.recordVisit(title).catchError((Object _) {}));
        }
      });
    }
    if (!library.ready) return const SizedBox.shrink();
    final favored = library.state.favorites.containsKey(title.key);
    final hidden = library.state.hidden.containsKey(title.key);
    final route = title.route;
    if (widget.compact && route is TitleRoute) {
      final movie = route.ref.kind == EntityKind.movie;
      final tv = route.ref.kind == EntityKind.tv;
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _quick(
            favored ? 'Favorited' : 'Favorite',
            favored ? Icons.favorite : Icons.favorite_border,
            () => personalWrite(context, library.favorite(title)),
          ),
          _quick(
            'Add to list',
            Icons.playlist_add,
            () => personalListsDialog(context, library, title),
          ),
          if (movie)
            _quick(
              'Log viewing',
              Icons.edit_calendar_outlined,
              () => showViewingEditor(
                context,
                library,
                title,
                repo: context.read<CatalogueRepository>(),
              ),
            ),
          if (tv && widget.details != null)
            _quick(
              _tracking ? 'Loading schedule…' : 'Track series',
              Icons.playlist_play,
              _tracking ? null : () => _track(library, widget.details!),
            ),
          if (movie || tv)
            _quick(
              hidden ? 'Show in recommendations' : 'Hide from recommendations',
              hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              () =>
                  personalWrite(context, library.hide(title, hidden: !hidden)),
            ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 7,
      children: [
        OutlinedButton.icon(
          icon: CineStateIcon(
            favored ? Icons.favorite : Icons.favorite_border,
            size: 17,
          ),
          label: Text(favored ? 'Favorited' : 'Favorite'),
          onPressed: () => personalWrite(context, library.favorite(title)),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.playlist_add, size: 17),
          label: const Text('Add to list'),
          onPressed: () => personalListsDialog(context, library, title),
        ),
        if (route is TitleRoute && route.ref.kind == EntityKind.movie)
          FilledButton.tonalIcon(
            icon: const Icon(Icons.edit_calendar_outlined, size: 17),
            label: const Text('Log viewing'),
            onPressed: () => showViewingEditor(
              context,
              library,
              title,
              repo: context.read<CatalogueRepository>(),
            ),
          ),
        if (route is TitleRoute &&
            route.ref.kind == EntityKind.tv &&
            widget.details != null)
          FilledButton.tonalIcon(
            icon: const Icon(Icons.playlist_play, size: 19),
            label: Text(_tracking ? 'Loading schedule…' : 'Track series'),
            onPressed: _tracking
                ? null
                : () => _track(library, widget.details!),
          ),
        if (route is TitleRoute &&
            (route.ref.kind == EntityKind.movie ||
                route.ref.kind == EntityKind.tv))
          TextButton(
            onPressed: () =>
                personalWrite(context, library.hide(title, hidden: !hidden)),
            child: Text(
              hidden ? 'Show in recommendations' : 'Hide from recommendations',
            ),
          ),
      ],
    );
  }

  Widget _quick(String label, IconData icon, VoidCallback? action) =>
      IconButton(
        tooltip: label,
        onPressed: action,
        icon: CineStateIcon(icon, size: 19),
        style: IconButton.styleFrom(
          side: const BorderSide(color: outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      );

  Future<void> _track(PersonalLibrary library, TitleKnowledge detail) async {
    final repo = context.read<CatalogueRepository>();
    setState(() => _tracking = true);
    try {
      final ref = detail.media.ref;
      final existing = library.state.seasons.values
          .where((item) => item.series.key == widget.title.key)
          .toList();
      final listed =
          detail.seasons
              .map((row) => integer(row['season_number']))
              .whereType<int>()
              .where((number) => number > 0)
              .toList()
            ..sort();
      final ongoing = seasonProgressFor(library.state, existing);
      final upcoming = integer(
        object(detail.data['next_episode_to_air'])?['season_number'],
      );
      final progressNumber =
          ongoing ??
          (existing.isEmpty || listed.isEmpty
              ? listed.firstOrNull
              : listed
                        .where(
                          (number) =>
                              number >
                              existing
                                  .map((season) => season.number)
                                  .reduce((a, b) => a > b ? a : b),
                        )
                        .firstOrNull ??
                    listed.last);
      final numbers = {?progressNumber, ?upcoming};
      if (numbers.isEmpty) numbers.add(0);
      final seasons = await Future.wait([
        for (final number in numbers)
          repo.season((seriesId: ref.id, seasonNumber: number), refresh: true),
      ]);
      for (final (index, number) in numbers.indexed) {
        await library.saveSeason(
          seasonFromJson(widget.title, ref.id, number, seasons[index]),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Episode schedule saved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not refresh the episode schedule.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _tracking = false);
    }
  }
}

int? seasonProgressFor(PersonalState state, List<SeriesSeason> seasons) {
  final incomplete =
      seasons
          .where(
            (season) =>
                season.number != 0 &&
                season.episodes.any(
                  (episode) => !state.marked.containsKey(episode.key),
                ),
          )
          .map((season) => season.number)
          .toList()
        ..sort();
  return incomplete.firstOrNull;
}

SeriesSeason seasonFromJson(
  PersonalTitle series,
  int id,
  int number,
  Json data,
) {
  final episodes =
      [
        for (final row in objects(data['episodes']))
          if (integer(row['episode_number']) case final episode?
              when episode > 0)
            PersonalTitle.episode((
              seriesId: id,
              seasonNumber: number,
              episodeNumber: episode,
            ), row),
      ]..sort(
        (a, b) => (a.route as EpisodeRoute).ref.episodeNumber.compareTo(
          (b.route as EpisodeRoute).ref.episodeNumber,
        ),
      );
  return SeriesSeason(series, number, episodes);
}

class EpisodeWatchAction extends StatelessWidget {
  const EpisodeWatchAction(
    this.episode, {
    this.schedule,
    this.compact = false,
    super.key,
  });
  final PersonalTitle episode;
  final SeriesSeason? schedule;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final library = context.watch<PersonalLibrary?>();
    if (library == null || !library.ready) return const SizedBox.shrink();
    final watched = library.state.marked.containsKey(episode.key);
    final label = watched ? 'Mark unwatched' : 'Mark watched';
    final icon = watched ? Icons.check_circle : Icons.check_circle_outline;
    Future<void> update() async {
      final repo = context.read<CatalogueRepository>();
      await personalWrite(context, library.mark(episode, watched: !watched));
      if (watched) return;
      final ref = (episode.route as EpisodeRoute).ref;
      final key = '/tv/${ref.seriesId}/season/${ref.seasonNumber}';
      if (library.state.seasons.containsKey(key)) return;
      if (schedule case final value?) {
        await library.saveSeason(value).catchError((Object _) {});
        return;
      }
      try {
        final values = await Future.wait([
          repo.titleKnowledge((kind: EntityKind.tv, id: ref.seriesId)),
          repo.season((seriesId: ref.seriesId, seasonNumber: ref.seasonNumber)),
        ]);
        final title = values[0] as TitleKnowledge;
        await library.saveSeason(
          seasonFromJson(
            PersonalTitle.media(title.media, data: title.data),
            ref.seriesId,
            ref.seasonNumber,
            values[1] as Json,
          ),
        );
      } catch (_) {
        // The watch mark remains available when the catalogue is offline.
      }
    }

    if (compact) {
      return IconButton(
        tooltip: label,
        isSelected: watched,
        icon: Icon(icon),
        onPressed: update,
      );
    }
    return OutlinedButton.icon(
      icon: Icon(icon, size: 17),
      label: Text(label),
      onPressed: update,
    );
  }
}

Future<void> personalListsDialog(
  BuildContext context,
  PersonalLibrary library,
  PersonalTitle title,
) => showDialog<void>(
  context: context,
  builder: (context) => ListenableBuilder(
    listenable: library,
    builder: (context, _) => AlertDialog(
      title: Text('Lists for ${title.name}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final list in library.state.lists.values)
                CheckboxListTile(
                  value: list.titles.any((item) => item.key == title.key),
                  title: Text(list.name),
                  onChanged: (included) => personalWrite(
                    context,
                    library.toggleListMember(
                      list.id,
                      title,
                      included: included,
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () =>
                    editPersonalList(context, library, title: title),
                icon: const Icon(Icons.add),
                label: const Text('Create a list'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Done'),
        ),
      ],
    ),
  ),
);

Future<void> editPersonalList(
  BuildContext context,
  PersonalLibrary library, {
  PersonalCollection? list,
  PersonalTitle? title,
}) async {
  var name = list?.name ?? '';
  var description = list?.description ?? '';
  final origin = context;
  final form = GlobalKey<FormState>();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(list == null ? 'Create a list' : 'Edit list'),
      content: Form(
        key: form,
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'List name'),
                  onChanged: (value) => name = value,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a list name.'
                      : null,
                ),
                TextFormField(
                  initialValue: description,
                  maxLength: 400,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                  onChanged: (value) => description = value,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState?.validate() != true) return;
            Navigator.of(context).pop();
            final id = list?.id ?? library.newId();
            unawaited(
              personalWrite(
                origin,
                library.saveList(
                  id,
                  name.trim(),
                  description.trim(),
                  initial: title,
                ),
              ),
            );
          },
          child: const Text('Save list'),
        ),
      ],
    ),
  );
}

Future<void> showViewingEditor(
  BuildContext context,
  PersonalLibrary library,
  PersonalTitle title, {
  Viewing? original,
  CatalogueRepository? repo,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ViewingEditor(library, title, original, repo),
);

class _ViewingEditor extends StatefulWidget {
  const _ViewingEditor(this.library, this.title, this.original, this.repo);
  final PersonalLibrary library;
  final PersonalTitle title;
  final Viewing? original;
  final CatalogueRepository? repo;
  @override
  State<_ViewingEditor> createState() => _ViewingEditorState();
}

class _ViewingEditorState extends State<_ViewingEditor> {
  late DateTime _day = widget.original?.day ?? widget.library.now();
  late double? _rating = widget.original?.rating;
  late String _notes = widget.original?.notes ?? '';
  late String _review = widget.original?.review ?? '';
  bool _busy = false;
  bool _failed = false;

  Future<void> save() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final title = widget.title;
    final event = Viewing(
      widget.original?.id ?? widget.library.newId(),
      title,
      _day,
      rating: _rating,
      notes: _notes,
      review: _review,
    );
    try {
      await widget.library.saveViewing(event);
      if (mounted) Navigator.of(context).pop();
      final route = title.route;
      if (widget.original == null &&
          widget.repo != null &&
          route is TitleRoute) {
        unawaited(_enrich(event, route.ref));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _enrich(Viewing event, EntityRef ref) async {
    try {
      final data = await widget.repo!.section(ref, KnowledgeSection.credits);
      final people = [
        ...EntityLink.list(data['cast'], EntityKind.person).take(5),
        for (final row in objects(
          data['crew'],
        ).where((row) => row['job'] == 'Director'))
          ?EntityLink.read(row, EntityKind.person),
      ];
      await widget.library.enrichViewing(event.id, people);
    } catch (_) {
      // Credits are optional enrichment for an already saved offline event.
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.original == null ? 'Log ${widget.title.name}' : 'Edit viewing',
    ),
    content: SizedBox(
      width: 475,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 17),
              label: Text('Viewing date · ${calendarDay(_day)}'),
              onPressed: _busy
                  ? null
                  : () async {
                      final now = widget.library.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _day,
                        firstDate: DateTime(1900),
                        lastDate: _day.isAfter(now) ? _day : now,
                      );
                      if (picked != null && mounted) {
                        setState(() => _day = picked);
                      }
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<double>(
              initialValue: _rating,
              decoration: const InputDecoration(labelText: 'Personal rating'),
              items: [
                const DropdownMenuItem(child: Text('No rating')),
                for (var index = 1; index <= 10; index++)
                  DropdownMenuItem(
                    value: index / 2,
                    child: Text('${index / 2} stars'),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (rating) => setState(() => _rating = rating),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _notes,
              enabled: !_busy,
              maxLength: 4000,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Private notes'),
              onChanged: (value) => _notes = value,
            ),
            TextFormField(
              initialValue: _review,
              enabled: !_busy,
              maxLength: 12000,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Review'),
              onChanged: (value) => _review = value,
            ),
            if (_failed)
              const Text('The viewing could not be saved. Try again.'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : Navigator.of(context).pop,
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : save,
        child: Text(_busy ? 'Saving…' : 'Save viewing'),
      ),
    ],
  );
}
