enum EntityKind { movie, tv, person, collection, company, network, keyword }

enum MediaKind {
  movie,
  tv;

  EntityKind get entityKind => switch (this) {
    movie => EntityKind.movie,
    tv => EntityKind.tv,
  };

  static MediaKind? parse(String? value) => switch (value) {
    'movie' => movie,
    'tv' => tv,
    _ => null,
  };
}

typedef EntityRef = ({EntityKind kind, int id});
typedef GenreRef = ({MediaKind kind, int id});
typedef SeasonRef = ({int seriesId, int seasonNumber});
typedef EpisodeRef = ({int seriesId, int seasonNumber, int episodeNumber});
