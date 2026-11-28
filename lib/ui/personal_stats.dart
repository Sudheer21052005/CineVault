import 'package:provider/provider.dart';

import '../app/route_contract.dart';
import '../catalogue/entity_ref.dart';
import '../core/material.dart';
import '../library/personal_insights.dart';
import '../library/personal_library.dart';
import '../providers/watchlist_provider.dart';
import 'design_system.dart';
import 'graph_widgets.dart';
import 'media_sections.dart';
import 'personal_page.dart';

class PersonalStatsPanels extends StatelessWidget {
  const PersonalStatsPanels({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<PersonalLibrary?>();
    if (library == null || !library.ready) return const SizedBox.shrink();
    final saved = context.watch<WatchlistProvider>().items;
    final state = library.state;
    final stats = PersonalStats(state, saved);
    final people = stats.people.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final routeByGenre = <String, GenreRef>{};
    for (final match in state.diary.values) {
      final title = match.title;
      final route = title.route;
      final kind = route is TitleRoute
          ? MediaKind.parse(route.ref.kind.name)
          : null;
      if (kind == null || title.genres.length != title.genreIds.length) {
        continue;
      }
      for (final (index, name) in title.genres.indexed) {
        routeByGenre.putIfAbsent(
          name,
          () => (kind: kind, id: title.genreIds[index]),
        );
      }
    }
    final yearly = stats.years.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final activity = stats.days.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final total = stats.years.values.fold(0, (sum, n) => sum + n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GraphHeading('Personal viewing statistics'),
        GraphPanel(
          child: Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _total(
                'Viewing time',
                '${stats.minutes ~/ 60}h ${stats.minutes % 60}m',
                '${stats.withRuntime} with runtimes',
              ),
              _total(
                'Diary entries',
                '${stats.diary}',
                '${stats.repeats} repeat viewings',
              ),
              _total(
                'Episodes watched',
                '${stats.episodes}',
                '$total total viewing records',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GraphSection(
          title: 'Genres',
          icon: Icons.category_outlined,
          builder: (_) => _counts(
            stats.genres,
            (name, count) => routeByGenre.containsKey(name)
                ? GraphLink('$name · $count', GenreRoute(routeByGenre[name]!))
                : Chip(label: Text('$name · $count')),
          ),
        ),
        const SizedBox(height: 8),
        GraphSection(
          title: 'Languages and countries',
          icon: Icons.language_outlined,
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GraphHeading('Original languages'),
              _counts(stats.languages),
              const SizedBox(height: 13),
              const GraphHeading('Production countries'),
              _counts(stats.countries),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GraphSection(
          title: 'Favorite and most watched people',
          icon: Icons.people_outline,
          builder: (_) => Column(
            children: [
              if (people.isEmpty)
                const GraphMessage(
                  'Favorite people or log films with available credits.',
                ),
              for (final item in people.take(12))
                PersonalTile(
                  title: item.title,
                  subtitle: item.count == 0
                      ? 'Favorite'
                      : '${item.count} credited viewings',
                ),
              const Align(
                alignment: Alignment.centerLeft,
                child: GraphLink(
                  'All favorites',
                  PersonalRoute(PersonalView.favorites),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GraphSection(
          title: 'Yearly trends and activity',
          icon: Icons.analytics_outlined,
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (yearly.isEmpty)
                const GraphMessage(
                  'Dated viewings and episode marks will appear here.',
                ),
              for (final entry in yearly.take(20))
                GraphMessage('${entry.key} · ${entry.value} viewing records'),
              if (activity.isNotEmpty) ...[
                const GraphHeading('Recent activity'),
                for (final entry in activity.take(14))
                  GraphMessage('${entry.key} · ${entry.value}'),
              ],
              const GraphLink('Open diary', PersonalRoute()),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GraphSection(
          title: 'Personal milestones',
          icon: Icons.emoji_events_outlined,
          builder: (_) => stats.achievements.isEmpty
              ? const GraphMessage(
                  'Repeat a film or track episodes to reach your first milestone.',
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final award in stats.achievements)
                      Chip(label: Text(award)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _total(String label, String value, String sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: cineLabel()),
      Text(value, style: cineDisplay(30)),
      Text(sub),
    ],
  );

  Widget _counts(Map<String, int> map, [Widget Function(String, int)? tile]) {
    if (map.isEmpty) {
      return const GraphMessage('No metadata in your recorded viewings.');
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final entry in sorted.take(15))
          tile?.call(entry.key, entry.value) ??
              Chip(label: Text('${entry.key} · ${entry.value}')),
      ],
    );
  }
}
