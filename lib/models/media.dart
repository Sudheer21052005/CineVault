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
  final double popularity;

  bool get isMovie => type == 'movie';
  String get year => releaseDate?.year.toString() ?? 'TBA';
  String get key => '$type-$id';

  factory Media.fromJson(Map<String, dynamic> json, {String? forcedType}) {
    final type = forcedType ?? (json['media_type'] as String?) ?? 'movie';
    final title = (json[type == 'tv' ? 'name' : 'title'] as String?) ??
        (json['original_name'] as String?) ??
        (json['original_title'] as String?) ??
        'Untitled';
    final dateText =
        (json[type == 'tv' ? 'first_air_date' : 'release_date'] as String?) ?? '';
    final genreNames = (json['genres'] as List<dynamic>?)
            ?.map((item) => item is Map ? item['name'] as String? : null)
            .whereType<String>()
            .toList() ??
        (json['genre_names'] as List<dynamic>?)?.whereType<String>().toList() ??
        <String>[];
    return Media(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: type,
      title: title,
      overview: (json['overview'] as String?) ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: DateTime.tryParse(dateText),
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0,
      runtime: (json['runtime'] as num?)?.toInt(),
      seasons: (json['number_of_seasons'] as num?)?.toInt(),
      episodes: (json['number_of_episodes'] as num?)?.toInt(),
      episodeRuntime: (json['episode_run_time'] as List<dynamic>?)
          ?.whereType<num>()
          .firstOrNull
          ?.toInt(),
      genres: genreNames,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0,
    );
  }
}
