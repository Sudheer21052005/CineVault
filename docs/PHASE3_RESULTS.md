# Phase 3 cinema knowledge graph

Verification completed 28 November 2026 · `feature/ui-redesign` · Phase 2 comparison revision `2e9cac61ae2218fa0260a7217e6746f450a2eb67` · Phase 3 app revision `611f0eca24c0b2670d942951ac5de3837d653ef2`

CineVault now treats titles, credited people, franchises, studios, networks, genres, keywords, seasons and episodes as destinations. Relationships use typed routes, portrait and still artwork use TMDB size variants, and the Phase 2 navigation shell stays available on larger screens. The watchlist and developer credit keep their existing contracts.

## TMDB coverage

| Surface | Endpoints and behavior |
| --- | --- |
| Movie and series | The detail request appends `external_ids,keywords` in a single response. It renders original titles, overview, artwork, genre links, languages, countries, releases and production facts. TMDB collections, companies, networks, creators and seasons lead to their own destinations. [Detail appending](https://developer.themoviedb.org/docs/append-to-response) |
| Cast and crew | Movie credits and TV aggregate credits load when opened. Source job names, characters, departments, credit IDs and aggregate episode counts remain distinct under each person. Season aggregate credits and episode-specific cast and crew use their own responses. [TV aggregate credits](https://developer.themoviedb.org/reference/tv-series-aggregate-credits) · [Season aggregate credits](https://developer.themoviedb.org/reference/tv-season-aggregate-credits) |
| Person and filmography | Person details, external IDs, profile images and combined credits support biographies, aliases, known-for shelves ranked by credited title popularity, and a browsable filmography. Media, role, typed genre, year and vote-count filters combine. The URL carries filters and sorting for reload and sharing. Highest and lowest rating use titles with votes before unrated entries. [Combined credits](https://developer.themoviedb.org/reference/person-combined-credits) |
| Collections and associated catalogues | Collections read TMDB's explicit `parts` list. Companies, networks, keywords and typed genres use Discover with `with_companies`, `with_networks`, `with_keywords` and `with_genres` respectively. Companies and keywords offer separate movie and TV catalogues. [Collection details](https://developer.themoviedb.org/reference/collection-details) · [Movie Discover](https://developer.themoviedb.org/reference/discover-movie) · [TV Discover](https://developer.themoviedb.org/reference/discover-tv) |
| Seasons and episodes | Season numbers come from the show, including season zero when TMDB lists it. Season details supply episodes, stills, runtimes and votes. Episode detail exposes guest and crew links, stills and the typed parent routes. [Season details](https://developer.themoviedb.org/reference/tv-season-details) · [Episode details](https://developer.themoviedb.org/reference/tv-episode-details) |
| Availability and media | Watch providers are grouped by market and offer type with JustWatch attribution and the TMDB watch link. Trailers and teasers launch from their supplied video keys. Image galleries, reviews, alternate titles, translations, theatrical and home releases, and TV certifications have independent loading, empty, unavailable and failure states. [Watch providers](https://developer.themoviedb.org/reference/movie-watch-providers) |
| Universal search | Titles & people uses TMDB multi search. Dedicated Movies, TV Shows, People, Collections, Companies and Keywords scopes keep their own relevance and pagination. Supported external ID input routes through Find. Text search stays separate from faceted Discover. [Finding data](https://developer.themoviedb.org/docs/finding-data) · [Find by ID](https://developer.themoviedb.org/reference/find-by-id) |

## Request and navigation behavior

The primary title frame can reuse a poster-card summary immediately. Large credits, availability, videos, reviews, image galleries and related titles start only when opened. The transport coalesces duplicate calls and reuses its existing bounded memory and durable JSON caches. A cold direct entity route leaves the hidden Home branch unmounted. The router keeps a bounded set of recent mounted graph screens and stores page offsets separately from response data.

On Web, entity URLs use the app's existing hash strategy, for example `/#/tv/1396/season/1/episode/1`. The Android release registers the same paths under `cinevault://open/`. The in-app Back action returns to the originating route when a chain exists, and a direct filmography, season or episode has a typed parent.

## Verification and visual evidence

| Check | Result |
| --- | --- |
| Static analysis and automated regressions | Flutter analysis had zero findings, and all 32 tests passed. The graph tests cover appended request shape, lazy sections and direct routes, multiple roles and missing-versus-empty credits, scoped search and external IDs, sorted filmography, and phone episode navigation. |
| Web release | The JavaScript release built successfully and passed the Wasm compatibility dry run. Chromium exercised browser reload, in-app Back, browser Back/Forward, and restoration of the original filmography sort, vote filter and scroll position. |
| Android release | The APK built and installed on an isolated Pixel 9 emulator. Its Android 17 walkthrough used real entity links, the `cinevault://open/` scheme, and system Back. Flutter still reports upcoming support changes for Gradle, AGP and Kotlin. |
| Windows release | The Windows x64 release build passed. Native Windows runtime and Apple, Safari, Linux and TalkBack checks remain open. |

The Web visual matrix covers 13 destinations at 1440 × 900 and 390 × 844. The Pixel 9 release captures show the main chains and the episode-still gallery. The visual pass split desktop credits into two columns, narrowed the desktop biography measure, and added padding around the watch market label.

[Desktop Web gallery](screenshots/phase3/web-desktop-gallery.jpg) · [Phone Web gallery](screenshots/phase3/web-mobile-gallery.jpg) · [Pixel 9 gallery](screenshots/phase3/android-gallery.jpg)

| Live chain | Representative capture |
| --- | --- |
| Inception → Leonardo DiCaprio → highest-rated filmography with 1,000 minimum votes → Django Unchained → Quentin Tarantino | [Cast](screenshots/phase3/movie-cast-desktop.jpg) · [Profile](screenshots/phase3/person-mobile.jpg) · [Sorted filmography](screenshots/phase3/filmography-desktop.jpg) |
| Star Wars → Star Wars Collection → The Empire Strikes Back | [Collection and title in the desktop gallery](screenshots/phase3/web-desktop-gallery.jpg) |
| Breaking Bad → Season 1 → Pilot → Steven Michael Quezada, plus the separate Specials route | [Guest stars](screenshots/phase3/episode-guests-mobile.jpg) · [Episode stills](screenshots/phase3/episode-stills-mobile.jpg) |
| Regional availability and market grouping | [Watch availability](screenshots/phase3/regional-availability-desktop.jpg) |

The live Web walkthrough also followed Inception into its company, genre and keyword catalogues, and Breaking Bad into AMC's TV catalogue. It exercised the People, Collections, Companies and Keywords scopes and IMDb lookup. Direct live checks additionally resolved Breaking Bad by TVDB ID and returned different US and India watch offers.

## Performance

A controlled comparison uses the exact Phase 2 and Phase 3 instrumented release Web builds. The host runs Windows 11 and headless Chrome 158 with software rendering on an Intel Core i5-13450HX. Both revisions use 1440 × 900 at DPR 1, a 350 ms JSON fixture delay and a 120 ms artwork delay. The harness disables the browser HTTP cache and clears the test origin's catalogue storage before each Home document. It uses the same Home, search and visible-runtime markers on both releases. The visible runtime may arrive with the carried summary, so the title timing follows useful content and the count tracks requests initiated before that marker.

Thirty samples per revision. Timing rows use milliseconds.

| Measurement | Phase 2 p50 | Phase 2 p95 | Phase 3 p50 | Phase 3 p95 |
| --- | ---: | ---: | ---: | ---: |
| Document load → visible Home heading | 391.90 | 708.20 | 320.40 | 650.60 |
| Document load → first painted artwork | 1,102.90 | 1,447.70 | 1,035.65 | 1,409.90 |
| First artwork transfer | 136.30 | 163.48 | 135.19 | 153.52 |
| Artwork transferred before first paint (bytes) | 96,641 | 96,641 | 96,641 | 96,641 |
| JSON requests initiated before first artwork | 3 | 3 | 3 | 3 |
| Search input → visible result | 720.65 | 743.30 | 746.50 | 780.90 |
| Fresh title click → visible runtime | 112.60 | 154.70 | 94.40 | 130.20 |
| JSON requests initiated before fresh title marker | 3 | 3 | 2 | 2 |
| Cached title click → visible runtime | 84.80 | 112.50 | 81.25 | 111.30 |
| Repeated title detail JSON before cached marker | 0 | 0 | 0 | 0 |

The fresh title met the two-request budget and reached visible runtime 24.5 ms sooner at p95. A separate isolated search-to-title trace observed one title-scoped JSON request and zero eager related calls through 1.5 seconds after the visible-runtime marker. Cached title navigation stayed within the 300 ms target, with no repeated detail request before the marker. Search was 37.6 ms slower at p95 and stayed within its 1.2-second target.

A live Inception sample measured 1,698 bytes for the base title, 12,504 for similar titles and 13,683 for recommendations. Those three responses totaled 27,885 bytes under the earlier request pattern. The appended primary response is 2,309 bytes, a 92% reduction in the initial response set. The 205,932-byte credits response remains separate. Live payload sizes vary with title, locale and catalogue edits.

The live movie exploration sample measured 28.20 MiB of JavaScript heap at the initial title, 78.99 MiB at the director profile, and 41.10 MiB on return to the sorted filmography after requested garbage collection. These are one chain's browser JS heap samples. Native and GPU memory remain separate checks. The router retains up to five mounted nested route states, and the existing network and artwork cache budgets remain in place.

The live episode gallery initially returned zero stills with the default English filter. The documented include-language parameter returned 12 stills for the same pilot after adding language-neutral artwork. [TMDB episode images](https://developer.themoviedb.org/reference/tv-episode-images)

## Remaining limits

- Multi search covers titles and people. Use the dedicated scopes for collections, companies and keywords because TMDB provides independent result sets and relevance. The catalogue retains the existing adult-content default.
- Filmography filters reopen from the URL. Recent routes retain their live browsing state. Restoring an older paginated catalogue can reload result pages after its live view has been discarded. A browser reload reopens the requested entity within a new in-app exploration stack.
- Trailer playback hands off to YouTube or Vimeo, and market offers use the supplied TMDB watch page. The response contents and availability depend on TMDB and JustWatch.
- Hardware-backed renderer and native memory profiling, Windows runtime, Safari and Apple runtime, Linux runtime, and manual assistive-technology traversal remain open. Phase 2's sustained-scroll frame budget is still open.

## Reproduction

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --release --no-pub --no-web-resources-cdn --dart-define=CINEVAULT_PERF=true --output=build/phase3_web
flutter build apk --release --no-pub
flutter build windows --release --no-pub
python scripts/phase3_web_verification.py --chrome '<chrome.exe>' --build build/phase3_web --out build/phase3-proof/web
python scripts/phase3_web_verification.py --chrome '<chrome.exe>' --baseline '<Phase 2 Web release>' --build build/phase3_web --samples 30
python scripts/phase3_android_verification.py --device '<isolated emulator serial>' --out build/phase3-proof/android
```

Fixture runs substitute a dummy credential and report durations and aggregate counts. Live screenshots use the existing local ignored credential asset and public TMDB catalogue data.
