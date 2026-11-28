import '../catalogue/catalogue_repository.dart';
import '../catalogue/entity_ref.dart';
import '../catalogue/knowledge_models.dart';
import '../core/performance.dart';

enum AppTab {
  home('/', PerfArea.home),
  discover('/discover', PerfArea.discoverHub),
  movies('/discover/movies', PerfArea.movies),
  nowPlaying('/discover/now-playing', PerfArea.nowPlaying),
  tv('/discover/tv', PerfArea.tv),
  search('/search', PerfArea.search),
  watchlist('/library/watchlist', PerfArea.library),
  stats('/library/stats', PerfArea.stats);

  const AppTab(this.path, this.area);
  final String path;
  final PerfArea area;

  AppTab get destination => switch (this) {
    movies || tv || nowPlaying => discover,
    stats => watchlist,
    _ => this,
  };
}

sealed class CineRoute {
  const CineRoute();

  Uri get uri;
  PerfArea get area;
}

enum PersonalView { diary, progress, favorites, lists, recent, data }

class PersonalRoute extends CineRoute {
  const PersonalRoute([this.view = PersonalView.diary]);
  final PersonalView view;
  @override
  Uri get uri => Uri(path: '/library/personal/${view.name}');
  @override
  PerfArea get area => PerfArea.library;
}

class TabRoute extends CineRoute {
  const TabRoute(
    this.tab, {
    this.text = '',
    this.scope = SearchScope.all,
    this.discovery,
  });

  final AppTab tab;
  final String text;
  final SearchScope scope;
  final DiscoveryQuery? discovery;

  @override
  PerfArea get area => tab.area;

  @override
  Uri get uri {
    final filters = discovery;
    final params = <String, String>{
      if (filters != null) ...{
        'mode': 'discover',
        'kind': filters.kind.name,
        if (filters.genre != null) 'genre': '${filters.genre}',
        if (filters.year != null) 'year': '${filters.year}',
        if (filters.minimumRating != null) 'rating': '${filters.minimumRating}',
        if (filters.sort != CatalogueSort.popularity) 'sort': filters.sort.name,
      } else ...{
        if (text.isNotEmpty) 'q': text.trim(),
        if (scope != SearchScope.all) 'scope': scope.name,
      },
    };
    return Uri(path: tab.path, queryParameters: params.isEmpty ? null : params);
  }
}

class FeedRoute extends CineRoute {
  const FeedRoute(this.feed);
  final CatalogueFeed feed;

  @override
  Uri get uri => Uri(path: '/discover/feed/${feed.name}');
  @override
  PerfArea get area => PerfArea.browse;
}

class TitleRoute extends CineRoute {
  const TitleRoute(this.ref);
  final EntityRef ref;

  @override
  Uri get uri => Uri(path: '/${ref.kind.name}/${ref.id}');
  @override
  PerfArea get area => switch (ref.kind) {
    EntityKind.movie || EntityKind.tv => PerfArea.title,
    _ => PerfArea.entity,
  };
}

class FilmographyRoute extends CineRoute {
  const FilmographyRoute(
    this.personId, {
    this.filter = const FilmographyFilter(),
  });
  final int personId;
  final FilmographyFilter filter;

  @override
  Uri get uri {
    final genre = filter.genre;
    final params = <String, String>{
      if (filter.kind != null) 'kind': filter.kind!.name,
      if (filter.role != null) 'role': filter.role!,
      if (genre != null) 'genre': '${genre.kind.name}:${genre.id}',
      if (filter.year != null) 'year': '${filter.year}',
      if (filter.minimumVotes > 0) 'votes': '${filter.minimumVotes}',
      if (filter.sort != FilmSort.relevance) 'sort': filter.sort.name,
    };
    return Uri(
      path: '/person/$personId/filmography',
      queryParameters: params.isEmpty ? null : params,
    );
  }

  @override
  PerfArea get area => PerfArea.entity;
}

class GenreRoute extends CineRoute {
  const GenreRoute(this.ref);
  final GenreRef ref;

  @override
  Uri get uri => Uri(path: '/genre/${ref.kind.name}/${ref.id}');
  @override
  PerfArea get area => PerfArea.browse;
}

class SeasonRoute extends CineRoute {
  const SeasonRoute(this.ref);
  final SeasonRef ref;

  @override
  Uri get uri => Uri(path: '/tv/${ref.seriesId}/season/${ref.seasonNumber}');
  @override
  PerfArea get area => PerfArea.entity;
}

class EpisodeRoute extends CineRoute {
  const EpisodeRoute(this.ref);
  final EpisodeRef ref;

  @override
  Uri get uri => Uri(
    path:
        '/tv/${ref.seriesId}/season/${ref.seasonNumber}/episode/${ref.episodeNumber}',
  );
  @override
  PerfArea get area => PerfArea.entity;
}

class UnknownRoute extends CineRoute {
  const UnknownRoute(this.uri);

  @override
  final Uri uri;
  @override
  PerfArea get area => PerfArea.entity;
}

CineRoute parseCineRoute(Uri uri) {
  final params = uri.queryParameters;
  for (final tab in AppTab.values) {
    if (tab.path != uri.path) continue;
    if (tab != AppTab.search) return TabRoute(tab);
    final kind = MediaKind.parse(params['kind']) ?? MediaKind.movie;
    final sort =
        CatalogueSort.values
            .where((value) => value.name == params['sort'])
            .firstOrNull ??
        CatalogueSort.popularity;
    final rating = double.tryParse(params['rating'] ?? '');
    return TabRoute(
      tab,
      text: params['q']?.trim() ?? '',
      scope:
          SearchScope.values
              .where((value) => value.name == params['scope'])
              .firstOrNull ??
          SearchScope.all,
      discovery: params['mode'] == 'discover'
          ? (
              kind: kind,
              genre: _positive(params['genre']),
              year: _positive(params['year']),
              minimumRating: rating != null && rating >= 0 && rating <= 10
                  ? rating
                  : null,
              sort: sort,
            )
          : null,
    );
  }
  final segments = uri.pathSegments;
  switch (segments) {
    case ['library', 'personal']:
      return const PersonalRoute();
    case ['library', 'personal', final name]:
      final view = PersonalView.values
          .where((value) => value.name == name)
          .firstOrNull;
      if (view != null) return PersonalRoute(view);
    case ['discover', 'feed', final name]:
      final feed = CatalogueFeed.values
          .where((feed) => feed.name == name)
          .firstOrNull;
      if (feed != null) return FeedRoute(feed);
    case ['genre', final name, final id]:
      final kind = MediaKind.parse(name);
      final number = _positive(id);
      if (kind != null && number != null) {
        return GenreRoute((kind: kind, id: number));
      }
    case ['person', final id, 'filmography']:
      final number = _positive(id);
      if (number != null) {
        final genreParts = params['genre']?.split(':');
        final genreKind = MediaKind.parse(genreParts?.firstOrNull);
        final genreId = genreParts?.length == 2
            ? _positive(genreParts?.last)
            : null;
        final role = params['role']?.trim();
        final year = _positive(params['year']);
        return FilmographyRoute(
          number,
          filter: FilmographyFilter(
            kind: MediaKind.parse(params['kind']),
            role: role == null || role.isEmpty || role.length > 100
                ? null
                : role,
            genre: genreKind != null && genreId != null
                ? (kind: genreKind, id: genreId)
                : null,
            year: year != null && year >= 1000 && year <= 9999 ? year : null,
            minimumVotes: (_positive(params['votes']) ?? 0).clamp(
              0,
              1000000000,
            ),
            sort:
                FilmSort.values
                    .where((sort) => sort.name == params['sort'])
                    .firstOrNull ??
                FilmSort.relevance,
          ),
        );
      }
    case ['tv', final id, 'season', final season]:
      final ref = _season(id, season);
      if (ref != null) return SeasonRoute(ref);
    case ['tv', final id, 'season', final season, 'episode', final episode]:
      final ref = _season(id, season);
      final number = _positive(episode);
      if (ref != null && number != null) {
        return EpisodeRoute((
          seriesId: ref.seriesId,
          seasonNumber: ref.seasonNumber,
          episodeNumber: number,
        ));
      }
    case [final name, final id]:
      final kind = EntityKind.values
          .where((kind) => kind.name == name)
          .firstOrNull;
      final number = _positive(id);
      if (kind != null && number != null) {
        return TitleRoute((kind: kind, id: number));
      }
  }
  return UnknownRoute(Uri(path: uri.path));
}

int? _positive(String? text) {
  final value = int.tryParse(text ?? '');
  return value != null && value > 0 ? value : null;
}

SeasonRef? _season(String id, String season) {
  final series = _positive(id);
  final number = int.tryParse(season);
  return series != null && number != null && number >= 0
      ? (seriesId: series, seasonNumber: number)
      : null;
}
