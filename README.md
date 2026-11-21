# CineVault — Movie & TV Discovery and Personal Watchlist Management

CineVault is a Flutter application for discovering movies and television shows, maintaining a personal watchlist, and reviewing collection statistics. It is not a streaming application.

## Stack

- Flutter and Dart
- Provider state management
- Hive local persistence
- TMDB REST API
- fl_chart visualizations
- Material 3 dark cinematic design

## Local setup

1. Copy `.env.example` to `.env`.
2. Add a TMDB API key to `TMDB_API_KEY`.
3. Run `flutter pub get`.
4. Run `flutter run`.

The API key is local-only and must never be committed.

## Implemented features

- TMDB-powered movie and TV discovery, search, details, similar titles, and recommendations.
- Debounced multi-media search with loading, empty, and error states.
- Hive-backed watchlist with duplicate-safe movie/TV identifiers, status filters, search, sorting, editing, personal ratings, notes, and confirmed deletion.
- Movie diary fields for watched date, personal review, notes, rating, and status, persisted in Hive.
- Statistics calculated from saved watchlist records using fl_chart, including watched-date activity and persisted achievements.
- Transparent recommendations based on saved titles and TMDB similar-title data, excluding existing watchlist items.
- TMDB discovery filters for content type, genre, year, minimum rating, and sort order.
- Responsive dark cinematic Material 3 interface with startup animation, hero carousel, shimmer placeholders, fade-in posters, Hero transitions, animated counters, and animated charts.

The TMDB key is required for live discovery. Because this is a client application, the key can be inspected by users of a built app; `.env` configuration is for local development convenience, not server-side secret protection.

Developed by **Sudheer Prajapati**  
GitHub: https://github.com/Sudheer21052005
