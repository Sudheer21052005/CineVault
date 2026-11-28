# Phase 4 personal cinema library and recommendations

28 November 2026 · `feature/ui-redesign` · Phase 3 comparison revision `b5d8010da983772d314b11b67b7e3fca1bc0aad4`

The personal library is reachable from Watchlist and via typed `/library/personal/:view` routes. Entries link back to movie, series, season, episode, person and franchise destinations. Existing Watchlist edits and original achievement IDs remain in their prior Hive boxes and adapter format.

## Implemented capabilities

| Area | Behavior |
| --- | --- |
| Diary | Every saved viewing has its own stable ID, local calendar date, optional half-star rating, review and notes. The same movie can be logged repeatedly on the same day. Existing Watchlist dates contribute to statistics when the same title and day have not already been logged. |
| TV tracking | A stored season includes its episode order, air dates and runtimes. Watched marks are local and reversible. Home uses the first known aired unwatched episode in tracked regular seasons, and retains the older Watching status for films and shows. Future episodes from stored schedules appear in Upcoming. |
| Lists and favorites | Custom lists support create, rename, describe, delete and membership editing. Titles can be added from catalogue pages or the saved offline Watchlist. Movies, shows, people, directors and TMDB collections can be favorited. The recent view keeps up to 100 locally explored destinations and can be cleared. |
| Discover and upcoming | Up to three seeds from saved and rated titles, diary viewings, tracked episodes, favorite people and favorite franchises use real cached TMDB recommendations, combined credits or collection membership. Each displayed pick names its source, excludes saved and previously logged titles and honors hidden items. Upcoming movies use a favorite person or a source movie's genre through Discover. [Movie Discover](https://developer.themoviedb.org/reference/discover-movie) · [Combined credits](https://developer.themoviedb.org/reference/person-combined-credits) |
| Statistics | Personal statistics add known-runtime viewing time, repeat counts, dated activity, yearly totals, genres, original languages, production countries, linked people and derived milestones. Film credits enrich the record after a diary save when TMDB is reachable. Missing runtimes stay out of the time total. |
| Backup and offline | The new `cinevault_personal_v1` box stores a validated versioned snapshot. JSON includes legacy records and achievement IDs, diary, marked episodes, cached schedules, favorites, lists, hidden titles and recent history. Merge preserves existing records on ID conflicts and allows safe retry across the legacy and personal stores. CSV quotes multiline values and protects formula-like cells. File selection and downloads use the platform picker. [File Picker](https://pub.dev/packages/file_picker) |

## Verification

| Check | Result |
| --- | --- |
| Flutter analysis and regression | Clean analysis and 36 passing tests. The new tests exercise offline Hive upgrade and restart, same-day repeats, field clearing, failed and concurrent writes, idempotent restore and source-backed recommendation filtering. |
| Live release Web | Chrome at 1440 × 900 and 390 × 844. Logged *Inception* twice with notes and a review, saved it to a custom list, favorited Christopher Nolan and the Star Wars Collection, marked *Breaking Bad*'s pilot and reached the next episode. Verified recent visits, statistics, recommendations and upcoming movies. |
| Web backup and offline | Both viewports downloaded JSON and CSV. With TMDB API and artwork hosts blocked, a reload retained the diary and next unwatched episode. A separate clean browser profile restored the JSON twice and exported identical records. |
| Live Android release | Installed the APK on an isolated Pixel 9 emulator. Used real TMDB title and episode pages, verified diary, favorite, next episode and backup controls, then force-stopped the app and reopened the diary and TV progress. |
| Release builds | Web (including the Wasm compatibility dry run), Android APK and Windows x64. Flutter reports future Gradle, AGP and Kotlin minimums for the existing Android toolchain. |
| Credential scan | Scanned the Phase 4 patches for the local TMDB key and credential-like assignments. The `.env` asset, QA user data and release bundles are excluded from Git. |

The 1,000-title fixture used offline legacy Hive records with ratings, dates and an existing achievement ID. A single regression run opened the boxes in 16.9 ms, committed an edit in 6.7 ms, computed recommendation seeds and personal statistics in 56.4 ms and merged the backup twice into a new store in 226.7 ms. These are local test timings for the specified operations.

## Matched Phase 3 and Phase 4 performance

The release-Web comparison uses headless Chrome and software rendering on the same Windows host at 1440 × 900 and DPR 1. It reuses the Phase 3 Home, search and visible-runtime markers, with 350 ms JSON fixtures and 120 ms artwork fixtures. The harness disables the browser HTTP cache and clears IndexedDB before each new Home run. The resulting cold Home timings use an empty personal library. The offline 1,000-title measurement above covers a populated library separately.

Thirty matched interactive samples per revision.

| Measurement | Phase 3 p50 / p95 | Phase 4 p50 / p95 |
| --- | ---: | ---: |
| Home heading (ms) | 407.9 / 488 | 384.3 / 460.6 |
| First painted artwork (ms) | 1,092.35 / 1,183.9 | 1,073.1 / 1,179.9 |
| First artwork transfer (ms) | 140.4 / 153.65 | 133.96 / 152.25 |
| Artwork before paint (bytes) | 96,641 / 96,641 | 96,641 / 96,641 |
| JSON requests before artwork | 3 / 3 | 3 / 3 |
| Search input to result (ms) | 742.9 / 767.3 | 745.85 / 770.4 |
| Fresh title click to visible runtime (ms) | 100.2 / 132.7 | 108 / 130.4 |
| JSON requests before fresh title marker | 2 / 2 | 2 / 2 |
| Cached title click to visible runtime (ms) | 88.9 / 112.7 | 90.85 / 127.5 |
| Repeated detail JSON before cached marker | 0 / 0 | 0 / 0 |

Home reached its heading 27.4 ms sooner at p95. Search was 3.1 ms slower at p95 and cached title navigation was 14.8 ms slower. The fresh title still initiated two JSON requests before the visible-runtime marker, and revisiting it made zero repeated detail requests.

Five separate 12-second Now Playing scroll samples per revision followed the interactive sequence in the same browser profile. For callback intervals, the table summarizes the per-run percentiles.

| Measurement | Phase 3 p50 / p95 | Phase 4 p50 / p95 |
| --- | ---: | ---: |
| Median animation callback interval (ms) | 16.7 / 16.7 | 16.7 / 16.7 |
| 95th-percentile animation callback interval (ms) | 50 / 50 | 33.4 / 49.9 |
| Animation callbacks above 20 ms (%) | 13.32 / 16.17 | 10.77 / 11.92 |
| Peak JS heap (MiB) | 200 / 226.48 | 202.16 / 220.06 |
| JS heap on return after requested garbage collection (MiB) | 123.74 / 151.26 | 121 / 148.17 |
| Artwork requests completed while scrolling | 160 / 160 | 160 / 160 |
| Catalogue pages requested while scrolling | 8 / 8 | 8 / 8 |
| Artwork transferred while scrolling (MiB) | 1.94 / 1.94 | 1.94 / 1.94 |

The median per-run share of animation callbacks above 20 ms fell from 13.32% to 10.77%. The scroll frame budget remains open. The two `main.dart.js` release files are 3,528,992 and 3,673,327 bytes, a 4.1% increase before transport compression. JavaScript heap and animation callback timing describe the headless renderer. Native and GPU use require separate measurements.

## Screenshots

- [Desktop walkthrough gallery](screenshots/phase4/desktop-overview.jpg)
- [Mobile Web walkthrough gallery](screenshots/phase4/mobile-overview.jpg)
- [Android emulator walkthrough gallery](screenshots/phase4/android-overview.jpg)
- [Personalized Home at desktop size](screenshots/phase4/personalized-home-desktop.jpg)
- [TV progress at phone size](screenshots/phase4/episode-progress-mobile.jpg)

## Reproduction

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --release --no-pub --no-web-resources-cdn --dart-define=CINEVAULT_PERF=true --output=build/phase4_web
flutter build apk --release --no-pub
flutter build windows --release --no-pub
python scripts/phase4_verification.py --chrome '<chrome.exe>' --build build/phase4_web --out build/phase4-proof/web
python scripts/phase4_verification.py --chrome '<chrome.exe>' --build build/phase4_web --out build/phase4-proof/mobile --mobile
python scripts/phase4_verification.py --chrome '<chrome.exe>' --baseline '<Phase 3 Web release>' --build build/phase4_web --samples 30 --scroll-samples 5 --scroll-seconds 12
adb -s '<isolated emulator serial>' install -r build/app/outputs/flutter-apk/app-release.apk
python scripts/phase4_android_verification.py --device '<isolated emulator serial>' --out build/phase4-proof/android
```

## Remaining limits

- Upcoming TV is based on stored season schedules. Use Track series to refresh the current and announced next season when online. Continue watching uses local episode completion and Watchlist status.
- The local history keeps at most 100 resolved destinations, and low-quality or missing TMDB data limits metadata coverage. Upcoming discovery and new recommendation responses require online TMDB access or fresh local catalogue cache entries.
- Viewing time includes known runtimes. The personal snapshot is rewritten per committed mutation, while Watchlist records are individually written. A restore merges the two stores in sequence, so a failed restore can safely be retried.
- Offline Web access requires a loadable application shell. The file picker round-trip was exercised on Web. Android used the local persistence and backup screen walkthrough. Windows was build-checked. Physical-device profiling, Windows runtime, Apple and Linux runtime, and Safari remain unverified.
