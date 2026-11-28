import '../app/route_contract.dart';
import '../catalogue/entity_ref.dart';
import '../catalogue/knowledge_models.dart';
import '../models/media.dart';
import '../models/watchlist_item.dart';

DateTime? personalDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String calendarDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class PersonalTitle {
  const PersonalTitle(
    this.route,
    this.name, {
    this.image,
    this.date,
    this.minutes,
    this.genres = const [],
    this.language,
    this.countries = const [],
    this.people = const [],
    this.genreIds = const [],
  });

  factory PersonalTitle.media(Media media, {Json? data}) => PersonalTitle(
    TitleRoute(media.ref),
    media.title,
    image: media.posterPath,
    date: media.releaseDate,
    minutes: media.runtime,
    genres: media.genres,
    genreIds: media.genreIds,
    language: text(data?['original_language']),
    countries: [
      ...names(data?['production_countries'], 'name'),
      if (objects(data?['production_countries']).isEmpty)
        ...strings(data?['origin_country']),
    ],
    people: EntityLink.list(data?['created_by'], EntityKind.person),
  );

  factory PersonalTitle.saved(WatchlistItem item) => PersonalTitle(
    TitleRoute((kind: MediaKind.parse(item.type)!.entityKind, id: item.id)),
    item.title,
    image: item.posterPath,
    genres: item.genres,
  );

  factory PersonalTitle.episode(EpisodeRef ref, Json data) => PersonalTitle(
    EpisodeRoute(ref),
    text(data['name']) ?? 'Episode ${ref.episodeNumber}',
    image: text(data['still_path']),
    date: personalDate(data['air_date']),
    minutes: integer(data['runtime']),
    people: EntityLink.list(data['guest_stars'], EntityKind.person),
  );

  final CineRoute route;
  final String name;
  final String? image;
  final DateTime? date;
  final int? minutes;
  final List<String> genres;
  final List<int> genreIds;
  final String? language;
  final List<String> countries;
  final List<EntityLink> people;
  String get key => route.uri.path;

  PersonalTitle enrichedWith(PersonalTitle incoming) => PersonalTitle(
    route,
    incoming.name,
    image: incoming.image ?? image,
    date: incoming.date ?? date,
    minutes: incoming.minutes ?? minutes,
    genres: incoming.genres.isEmpty ? genres : incoming.genres,
    genreIds: incoming.genreIds.isEmpty ? genreIds : incoming.genreIds,
    language: incoming.language ?? language,
    countries: incoming.countries.isEmpty ? countries : incoming.countries,
    people: {
      for (final p in [...people, ...incoming.people]) p.ref: p,
    }.values.toList(),
  );

  Json toJson() => {
    'route': key,
    'name': name,
    'image': image,
    'date': date == null ? null : calendarDay(date!),
    'minutes': minutes,
    'genres': genres,
    'genreIds': genreIds,
    'language': language,
    'countries': countries,
    'people': [
      for (final p in people)
        {'id': p.ref.id, 'name': p.name, 'profile_path': p.image},
    ],
  };

  factory PersonalTitle.fromJson(Json json) {
    final uri = Uri.tryParse(_required(json, 'route'));
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid library route.');
    }
    final route = parseCineRoute(uri);
    if (route is! TitleRoute &&
        route is! EpisodeRoute &&
        route is! SeasonRoute &&
        route is! GenreRoute) {
      throw const FormatException('Invalid library destination.');
    }
    return PersonalTitle(
      route,
      _required(json, 'name'),
      image: _artPath(json['image']),
      date: _date(json['date']),
      minutes: _minutes(json['minutes']),
      genres: strings(json['genres']),
      genreIds: json['genreIds'] is List
          ? (json['genreIds'] as List)
                .whereType<int>()
                .where((id) => id > 0)
                .toList()
          : const [],
      language: text(json['language']),
      countries: strings(json['countries']),
      people: EntityLink.list(json['people'], EntityKind.person),
    );
  }
}

class Viewing {
  const Viewing(
    this.id,
    this.title,
    this.day, {
    this.rating,
    this.review = '',
    this.notes = '',
  });
  final String id;
  final PersonalTitle title;
  final DateTime day;
  final double? rating;
  final String review;
  final String notes;

  Json toJson() => {
    'id': id,
    'title': title.toJson(),
    'day': calendarDay(day),
    'rating': rating,
    'review': review,
    'notes': notes,
  };

  factory Viewing.fromJson(Json json) {
    final title = PersonalTitle.fromJson(_map(json['title']));
    if (title.route is! TitleRoute ||
        (title.route as TitleRoute).ref.kind != EntityKind.movie) {
      throw const FormatException('Diary entries must be movies.');
    }
    return Viewing(
      _required(json, 'id'),
      title,
      _date(json['day']) ??
          (throw const FormatException('Missing viewing date.')),
      rating: _rating(json['rating']),
      review: _optional(json['review']),
      notes: _optional(json['notes']),
    );
  }
}

class PersonalCollection {
  const PersonalCollection(this.id, this.name, this.description, this.titles);
  final String id;
  final String name;
  final String description;
  final List<PersonalTitle> titles;
  Json toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'titles': titles.map((title) => title.toJson()).toList(),
  };
  factory PersonalCollection.fromJson(Json json) => PersonalCollection(
    _required(json, 'id'),
    _required(json, 'name'),
    _optional(json['description']),
    List.unmodifiable(_rows(json['titles']).map(PersonalTitle.fromJson)),
  );
}

class SeriesSeason {
  const SeriesSeason(this.series, this.number, this.episodes);
  final PersonalTitle series;
  final int number;
  final List<PersonalTitle> episodes;
  String get key => '${series.key}/season/$number';
  Json toJson() => {
    'series': series.toJson(),
    'number': number,
    'episodes': [for (final ep in episodes) ep.toJson()],
  };
  factory SeriesSeason.fromJson(Json json) {
    final series = PersonalTitle.fromJson(_map(json['series']));
    final number = integer(json['number']);
    if (series.route case TitleRoute(ref: (kind: EntityKind.tv, id: final id))
        when number != null && number >= 0) {
      final episodes = _rows(json['episodes'])
          .map(PersonalTitle.fromJson)
          .toList();
      if (episodes.every(
        (episode) => switch (episode.route) {
          EpisodeRoute(
            ref: (
              seriesId: final show,
              seasonNumber: final season,
              episodeNumber: _,
            ),
          ) =>
            show == id && season == number,
          _ => false,
        },
      )) {
        return SeriesSeason(series, number, List.unmodifiable(episodes));
      }
    }
    throw const FormatException('Invalid season snapshot.');
  }
}

typedef EpisodeMark = ({PersonalTitle episode, DateTime day});
typedef ExploreVisit = ({PersonalTitle title, DateTime time});

class PersonalState {
  PersonalState({
    Map<String, Viewing> diary = const {},
    Map<String, PersonalCollection> lists = const {},
    Map<String, PersonalTitle> favorites = const {},
    Map<String, PersonalTitle> hidden = const {},
    Map<String, EpisodeMark> marked = const {},
    Map<String, SeriesSeason> seasons = const {},
    Map<String, ExploreVisit> history = const {},
  }) : diary = Map.unmodifiable(diary),
       lists = Map.unmodifiable(lists),
       favorites = Map.unmodifiable(favorites),
       hidden = Map.unmodifiable(hidden),
       marked = Map.unmodifiable(marked),
       seasons = Map.unmodifiable(seasons),
       history = Map.unmodifiable(history);

  final Map<String, Viewing> diary;
  final Map<String, PersonalCollection> lists;
  final Map<String, PersonalTitle> favorites;
  final Map<String, PersonalTitle> hidden;
  final Map<String, EpisodeMark> marked;
  final Map<String, SeriesSeason> seasons;
  final Map<String, ExploreVisit> history;

  const PersonalState._(
    this.diary,
    this.lists,
    this.favorites,
    this.hidden,
    this.marked,
    this.seasons,
    this.history,
  );

  PersonalState copy({
    Map<String, Viewing>? diary,
    Map<String, PersonalCollection>? lists,
    Map<String, PersonalTitle>? favorites,
    Map<String, PersonalTitle>? hidden,
    Map<String, EpisodeMark>? marked,
    Map<String, SeriesSeason>? seasons,
    Map<String, ExploreVisit>? history,
  }) => PersonalState._(
    diary == null ? this.diary : Map.unmodifiable(diary),
    lists == null ? this.lists : Map.unmodifiable(lists),
    favorites == null ? this.favorites : Map.unmodifiable(favorites),
    hidden == null ? this.hidden : Map.unmodifiable(hidden),
    marked == null ? this.marked : Map.unmodifiable(marked),
    seasons == null ? this.seasons : Map.unmodifiable(seasons),
    history == null ? this.history : Map.unmodifiable(history),
  );

  Json toJson() => {
    'diary': [for (final entry in diary.values) entry.toJson()],
    'lists': [for (final entry in lists.values) entry.toJson()],
    'favorites': [for (final title in favorites.values) title.toJson()],
    'hidden': [for (final title in hidden.values) title.toJson()],
    'episodes': [
      for (final entry in marked.values)
        {'episode': entry.episode.toJson(), 'day': calendarDay(entry.day)},
    ],
    'seasons': [for (final entry in seasons.values) entry.toJson()],
    'history': [
      for (final entry in history.values)
        {
          'title': entry.title.toJson(),
          'time': entry.time.toUtc().toIso8601String(),
        },
    ],
  };

  factory PersonalState.fromJson(Json json) {
    final diary = _rows(json['diary']).map(Viewing.fromJson);
    final lists = _rows(json['lists']).map(PersonalCollection.fromJson);
    final favorites = _rows(json['favorites']).map(PersonalTitle.fromJson);
    final hidden = _rows(json['hidden']).map(PersonalTitle.fromJson);
    final seasons = _rows(json['seasons']).map(SeriesSeason.fromJson);
    final marked = <String, EpisodeMark>{};
    for (final value in _rows(json['episodes'])) {
      final episode = PersonalTitle.fromJson(_map(value['episode']));
      final day = _date(value['day']);
      if (episode.route is! EpisodeRoute || day == null) {
        throw const FormatException('Invalid episode mark.');
      }
      marked[episode.key] = (episode: episode, day: day);
    }
    final history = <String, ExploreVisit>{};
    for (final value in _rows(json['history'])) {
      final title = PersonalTitle.fromJson(_map(value['title']));
      final time = _date(value['time']);
      if (time == null) {
        throw const FormatException('Invalid exploration date.');
      }
      history[title.key] = (title: title, time: time);
    }
    return PersonalState(
      diary: {for (final entry in diary) entry.id: entry},
      lists: {for (final entry in lists) entry.id: entry},
      favorites: {for (final entry in favorites) entry.key: entry},
      hidden: {for (final entry in hidden) entry.key: entry},
      seasons: {for (final entry in seasons) entry.key: entry},
      marked: marked,
      history: trimHistory(history),
    );
  }

  static Map<String, ExploreVisit> trimHistory(
    Map<String, ExploreVisit> source,
  ) {
    final recent = source.values.toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    return {for (final entry in recent.take(100)) entry.title.key: entry};
  }
}

class LibraryBackup {
  const LibraryBackup(this.personal, this.watchlist, this.achievements);
  final PersonalState personal;
  final List<WatchlistItem> watchlist;
  final Set<String> achievements;

  Json toJson() => {
    'format': 'cinevault-library',
    'version': 1,
    'personal': personal.toJson(),
    'watchlist': [
      for (final item in watchlist)
        {
          'id': item.id,
          'type': item.type,
          'title': item.title,
          'poster': item.posterPath,
          'score': item.rating,
          'status': item.status.name,
          'rating': item.userRating,
          'notes': item.notes,
          'review': item.review,
          'genres': item.genres,
          'added': item.addedAt.toIso8601String(),
          'watched': item.dateWatched?.toIso8601String(),
        },
    ],
    'achievements': achievements.toList()..sort(),
  };

  factory LibraryBackup.fromJson(Object? input) {
    final json = _map(input);
    if (json['format'] != 'cinevault-library' || json['version'] != 1) {
      throw const FormatException('This backup format is unsupported.');
    }
    if (json['achievements'] is! List ||
        (json['achievements'] as List).any(
          (id) => id is! String || id.isEmpty || id.length > 128,
        )) {
      throw const FormatException('Invalid achievement IDs.');
    }
    return LibraryBackup(PersonalState.fromJson(_map(json['personal'])), [
      for (final item in _rows(json['watchlist'])) _watchlistItem(item),
    ], strings(json['achievements']).toSet());
  }

  static WatchlistItem _watchlistItem(Json json) {
    final id = integer(json['id']);
    final type = MediaKind.parse(text(json['type']));
    final status = WatchStatus.values
        .where((value) => value.name == json['status'])
        .firstOrNull;
    if (id == null || id <= 0 || type == null || status == null) {
      throw const FormatException('Invalid watchlist record.');
    }
    return WatchlistItem(
      id: id,
      type: type.name,
      title: _required(json, 'title'),
      posterPath: _artPath(json['poster']),
      rating: _rating(json['score'], maximum: 10) ?? 0,
      status: status,
      userRating: _rating(json['rating']),
      notes: _optional(json['notes']),
      review: _optional(json['review']),
      genres: strings(json['genres']),
      addedAt:
          _date(json['added']) ??
          (throw const FormatException('Missing added date.')),
      dateWatched: _date(json['watched']),
    );
  }

  String toCsv() {
    final rows = <List<Object?>>[
      [
        'Record',
        'Title',
        'Route',
        'Date',
        'Rating',
        'Notes',
        'Review',
        'Status or list',
      ],
      for (final item in watchlist)
        [
          'Watchlist',
          item.title,
          '/${item.type}/${item.id}',
          item.dateWatched == null ? null : calendarDay(item.dateWatched!),
          item.userRating,
          item.notes,
          item.review,
          item.status.name,
        ],
      for (final event in personal.diary.values)
        [
          'Viewing',
          event.title.name,
          event.title.key,
          calendarDay(event.day),
          event.rating,
          event.notes,
          event.review,
          null,
        ],
      for (final entry in personal.marked.values)
        [
          'Episode',
          entry.episode.name,
          entry.episode.key,
          calendarDay(entry.day),
          null,
          null,
          null,
          'watched',
        ],
      for (final title in personal.favorites.values)
        ['Favorite', title.name, title.key, null, null, null, null, null],
      for (final list in personal.lists.values)
        for (final title in list.titles)
          [
            'List member',
            title.name,
            title.key,
            null,
            null,
            list.description,
            null,
            list.name,
          ],
    ];
    String cell(Object? value) {
      var content = value?.toString() ?? '';
      if (value is String &&
          RegExp(r'^\s*[=+@-]|^[\t\r\n]').hasMatch(content)) {
        content = "'$content";
      }
      return '"${content.replaceAll('"', '""')}"';
    }

    return rows.map((row) => row.map(cell).join(',')).join('\r\n');
  }
}

Json _map(Object? value) =>
    object(value) ?? (throw const FormatException('Expected an object.'));
Iterable<Json> _rows(Object? value) {
  if (value is! List || value.length > 100000) {
    throw const FormatException('Invalid backup records.');
  }
  return value.map(_map);
}

String _required(Json json, String key) =>
    text(json[key]) ?? (throw const FormatException('Missing backup field.'));
String _optional(Object? value) => value == null
    ? ''
    : (value is String
          ? value
          : (throw const FormatException('Invalid text field.')));
DateTime? _date(Object? value) => value == null
    ? null
    : (personalDate(value) ?? (throw const FormatException('Invalid date.')));
String? _artPath(Object? value) =>
    value is String && RegExp(r'^/[\w.-]+$').hasMatch(value) ? value : null;
int? _minutes(Object? value) =>
    value is int && value > 0 && value <= 1440 ? value : null;
double? _rating(Object? value, {double maximum = 5}) {
  if (value == null) return null;
  if (value is num && value.isFinite && value >= 0 && value <= maximum) {
    return value.toDouble();
  }
  throw const FormatException('Invalid rating.');
}
