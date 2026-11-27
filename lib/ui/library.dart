import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../app/navigation_scope.dart';
import '../app/route_contract.dart';
import '../core/material.dart';
import '../models/media.dart';
import '../models/watchlist_item.dart';
import '../providers/watchlist_provider.dart';
import 'about.dart';
import 'artwork.dart';
import 'design_system.dart';

class LibraryTitleAction extends StatelessWidget {
  const LibraryTitleAction({
    required this.media,
    this.compact = false,
    super.key,
  });
  final Media media;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (ready, item) = context
        .select<WatchlistProvider, (bool, WatchlistItem?)>(
          (library) =>
              (library.initialized, library.find(media.id, media.type)),
        );
    final label = item == null ? 'Add to watchlist' : 'Remove from watchlist';
    final icon = item == null
        ? Icons.bookmark_add_outlined
        : Icons.bookmark_added_rounded;
    VoidCallback? action;
    if (ready) {
      action = item == null
          ? () => _save(context, media)
          : () => _remove(context, item);
    }
    return compact
        ? CineIconButton(
            label: label,
            icon: icon,
            onPressed: action,
            overlay: true,
          )
        : OutlinedButton.icon(
            onPressed: action,
            icon: Icon(icon, size: 19),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              backgroundColor: canvas.withValues(alpha: .77),
            ),
          );
  }
}

Future<void> _save(BuildContext context, Media media) async {
  final library = context.read<WatchlistProvider>();
  try {
    await library.save(media);
    if (context.mounted) _message(context, 'Added to your watchlist');
  } catch (_) {
    if (context.mounted) {
      _message(context, 'Unable to save this title. Please retry.');
    }
  }
}

Future<void> _remove(BuildContext context, WatchlistItem item) async {
  final library = context.read<WatchlistProvider>();
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove title?'),
      content: Text('Remove ${item.title} from your watchlist?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return;
  try {
    await library.remove(item);
    if (context.mounted) _message(context, 'Removed from your watchlist');
  } catch (_) {
    if (context.mounted) {
      _message(context, 'Unable to remove this title. Please retry.');
    }
  }
}

void _message(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

Future<void> _edit(BuildContext context, WatchlistItem item) async {
  if (CineLayout.widthOf(context) == CineWidth.compact) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _EditTitle(item: item),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 570),
          child: _EditTitle(item: item),
        ),
      ),
    );
  }
}

String _statusLabel(WatchStatus status) => switch (status) {
  WatchStatus.planToWatch => 'Plan to Watch',
  WatchStatus.watching => 'Watching',
  WatchStatus.watched => 'Watched',
};

Color _statusColor(WatchStatus status) => switch (status) {
  WatchStatus.planToWatch => blue,
  WatchStatus.watching => watching,
  WatchStatus.watched => watched,
};

class _EditTitle extends StatefulWidget {
  const _EditTitle({required this.item});
  final WatchlistItem item;
  @override
  State<_EditTitle> createState() => _EditTitleState();
}

class _EditTitleState extends State<_EditTitle> {
  late final _notes = TextEditingController(text: widget.item.notes);
  late final _review = TextEditingController(text: widget.item.review);
  late WatchStatus _status = widget.item.status;
  late double? _rating = widget.item.userRating;
  late DateTime? _date = widget.item.dateWatched;
  bool _saving = false;
  bool _failed = false;

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final earliest = DateTime(1900);
    final initial = _date;
    final date = await showDatePicker(
      context: context,
      firstDate: earliest,
      lastDate: now,
      initialDate:
          initial == null || initial.isBefore(earliest) || initial.isAfter(now)
          ? now
          : initial,
    );
    if (mounted && date != null) setState(() => _date = date);
  }

  Future<void> _saveChanges() async {
    final library = context.read<WatchlistProvider>();
    final edit = (
      status: _status,
      rating: _rating,
      notes: _notes.text.trim(),
      review: _review.text.trim(),
      watchedDate: _date,
    );
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await library.update(widget.item, edit);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      18,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Edit ${widget.item.title}', style: cineDisplay(29)),
        const SizedBox(height: 18),
        DropdownButtonFormField<WatchStatus>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Viewing status'),
          isExpanded: true,
          items: WatchStatus.values
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(_statusLabel(status)),
                ),
              )
              .toList(),
          onChanged: _saving
              ? null
              : (status) => setState(() {
                  if (status == null) return;
                  if (status == WatchStatus.watched && _status != status) {
                    _date ??= DateTime.now();
                  }
                  _status = status;
                }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<double?>(
          initialValue: _rating,
          decoration: const InputDecoration(labelText: 'Personal rating'),
          isExpanded: true,
          items: [
            const DropdownMenuItem<double?>(
              value: null,
              child: Text('Not rated'),
            ),
            for (final value in {
              ...List.generate(10, (index) => (index + 1) / 2),
              ?_rating,
            })
              DropdownMenuItem<double?>(
                value: value,
                child: Text('$value / 5'),
              ),
          ],
          onChanged: _saving
              ? null
              : (rating) => setState(() => _rating = rating),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _review,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Personal review'),
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _saving ? null : _chooseDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _date == null
                    ? 'Set date watched'
                    : MaterialLocalizations.of(context)
                          .formatMediumDate(_date!),
              ),
            ),
            if (_date != null)
              CineIconButton(
                label: 'Clear watched date',
                icon: Icons.close_rounded,
                onPressed: _saving ? null : () => setState(() => _date = null),
              ),
          ],
        ),
        if (_failed)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text(
              'Unable to save changes. Please retry.',
              style: TextStyle(color: danger),
            ),
          ),
        const SizedBox(height: 19),
        FilledButton(
          onPressed: _saving ? null : _saveChanges,
          child: Text(_saving ? 'Saving…' : 'Save changes'),
        ),
      ],
    ),
  );
}

class WatchlistPage extends StatefulWidget {
  const WatchlistPage({super.key});
  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

enum _LibrarySort { recent, title, rating }

class _WatchlistPageState extends State<WatchlistPage> {
  final _text = TextEditingController();
  WatchStatus? _status;
  _LibrarySort _sort = _LibrarySort.recent;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<WatchlistProvider>();
    final count = library.items.length;
    final query = _text.text.trim().toLowerCase();
    final items =
        library.items.where((item) {
          return (_status == null || item.status == _status) &&
              item.title.toLowerCase().contains(query);
        }).toList()..sort(
          (a, b) => switch (_sort) {
            _LibrarySort.recent => b.addedAt.compareTo(a.addedAt),
            _LibrarySort.title => a.title.toLowerCase().compareTo(
              b.title.toLowerCase(),
            ),
            _LibrarySort.rating => (b.userRating ?? 0).compareTo(
              a.userRating ?? 0,
            ),
          },
        );
    return CinePage(
      scrollKey: const PageStorageKey('watchlist'),
      slivers: [
        CineSliver(
          top: 24,
          bottom: 21,
          child: CineHeading(
            'Watchlist',
            subtitle: '$count saved ${count == 1 ? 'title' : 'titles'}',
            action: Wrap(
              spacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      CineNavigation.of(context).select(context, AppTab.stats),
                  icon: const Icon(Icons.bar_chart_rounded, size: 18),
                  label: const Text('Statistics'),
                ),
                if (CineLayout.widthOf(context) == CineWidth.compact)
                  CineIconButton(
                    label: 'About CineVault',
                    icon: Icons.info_outline,
                    onPressed: () => showCineAbout(context),
                  ),
              ],
            ),
          ),
        ),
        if (!library.initialized)
          CineSliver(child: _libraryState(library))
        else ...[
          CineSliver(
            bottom: 14,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 630),
              child: TextField(
                controller: _text,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search your collection',
                  prefixIcon: const Icon(Icons.search_rounded, color: blue),
                  suffixIcon: IconButton(
                    tooltip: 'Clear watchlist search',
                    onPressed: () => setState(_text.clear),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ),
          ),
          CineSliver(
            bottom: 22,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final status in [null, ...WatchStatus.values])
                  ChoiceChip(
                    label: Text(status == null ? 'All' : _statusLabel(status)),
                    selected: status == _status,
                    onSelected: (_) => setState(() => _status = status),
                  ),
                PopupMenuButton<_LibrarySort>(
                  tooltip: 'Sort watchlist',
                  onSelected: (value) => setState(() => _sort = value),
                  itemBuilder: (_) => [
                    for (final (sort, label) in const [
                      (_LibrarySort.recent, 'Recently added'),
                      (_LibrarySort.title, 'Title'),
                      (_LibrarySort.rating, 'Personal rating'),
                    ])
                      CheckedPopupMenuItem(
                        value: sort,
                        checked: sort == _sort,
                        child: Text(label),
                      ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(13),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort_rounded, size: 19),
                        SizedBox(width: 6),
                        Text('Sort'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            CineSliver(
              child: MessageState(
                icon: Icons.bookmarks_outlined,
                message: library.items.isEmpty
                    ? 'Your watchlist is empty. Save a movie or series to start building your library.'
                    : 'No saved titles match these filters.',
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: CineLayout.gutterOf(context),
              ),
              sliver: SliverList.builder(
                itemCount: items.length,
                itemBuilder: (_, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _LibraryRow(
                    key: ValueKey(items[index].key),
                    item: items[index],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.item, super.key});
  final WatchlistItem item;

  @override
  Widget build(BuildContext context) {
    final mobile = CineLayout.widthOf(context) == CineWidth.compact;
    final color = _statusColor(item.status);
    return Material(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: outline),
      ),
      color: surface,
      child: InkWell(
        onTap: () => CineNavigation.of(context).openTitle(
          context,
          Media(
            id: item.id,
            type: item.type,
            title: item.title,
            posterPath: item.posterPath,
            genres: item.genres,
            rating: item.rating,
          ),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                height: 75,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CineArt(path: item.posterPath),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          item.type == 'tv' ? 'TV show' : 'Movie',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        Text(
                          _statusLabel(item.status),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (item.userRating != null)
                          Text(
                            '${item.userRating} / 5',
                            style: const TextStyle(color: gold, fontSize: 12),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (mobile)
                PopupMenuButton<bool>(
                  tooltip: 'Options for ${item.title}',
                  onSelected: (edit) =>
                      edit ? _edit(context, item) : _remove(context, item),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: true, child: Text('Edit')),
                    PopupMenuItem(value: false, child: Text('Remove')),
                  ],
                )
              else ...[
                TextButton.icon(
                  onPressed: () => _edit(context, item),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
                IconButton(
                  onPressed: () => _remove(context, item),
                  tooltip: 'Remove ${item.title}',
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _libraryState(WatchlistProvider library) => library.openFailed
    ? MessageState(
        message: 'Unable to open your local watchlist.',
        onRetry: library.initialize,
      )
    : const CineSkeleton(height: 110);

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<WatchlistProvider>();
    return CinePage(
      scrollKey: const PageStorageKey('statistics'),
      slivers: [
        const CineSliver(
          top: 24,
          bottom: 23,
          child: CineHeading(
            'Statistics',
            subtitle: 'Your watchlist and viewing activity.',
          ),
        ),
        if (!library.initialized)
          CineSliver(child: _libraryState(library))
        else ...[
          CineSliver(bottom: 18, child: _Totals(library: library)),
          CineSliver(bottom: 18, child: _StatsPanels(library: library)),
          CineSliver(child: _AchievementPanel(library: library)),
        ],
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.library});
  final WatchlistProvider library;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final columns = box.maxWidth >= 680 ? 4 : 2;
      final width = (box.maxWidth - (columns - 1) * 11) / columns;
      return Wrap(
        spacing: 11,
        runSpacing: 11,
        children: [
          for (final (label, value, color, icon) in [
            (
              'Saved titles',
              library.items.length,
              blue,
              Icons.bookmarks_outlined,
            ),
            (
              'Movies',
              library.countType('movie'),
              gold,
              Icons.movie_creation_outlined,
            ),
            ('TV shows', library.countType('tv'), blue, Icons.tv_rounded),
            (
              'Watched',
              library.statusCounts[WatchStatus.watched] ?? 0,
              watched,
              Icons.check_circle_outline,
            ),
          ])
            SizedBox(
              width: width,
              child: CinePanel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 22, color: color),
                    const SizedBox(height: 11),
                    Text('$value', style: cineDisplay(35)),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _StatsPanels extends StatelessWidget {
  const _StatsPanels({required this.library});
  final WatchlistProvider library;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth >= 730
          ? (box.maxWidth - 15) / 2
          : box.maxWidth;
      return Wrap(
        spacing: 15,
        runSpacing: 15,
        children: [
          SizedBox(
            width: width,
            child: _Breakdown(counts: library.statusCounts),
          ),
          SizedBox(
            width: width,
            child: _Activity(library: library),
          ),
        ],
      );
    },
  );
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.counts});
  final Map<WatchStatus, int> counts;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (sum, item) => sum + item);
    return CinePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Viewing status', style: cineDisplay(25)),
          const SizedBox(height: 14),
          Center(
            child: SizedBox.square(
              dimension: 122,
              child: ExcludeSemantics(
                child: total == 0
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: outline, width: 16),
                        ),
                      )
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 43,
                          sections: [
                            for (final status in WatchStatus.values)
                              if ((counts[status] ?? 0) > 0)
                                PieChartSectionData(
                                  color: _statusColor(status),
                                  radius: 15,
                                  value: (counts[status] ?? 0).toDouble(),
                                  showTitle: false,
                                ),
                          ],
                        ),
                        duration: Duration.zero,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final status in WatchStatus.values)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 10, color: _statusColor(status)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_statusLabel(status))),
                  Text(
                    '${counts[status] ?? 0}',
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Activity extends StatelessWidget {
  const _Activity({required this.library});
  final WatchlistProvider library;

  @override
  Widget build(BuildContext context) {
    final events = library.activityByDay;
    final count = events.values.fold(0, (sum, item) => sum + item);
    final now = DateTime.now();
    final dates = List.generate(
      28,
      (index) => DateTime(now.year, now.month, now.day - 27 + index),
    );
    final locale = MaterialLocalizations.of(context);
    final monthCounts = <DateTime, int>{};
    for (final entry in events.entries) {
      final month = DateTime(entry.key.year, entry.key.month);
      monthCounts[month] = (monthCounts[month] ?? 0) + entry.value;
    }
    final peak = monthCounts.entries.fold<MapEntry<DateTime, int>?>(
      null,
      (best, current) =>
          best == null || current.value > best.value ? current : best,
    );
    return CinePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Viewing activity', style: cineDisplay(25)),
          const SizedBox(height: 8),
          Text(
            '$count titles with a recorded watch date',
            style: const TextStyle(color: muted),
          ),
          if (peak != null)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                'Most active month · ${locale.formatMonthYear(peak.key)} (${peak.value})',
              ),
            ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (_, box) {
              final columns = box.maxWidth >= 370 ? 14 : 7;
              final size = math.min(
                26.0,
                (box.maxWidth - (columns - 1) * 4) / columns,
              );
              return Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final date in dates)
                    Tooltip(
                      message:
                          '${locale.formatMediumDate(date)} · ${events[date] ?? 0} watched',
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: events[date] == null
                              ? elevated
                              : Color.lerp(
                                  blue,
                                  watched,
                                  ((events[date] ?? 0) / 3).clamp(0, 1),
                                ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'Last 28 days',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AchievementPanel extends StatelessWidget {
  const _AchievementPanel({required this.library});
  final WatchlistProvider library;

  @override
  Widget build(BuildContext context) {
    final unlocked = library.unlockedAchievements;
    return CinePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Achievements', style: cineDisplay(25)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (id, label) in const [
                ('first-watch', 'First Watch'),
                ('ten-watched', '10 Titles Watched'),
                ('genre-explorer', 'Genre Explorer'),
                ('movie-marathon', 'Movie Marathon'),
                ('tv-completion', 'TV Explorer'),
              ])
                Chip(
                  avatar: Icon(
                    unlocked.contains(id)
                        ? Icons.emoji_events_outlined
                        : Icons.lock_outline,
                    color: unlocked.contains(id) ? gold : muted,
                    size: 16,
                  ),
                  label: Text(label),
                ),
            ],
          ),
          if (library.achievementsNeedRetry)
            MessageState(
              message: 'Some achievements could not be updated.',
              onRetry: library.initialize,
            ),
        ],
      ),
    );
  }
}
