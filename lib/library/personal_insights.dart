import '../app/route_contract.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/entity_ref.dart';
import '../catalogue/knowledge_models.dart';
import '../models/media.dart';
import '../models/watchlist_item.dart';
import 'personal_models.dart';

typedef SeasonProgress = ({
  SeriesSeason season,
  int watched,
  int available,
  PersonalTitle? next,
});

List<SeasonProgress> seasonProgress(PersonalState state, DateTime now) {
  final day = calendarDay(now);
  final result = [
    for (final season in state.seasons.values)
      (
        season: season,
        watched: season.episodes
            .where((ep) => state.marked.containsKey(ep.key))
            .length,
        available: season.episodes
            .where(
              (ep) =>
                  ep.date == null || calendarDay(ep.date!).compareTo(day) <= 0,
            )
            .length,
        next: season.episodes
            .where(
              (ep) =>
                  !state.marked.containsKey(ep.key) &&
                  ep.date != null &&
                  calendarDay(ep.date!).compareTo(day) <= 0,
            )
            .firstOrNull,
      ),
  ];
  result.sort((a, b) {
    final series = a.season.series.name.compareTo(b.season.series.name);
    return series != 0 ? series : a.season.number.compareTo(b.season.number);
  });
  return result;
}

typedef TasteSource = ({PersonalTitle title, double weight, String reason});
typedef PersonalPick = ({Media media, List<TasteSource> sources});
typedef UpcomingPick = ({PersonalTitle title, String reason});

/// Memoizes only the current library projections across route and sliver mounts.
class PersonalInsights {
  PersonalInsights(this._discovery);

  final PersonalDiscovery _discovery;
  Object? _homeKey;
  Object? _statsKey;
  DateTime? _requestedAt;
  Future<(List<PersonalPick>, List<UpcomingPick>)>? _home;
  PersonalStats? _stats;

  Future<(List<PersonalPick>, List<UpcomingPick>)> home(
    PersonalState state,
    List<WatchlistItem> saved,
    DateTime now,
  ) {
    final key = (
      state.diary,
      state.favorites,
      state.hidden,
      state.seasons,
      state.marked,
      saved,
      calendarDay(now),
    );
    final age = now.difference(_requestedAt ?? now);
    if (_homeKey == key &&
        !age.isNegative &&
        age < const Duration(minutes: 5)) {
      return _home!;
    }
    _homeKey = key;
    _requestedAt = now;
    return _home = _loadHome(state, saved, now);
  }

  Future<(List<PersonalPick>, List<UpcomingPick>)> _loadHome(
    PersonalState state,
    List<WatchlistItem> saved,
    DateTime now,
  ) async {
    final seeds = PersonalDiscovery.sources(state, saved);
    final picks = _discovery.picks(state, saved, seeds);
    final upcoming = _discovery.upcoming(state, seeds, now);
    return (await picks, await upcoming);
  }

  PersonalStats statistics(PersonalState state, List<WatchlistItem> saved) {
    final key = (
      state.diary,
      state.marked,
      state.seasons,
      state.favorites,
      saved,
    );
    if (_statsKey == key) return _stats!;
    _statsKey = key;
    return _stats = PersonalStats(state, saved);
  }
}

class PersonalDiscovery {
  PersonalDiscovery(this.repo);
  final CatalogueRepository repo;

  static List<TasteSource> sources(
    PersonalState state,
    List<WatchlistItem> saved,
  ) {
    final seeds = <String, TasteSource>{};
    void add(PersonalTitle title, double weight, String reason) {
      if (state.hidden.containsKey(title.key)) return;
      final previous = seeds[title.key];
      seeds[title.key] = (
        title: previous?.title.enrichedWith(title) ?? title,
        weight: (previous?.weight ?? 0) + weight,
        reason: weight > (previous?.weight ?? 0)
            ? reason
            : previous?.reason ?? reason,
      );
    }

    for (final item in saved) {
      if (MediaKind.parse(item.type) == null) continue;
      final rating = item.userRating;
      if (rating != null && rating < 3) continue;
      add(
        PersonalTitle.saved(item),
        rating ?? (item.status == WatchStatus.watched ? 2.5 : 1),
        rating != null
            ? 'Rated ${item.userRating!.toStringAsFixed(1)} stars'
            : item.status == WatchStatus.watched
            ? 'Watched'
            : 'Saved',
      );
    }
    for (final viewing in state.diary.values) {
      final rating = viewing.rating;
      if (rating == null || rating >= 3) {
        add(viewing.title, rating ?? 2, 'Logged in your diary');
      }
    }
    for (final favorite in state.favorites.values) {
      add(favorite, 7, 'Favorited');
    }
    for (final progress in state.seasons.values) {
      final completed = progress.episodes
          .where((episode) => state.marked.containsKey(episode.key))
          .length;
      if (completed > 0) {
        add(progress.series, completed.clamp(1, 6) / 2, 'Tracked episodes');
      }
    }
    int rank(TasteSource a, TasteSource b) {
      final score = b.weight.compareTo(a.weight);
      return score == 0 ? a.title.key.compareTo(b.title.key) : score;
    }

    final top = <TasteSource>[];
    // Reserve one slot for a favorite person or franchise when the library has one.
    TasteSource? entity;
    for (final seed in seeds.values) {
      final route = seed.title.route;
      if (route is! TitleRoute) continue;
      switch (route.ref.kind) {
        case EntityKind.person || EntityKind.collection:
          if (entity == null || rank(seed, entity) < 0) entity = seed;
        case EntityKind.movie || EntityKind.tv:
          break;
        default:
          continue;
      }
      final index = top.indexWhere((other) => rank(seed, other) < 0);
      if (index >= 0) {
        top.insert(index, seed);
      } else if (top.length < 3) {
        top.add(seed);
      }
      if (top.length > 3) top.removeLast();
    }
    return [
      for (final seed
          in top.where((seed) => seed != entity).take(entity == null ? 3 : 2))
        seed,
      ?entity,
    ];
  }

  Future<List<PersonalPick>> picks(
    PersonalState state,
    List<WatchlistItem> saved,
    List<TasteSource> seeds,
  ) async {
    final excluded = {
      for (final item in saved) '/${item.type}/${item.id}',
      ...state.hidden.keys,
      ...state.favorites.keys,
      for (final event in state.diary.values) event.title.key,
      for (final season in state.seasons.values) season.series.key,
    };
    final results = await Future.wait(seeds.map(_related));
    final candidates =
        <String, ({Media media, double score, List<TasteSource> sources})>{};
    for (final (index, items) in results.indexed) {
      final seed = seeds[index];
      final seen = <String>{};
      for (final (position, media) in items.take(20).indexed) {
        final key = '/${media.type}/${media.id}';
        if (excluded.contains(key) || key == seed.title.key || !seen.add(key)) {
          continue;
        }
        final previous = candidates[key];
        candidates[key] = (
          media: media,
          score:
              (previous?.score ?? 0) +
              (1 + seed.weight.clamp(0, 20) / 20) / (1 + position / 6),
          sources: [...?previous?.sources, seed],
        );
      }
    }
    final ordered = candidates.values.toList()
      ..sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score == 0 ? a.media.key.compareTo(b.media.key) : score;
      });
    return [
      for (final candidate in ordered.take(12))
        (media: candidate.media, sources: candidate.sources),
    ];
  }

  Future<List<Media>> _related(TasteSource source) async {
    final ref = (source.title.route as TitleRoute).ref;
    try {
      return switch (ref.kind) {
        EntityKind.person => _popularPersonTitles(
          await repo.filmography(ref.id),
        ),
        EntityKind.collection => [
          for (final row in objects((await repo.entity(ref))['parts']))
            if (row['adult'] != true && (integer(row['id']) ?? 0) > 0)
              Media.fromJson(row, forcedType: 'movie'),
        ],
        _ => await repo.related(ref, recommended: true),
      };
    } catch (_) {
      return const [];
    }
  }

  List<Media> _popularPersonTitles(Json data) =>
      [
        for (final credit in readFilmography(data) ?? const <FilmCredit>[])
          credit.title,
      ]..sort((a, b) {
        final popularity = b.popularity.compareTo(a.popularity);
        if (popularity != 0) return popularity;
        final name = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        return name == 0 ? a.key.compareTo(b.key) : name;
      });

  Future<List<UpcomingPick>> upcoming(
    PersonalState state,
    List<TasteSource> seeds,
    DateTime now,
  ) async {
    final today = calendarDay(now);
    final people = state.favorites.values
        .where(
          (title) => switch (title.route) {
            TitleRoute(ref: (kind: EntityKind.person, id: _)) => true,
            _ => false,
          },
        )
        .firstOrNull;
    final genreSource = seeds
        .where(
          (seed) =>
              (seed.title.genreIds.isNotEmpty ||
                  seed.title.genres.isNotEmpty) &&
              ((seed.title.route as TitleRoute).ref.kind == EntityKind.movie),
        )
        .firstOrNull;
    final future = <UpcomingPick>[
      for (final season in state.seasons.values)
        for (final episode in season.episodes)
          if (episode.date != null &&
              calendarDay(episode.date!).compareTo(today) >= 0 &&
              now.difference(episode.date!).inDays >= -120 &&
              !state.marked.containsKey(episode.key))
            (title: episode, reason: 'Tracking ${season.series.name}'),
    ];
    if (people != null || genreSource != null) {
      try {
        final explicit = genreSource?.title.genreIds.firstOrNull;
        final name = genreSource?.title.genres.firstOrNull;
        final genre =
            explicit ??
            (people == null && name != null
                ? (await repo.genres(MediaKind.movie))
                      .where((entry) => entry.name == name)
                      .firstOrNull
                      ?.id
                : null);
        final movies = await repo.upcomingFor(
          person: people == null ? null : (people.route as TitleRoute).ref.id,
          genre: people == null ? genre : null,
        );
        future.addAll([
          for (final movie in movies)
            if (movie.releaseDate != null &&
                calendarDay(movie.releaseDate!).compareTo(today) >= 0)
              (
                title: PersonalTitle.media(movie),
                reason: people == null
                    ? 'Shares a genre with ${genreSource!.title.name}'
                    : 'Features your favorite ${people.name}',
              ),
        ]);
      } catch (_) {
        // Cached episode schedules are still useful on their own.
      }
    }
    future.removeWhere((item) => state.hidden.containsKey(item.title.key));
    future.sort((a, b) => a.title.date!.compareTo(b.title.date!));
    return future.take(12).toList();
  }
}

class PersonalStats {
  PersonalStats(PersonalState state, List<WatchlistItem> library) {
    final logged = <String>{};
    for (final event in state.diary.values) {
      logged.add('${event.title.key}:${calendarDay(event.day)}');
      _track(event.title, event.day);
    }
    for (final mark in state.marked.values) {
      episodes++;
      final ref = (mark.episode.route as EpisodeRoute).ref;
      final show = state
          .seasons['/tv/${ref.seriesId}/season/${ref.seasonNumber}']
          ?.series;
      _track(mark.episode, mark.day, show: show);
    }
    for (final item in library) {
      final day = item.dateWatched;
      if (day == null || MediaKind.parse(item.type) == null) continue;
      final title = PersonalTitle.saved(item);
      if (!logged.contains('${title.key}:${calendarDay(day)}')) {
        _track(title, day);
      }
    }
    for (final favorite in state.favorites.values) {
      if (favorite.route case TitleRoute(
        ref: (kind: EntityKind.person, id: final id),
      )) {
        people.putIfAbsent(id, () => (title: favorite, count: 0));
      }
    }
    diary = state.diary.length;
    repeats =
        diary -
        state.diary.values.map((event) => event.title.key).toSet().length;
    achievements = {
      if (repeats > 0) 'Encore',
      if (diary >= 25) '25 diary entries',
      if (episodes >= 10) 'Ten episodes logged',
      if (genres.length >= 5) 'Five genres explored',
      if (years.length >= 2) 'Two years in the diary',
    };
  }
  int minutes = 0, withRuntime = 0, episodes = 0, diary = 0, repeats = 0;
  final genres = <String, int>{},
      languages = <String, int>{},
      countries = <String, int>{};
  final years = <int, int>{};
  final days = <String, int>{};
  final people = <int, ({PersonalTitle title, int count})>{};
  late final Set<String> achievements;
  void _track(PersonalTitle title, DateTime date, {PersonalTitle? show}) {
    void add<K>(Map<K, int> target, K key) =>
        target.update(key, (count) => count + 1, ifAbsent: () => 1);
    add(years, date.year);
    add(days, calendarDay(date));
    if (title.minutes case final runtime? when runtime > 0) {
      minutes += runtime;
      withRuntime++;
    }
    for (final genre in {...title.genres, ...?show?.genres}) {
      add(genres, genre);
    }
    for (final country in {...title.countries, ...?show?.countries}) {
      add(countries, country);
    }
    if ((title.language ?? show?.language) case final language?) {
      add(languages, language);
    }
    for (final person in {
      for (final link in [...title.people, ...?show?.people]) link.ref: link,
    }.values) {
      people[person.ref.id] = (
        title: PersonalTitle(
          TitleRoute(person.ref),
          person.name,
          image: person.image,
        ),
        count: (people[person.ref.id]?.count ?? 0) + 1,
      );
    }
  }
}
