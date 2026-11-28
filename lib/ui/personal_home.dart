import 'package:provider/provider.dart';

import '../app/route_contract.dart';
import '../catalogue/catalogue_repository.dart';
import '../core/material.dart';
import '../library/personal_insights.dart';
import '../library/personal_library.dart';
import '../library/personal_models.dart';
import '../models/watchlist_item.dart';
import '../providers/watchlist_provider.dart';
import 'graph_widgets.dart';
import 'media_sections.dart';
import 'personal_page.dart';

class PersonalHome extends StatefulWidget {
  const PersonalHome({super.key});
  @override
  State<PersonalHome> createState() => _PersonalHomeState();
}

class _PersonalHomeState extends State<PersonalHome> {
  Object? _previous;
  Future<(List<PersonalPick>, List<UpcomingPick>)>? _request;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final library = context.watch<PersonalLibrary?>();
    final saved = context.watch<WatchlistProvider>().items;
    if (library == null || !library.ready) return;
    final state = library.state;
    final signal = (
      state.diary,
      state.favorites,
      state.hidden,
      state.seasons,
      state.marked,
      saved,
    );
    if (_previous == signal) return;
    _previous = signal;
    final discovery = PersonalDiscovery(context.read<CatalogueRepository>());
    final seeds = PersonalDiscovery.sources(state, saved);
    _request = _load(discovery, state, saved, seeds, library.now());
  }

  Future<(List<PersonalPick>, List<UpcomingPick>)> _load(
    PersonalDiscovery discovery,
    PersonalState state,
    List<WatchlistItem> saved,
    List<TasteSource> seeds,
    DateTime date,
  ) async {
    final picks = discovery.picks(state, saved, seeds);
    final upcoming = discovery.upcoming(state, seeds, date);
    return (await picks, await upcoming);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<PersonalLibrary?>();
    if (library == null || !library.ready) return const SizedBox.shrink();
    final saved = context.watch<WatchlistProvider>().items;
    final state = library.state;
    final next = <String, PersonalTitle>{};
    for (final entry in seasonProgress(state, library.now())) {
      final episode = entry.next;
      if (episode != null && entry.season.number != 0) {
        next.putIfAbsent(entry.season.series.key, () => episode);
      }
    }
    final continuing = [
      for (final entry in next.entries.take(4))
        (
          entry.value,
          'Next episode · ${state.seasons.values.firstWhere((row) => row.series.key == entry.key).series.name}',
        ),
      for (final item
          in saved
              .where(
                (item) =>
                    item.status == WatchStatus.watching &&
                    (item.type == 'movie' || item.type == 'tv') &&
                    !next.containsKey('/${item.type}/${item.id}'),
              )
              .take(4))
        (PersonalTitle.saved(item), 'Watching'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (continuing.isNotEmpty)
          _group('Continue watching', [
            for (final (title, reason) in continuing.take(4))
              PersonalTile(title: title, subtitle: reason),
            const Align(
              alignment: Alignment.centerLeft,
              child: GraphLink(
                'TV progress',
                PersonalRoute(PersonalView.progress),
              ),
            ),
          ]),
        FutureBuilder<(List<PersonalPick>, List<UpcomingPick>)>(
          future: _request,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                snapshot.data == null) {
              return const SizedBox.shrink();
            }
            final (picks, upcoming) = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (picks.isNotEmpty)
                  _group('Recommended for you', [
                    for (final pick in picks.take(6))
                      PersonalTile(
                        title: PersonalTitle.media(pick.media),
                        subtitle:
                            'Because of ${pick.sources.map((seed) => '${seed.title.name} (${seed.reason.toLowerCase()})').join(', ')}',
                      ),
                  ]),
                if (upcoming.isNotEmpty)
                  _group('Upcoming for you', [
                    for (final pick in upcoming.take(6))
                      PersonalTile(
                        title: pick.title,
                        subtitle:
                            '${calendarDay(pick.title.date!)} · ${pick.reason}',
                      ),
                  ]),
              ],
            );
          },
        ),
        if (state.history.isNotEmpty)
          _group('Recently explored', [
            for (final visit in state.history.values.take(4))
              PersonalTile(title: visit.title),
            const Align(
              alignment: Alignment.centerLeft,
              child: GraphLink(
                'See exploration history',
                PersonalRoute(PersonalView.recent),
              ),
            ),
          ]),
      ],
    );
  }

  Widget _group(String label, List<Widget> content) => Padding(
    padding: const EdgeInsets.only(bottom: 19),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [GraphHeading(label), ...content],
    ),
  );
}
