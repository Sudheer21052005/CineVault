import '../catalogue/entity_ref.dart';

class Media {
  const Media({
    required this.id,
    required this.type,
    required this.title,
    this.overview = '',
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.rating = 0,
    this.runtime,
    this.seasons,
    this.episodes,
    this.episodeRuntime,
    this.genres = const [],
    this.genreIds = const [],
    this.popularity = 0,
  });

  final int id;
  final String type;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final DateTime? releaseDate;
  final double rating;
  final int? runtime;
  final int? seasons;
  final int? episodes;
  final int? episodeRuntime;
  final List<String> genres;
  final List<int> genreIds;
  final double popularity;

  bool get isMovie => type == 'movie';
  String get year => releaseDate?.year.toString() ?? 'TBA';
  String get key => '$type-$id';
  EntityRef get ref =>
      (kind: (MediaKind.parse(type) ?? MediaKind.movie).entityKind, id: id);

  factory Media.fromJson(Map<String, dynamic> json, {String? forcedType}) {
    final type = forcedType ?? _string(json['media_type']) ?? 'movie';
    final title =
        _string(json[type == 'tv' ? 'name' : 'title']) ??
        _string(json['original_name']) ??
        _string(json['original_title']) ??
        'Untitled';
    final dateText =
        _string(json[type == 'tv' ? 'first_air_date' : 'release_date']) ?? '';
    final detailedGenres = _list(json['genres']).whereType<Map>();
    final genreNames = [
      ...detailedGenres.map((item) => item['name']).whereType<String>(),
      ..._list(json['genre_names']).whereType<String>(),
    ];
    return Media(
      id: _num(json['id'])?.toInt() ?? 0,
      type: type,
      title: title,
      overview: _string(json['overview']) ?? '',
      posterPath: _string(json['poster_path']),
      backdropPath: _string(json['backdrop_path']),
      releaseDate: DateTime.tryParse(dateText),
      rating: _num(json['vote_average'])?.toDouble() ?? 0,
      runtime: _num(json['runtime'])?.toInt(),
      seasons: _num(json['number_of_seasons'])?.toInt(),
      episodes: _num(json['number_of_episodes'])?.toInt(),
      episodeRuntime: _list(json['episode_run_time'])
          .whereType<num>()
          .firstOrNull
          ?.toInt(),
      genres: List.unmodifiable(genreNames),
      genreIds: List.unmodifiable({
        ..._list(json['genre_ids']).whereType<int>(),
        ...detailedGenres.map((item) => item['id']).whereType<int>(),
      }),
      popularity: _num(json['popularity'])?.toDouble() ?? 0,
    );
  }
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
num? _num(Object? value) => value is num && value.isFinite ? value : null;
List<Object?> _list(Object? value) => value is List ? value : const [];
