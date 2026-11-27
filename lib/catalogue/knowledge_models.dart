import '../models/media.dart';
import 'entity_ref.dart';

typedef Json = Map<String, dynamic>;

Json? object(Object? value) => value is Json ? value : null;
Iterable<Json> objects(Object? value) =>
    value is List ? value.whereType<Json>() : const [];
String? text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
int? integer(Object? value) => value is int ? value : null;
List<String> names(Object? value, String field) => [
  for (final item in objects(value)) ?text(item[field]),
];
List<String> strings(Object? value) => value is List
    ? value.whereType<String>().where((s) => s.trim().isNotEmpty).toList()
    : const [];

Uri? website(Object? value) {
  final uri = Uri.tryParse(text(value) ?? '');
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

class EntityLink {
  const EntityLink(this.ref, this.name, {this.image, this.caption});

  final EntityRef ref;
  final String name;
  final String? image;
  final String? caption;

  static EntityLink? read(Json? source, EntityKind kind) {
    if (source == null) return null;
    final id = integer(source['id']);
    final name = text(source['name']) ?? text(source['original_name']);
    if (id == null || id <= 0 || name == null) return null;
    return EntityLink(
      (kind: kind, id: id),
      name,
      image:
          text(source['profile_path']) ??
          text(source['poster_path']) ??
          text(source['logo_path']),
      caption: text(source['known_for_department']),
    );
  }

  static List<EntityLink> list(Object? source, EntityKind kind) => [
    for (final item in objects(source)) ?read(item, kind),
  ];
}

class SearchHit implements CatalogueItem {
  const SearchHit.title(Media title)
    : media = title,
      entity = null,
      season = null,
      episode = null;
  const SearchHit.entity(EntityLink link)
    : media = null,
      entity = link,
      season = null,
      episode = null;
  const SearchHit.season(EntityLink link, this.season)
    : media = null,
      entity = link,
      episode = null;
  const SearchHit.episode(EntityLink link, this.episode)
    : media = null,
      entity = link,
      season = null;

  final Media? media;
  final EntityLink? entity;
  final SeasonRef? season;
  final EpisodeRef? episode;

  @override
  String get key {
    if (season case (seriesId: final id, seasonNumber: final number)) {
      return 'tv-$id-season-$number';
    }
    if (episode case (
      seriesId: final id,
      seasonNumber: final season,
      episodeNumber: final number,
    )) {
      return 'tv-$id-season-$season-episode-$number';
    }
    return media?.key ?? '${entity!.ref.kind.name}-${entity!.ref.id}';
  }
}

typedef CreditRole = ({
  String? id,
  bool cast,
  String role,
  String? department,
  int? episodes,
});

List<CreditRole> _roles(Json credit, {required bool cast}) {
  // Aggregate TV credits preserve the individual credit IDs and episode totals.
  final entries = credit[cast ? 'roles' : 'jobs'];
  return [
    for (final entry in entries is List ? objects(entries) : [credit])
      (
        id: text(entry['credit_id']),
        cast: cast,
        role:
            text(entry[cast ? 'character' : 'job']) ?? (cast ? 'Cast' : 'Crew'),
        department: text(entry['department']) ?? text(credit['department']),
        episodes: integer(entry['episode_count']),
      ),
  ];
}

typedef PersonCredit = ({EntityLink person, List<CreditRole> roles});

List<PersonCredit>? readCredits(
  Object? cast,
  Object? crew, {
  bool crewFirst = false,
}) {
  if (cast is! List && crew is! List) return null;
  final people = <EntityRef, PersonCredit>{};
  void add(Object? entries, {required bool acting}) {
    for (final item in objects(entries)) {
      final person = EntityLink.read(item, EntityKind.person);
      if (person == null) continue;
      final entry = people.putIfAbsent(
        person.ref,
        () => (person: person, roles: []),
      );
      for (final role in _roles(item, cast: acting)) {
        if (!entry.roles.contains(role)) entry.roles.add(role);
      }
    }
  }

  if (crewFirst) add(crew, acting: false);
  add(cast, acting: true);
  if (!crewFirst) add(crew, acting: false);
  return List.unmodifiable(
    people.values.map(
      (entry) => (
        person: entry.person,
        roles: List<CreditRole>.unmodifiable(entry.roles),
      ),
    ),
  );
}

typedef FilmCredit = ({Media title, List<CreditRole> roles});

List<FilmCredit>? readFilmography(Json source) {
  if (source['cast'] is! List && source['crew'] is! List) return null;
  final credits = <EntityRef, FilmCredit>{};
  for (final acting in [true, false]) {
    for (final item in objects(source[acting ? 'cast' : 'crew'])) {
      final kind = MediaKind.parse(text(item['media_type']));
      if (kind == null || item['adult'] == true) continue;
      final title = Media.fromJson(item, forcedType: kind.name);
      if (title.id <= 0) continue;
      final entry = credits.putIfAbsent(
        title.ref,
        () => (title: title, roles: []),
      );
      for (final role in _roles(item, cast: acting)) {
        if (!entry.roles.contains(role)) entry.roles.add(role);
      }
    }
  }
  return List.unmodifiable(
    credits.values.map(
      (entry) => (
        title: entry.title,
        roles: List<CreditRole>.unmodifiable(entry.roles),
      ),
    ),
  );
}

enum FilmSort {
  popularity('Popularity'),
  topRated('Highest rated'),
  lowRated('Lowest rated'),
  newest('Newest first'),
  oldest('Oldest first'),
  alphabetical('Title A–Z');

  const FilmSort(this.label);
  final String label;
}

class FilmographyFilter {
  const FilmographyFilter({
    this.kind,
    this.role,
    this.genre,
    this.year,
    this.minimumVotes = 0,
    this.sort = FilmSort.popularity,
  });

  final MediaKind? kind;
  final String? role;
  final GenreRef? genre;
  final int? year;
  final int minimumVotes;
  final FilmSort sort;

  Iterable<FilmCredit> apply(List<FilmCredit> credits) {
    final filtered = credits.where((credit) {
      final title = credit.title;
      final scope = kind;
      final category = genre;
      return (scope == null || title.type == scope.name) &&
          (role == null ||
              credit.roles.any(
                (entry) => switch (role) {
                  'cast' => entry.cast,
                  'crew' => !entry.cast,
                  final job when job != null =>
                    !entry.cast && entry.role == job,
                  _ => true,
                },
              )) &&
          (category == null ||
              (title.type == category.kind.name &&
                  title.genreIds.contains(category.id))) &&
          (year == null || title.releaseDate?.year == year) &&
          title.voteCount >= minimumVotes;
    }).toList();
    int compareKnown<T extends Comparable<T>>(
      T? a,
      T? b, {
      bool descending = false,
    }) {
      if (a == null) return b == null ? 0 : 1;
      if (b == null) return -1;
      return descending ? b.compareTo(a) : a.compareTo(b);
    }

    int byName(Media a, Media b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase());
    double? rating(Media item) => item.voteCount > 0 ? item.rating : null;
    filtered.sort((left, right) {
      final a = left.title;
      final b = right.title;
      final result = switch (sort) {
        FilmSort.popularity => b.popularity.compareTo(a.popularity),
        FilmSort.topRated => compareKnown<num>(
          rating(a),
          rating(b),
          descending: true,
        ),
        FilmSort.lowRated => compareKnown<num>(rating(a), rating(b)),
        FilmSort.newest => compareKnown(
          a.releaseDate,
          b.releaseDate,
          descending: true,
        ),
        FilmSort.oldest => compareKnown(a.releaseDate, b.releaseDate),
        FilmSort.alphabetical => byName(a, b),
      };
      if (result != 0) return result;
      final names = byName(a, b);
      return names != 0 ? names : a.key.compareTo(b.key);
    });
    return filtered;
  }
}

class TitleKnowledge {
  TitleKnowledge(this.media, this.data);

  final Media media;
  final Json data;

  EntityLink? get collection => EntityLink.read(
    object(data['belongs_to_collection']),
    EntityKind.collection,
  );
  List<EntityLink> get companies =>
      EntityLink.list(data['production_companies'], EntityKind.company);
  List<EntityLink> get networks =>
      EntityLink.list(data['networks'], EntityKind.network);
  List<EntityLink> get creators =>
      EntityLink.list(data['created_by'], EntityKind.person);
  List<EntityLink>? get keywords {
    final container = object(data['keywords']);
    final list = container?[media.isMovie ? 'keywords' : 'results'];
    return list is List ? EntityLink.list(list, EntityKind.keyword) : null;
  }

  Iterable<Json> get seasons => objects(data['seasons']);
  Json? get externalIds => object(data['external_ids']);
}

typedef ExternalReference = ({String source, String value});

ExternalReference? externalReference(String term) {
  final input = term.trim();
  final external = RegExp(r'^(tt|nm)\d+$', caseSensitive: false);
  if (external.hasMatch(input)) {
    return (source: 'imdb_id', value: input.toLowerCase());
  }
  final colon = input.indexOf(':');
  if (colon <= 0) return null;
  final source = input.substring(0, colon).toLowerCase();
  final value = input.substring(colon + 1).trim();
  final valid = switch (source) {
    'imdb' => external.hasMatch(value),
    'tvdb' || 'tvrage' => RegExp(r'^[1-9]\d*$').hasMatch(value),
    'wikidata' => RegExp(r'^Q[1-9]\d*$', caseSensitive: false).hasMatch(value),
    'facebook' ||
    'instagram' ||
    'twitter' => RegExp(r'^[a-zA-Z0-9_.]{1,100}$').hasMatch(value),
    _ => false,
  };
  if (!valid) return null;
  return (
    source: '${source}_id',
    value: switch (source) {
      'imdb' => value.toLowerCase(),
      'wikidata' => value.toUpperCase(),
      _ => value,
    },
  );
}
