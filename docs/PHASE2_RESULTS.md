# Phase 2 responsive browsing and renderer results

27 November 2026 · `feature/ui-redesign` · Phase 1 comparison revision `fe91fd6b9fb83cf03cdfa284de99aa979be29c1e` · Phase 2 app revision `05c8c742b111e70be0aea09180ae2aeaa4385cd4`

The redesigned CineVault uses a navy canvas, blue navigation and actions, and warm gold catalogue scores. Manrope handles interface text and Space Grotesk handles titles. The original emblem and Sudheer Prajapati developer credit are available in the application. The shared theme covers focus, hover, selection, reduced motion, empty states, error recovery, and skeletons. Font licenses are stored with the [typefaces](../assets/fonts/).

## Screens and interaction

- Home uses a live, pausable feature carousel and lazy TMDB shelves. The artwork switches between landscape and portrait compositions. Pointer, touch, and keyboard inputs can move through the feature. Browse shelves retain their own scroll offsets.
- The 1024 px layout fixes a labeled sidebar beside the route viewport. Tablet widths use an icon rail with accessible labels. Phones use four primary destinations and direct links to Movies, TV Shows, Now Playing, and Statistics within Discover or Library. The search control is global, and Ctrl+K or Cmd+K opens and focuses the search field.
- Discover, Movies, TV Shows, and Now Playing use the same responsive grid and rail components. Search has direct All, Movies, and TV Shows scopes and a separate Discovery filters surface. The shared paged controller retains query semantics, cancels stale UI commits, and provides fresh retry at the end of a feed.
- Title detail renders provisional summary artwork and then loads full metadata. Overview, facts, genres, similar titles, and recommendations are reusable sections. Genre names with IDs link to their catalogue. Existing title and reserved Phase 3 entity routes remain typed.
- Watchlist has explicit detail, edit, and removal actions. Statistics summarizes totals, viewing status, dated activity, and persisted achievements. The existing watchlist adapter and data contract remain compatible, with metadata caching in a distinct Hive box.

## Visual QA

Phase 1 reference captures came from the previous instrumented Web release. Phase 2 screenshots use live TMDB content on an isolated browser origin and Pixel 9 emulator app installation. The watchlist captures use QA entries added from the catalogue. Home, Discover, Movies, TV Shows, Now Playing, Search, title detail, Watchlist, and Statistics were visually reviewed.

### Representative captures

| Surface | Phase 1 | Phase 2 |
| --- | --- | --- |
| Desktop Home | [1440 px Home](screenshots/phase2/before-home-1440.jpg) | [1440 px Home](screenshots/phase2/after-home-1440.jpg) |
| Phone Home | [390 px Home](screenshots/phase2/before-home-390.jpg) | [390 px Home](screenshots/phase2/after-home-390.jpg) |
| Desktop title detail | [1440 px detail](screenshots/phase2/before-detail-1440.jpg) | [1440 px detail](screenshots/phase2/after-detail-1440.jpg) |
| Tablet rail | — | [768 px Home](screenshots/phase2/after-home-768.jpg) |
| Pixel 9 emulator | — | [Android Home](screenshots/phase2/android-home.jpg) · [Android title detail](screenshots/phase2/android-detail.jpg) |

[Desktop Web gallery](screenshots/phase2/web-desktop-gallery.jpg) · [Mobile Web gallery](screenshots/phase2/web-mobile-gallery.jpg) · [Android gallery](screenshots/phase2/android-gallery.jpg) · [Eight-width breakpoint gallery](screenshots/phase2/breakpoints-gallery.jpg)

The visual passes identified uneven poster metadata baselines, an orphaned quick link at 390 px, and a truncated featured title at the narrowest tablet width. The updated layout reserves two title lines per poster, tightens phone quick-link padding, and chooses the stacked feature composition based on content width. The smallest phone layout also constrained the carousel counter at 200% text so the previous, next, and pause controls fit. Posters replace their fitted placeholder when ready and backdrops retain a short reveal, limiting repeated animations during dense-grid scrolling.

## Renderer and caching

- TMDB configuration supplies secure CDN sizes, with known-size fallbacks while configuration loads. Requests choose the next supported variant for logical size and device pixel ratio, capped at 2×. Native decoding is bucketed by the same width. The catalogue image cache is budgeted at 180 entries and 64 MiB of decoded pixels, subject to Flutter's live-image behavior. Feature prefetch covers one adjacent image.
- Lazy sliver grids and lists keep the widget tree bounded by the viewport. Scroll and route telemetry report fixed, redacted fields. The About screen identifies TMDB as the source. [TMDB image configuration](https://developer.themoviedb.org/docs/image-basics)
- The persistent catalogue box has a 350-entry cap and logical response-byte limits of 15 MiB Web and 40 MiB native. Expiry and size eviction run separately from the watchlist. Typed search text, ad-hoc discovery queries, and credentials stay outside that box. A failed cache read falls back to TMDB. Expired metadata requires a fresh request.

## Verification

| Check | Result |
| --- | --- |
| Flutter analysis | `flutter analyze --no-pub` passed with zero findings. |
| Regression suite | All 27 tests passed. Coverage includes the 21 Phase 1 tests, layout and artwork policy, bounded persistent storage and cache identity, keyboard search, all eight breakpoint shells, and 200% text on all nine views at 320 × 740. |
| Web release | Release JavaScript built and the Wasm compatibility dry run passed. The phone fixture smoke verifies Now Playing Back, search → title detail → save, browser Back/Forward, canonical title links, a reload of the saved watchlist, and separate TV search and discovery endpoints. |
| Web visual matrix | Nine live screens captured at 1440 × 900 and 390 × 844. The Home layout was also checked at 320, 390, 599, 600, 768, 1023, 1024 and 1440 CSS px. |
| Android release | The release APK built and installed on an isolated Pixel 9 emulator running Android 17 at 1080 × 2424 physical pixels. The walkthrough exercised live TMDB browsing, title search, the watchlist save, Android system Back, Watchlist and Statistics. Flutter reports upcoming Gradle, AGP and Kotlin support changes. |
| Windows release | The Windows x64 release build passed. Native Windows runtime and graphics profiling remain open. |

## Comparable measurement protocol

Both sides use release JavaScript builds with local CanvasKit on Windows 11, Intel Core i5-13450HX, Flutter 3.50.1, Dart 3.14.0, and Chrome 158.0.8127.37. Headless Chrome uses software rendering at a 1440 × 900 CSS viewport and DPR 1. The fixture clears the isolated test origin's IndexedDB before each Home startup sample and sustained scroll, with browser HTTP caching disabled. Cold here means a fresh document and empty catalogue storage within a reused browser process. TMDB JSON has a fixed 350 ms delay, and deterministic JPEG responses use a fixed 120 ms delay. The shared shell marker is the visible “Trending this week” heading, and a pixel probe detects the first painted fixture artwork. Cached navigation measures from selecting the same title a second time to its visible 148-minute runtime.

Each sustained run starts a fresh Chrome process and uses scripted wheel input over eight available pages and 160 fixture titles. The frame metric is the time between Chromium animation callbacks in a headless 60 Hz environment. The JS heap is sampled during the scroll, after returning to Home, and after requesting garbage collection there. It excludes native and GPU allocations. These values use a separate protocol from the Phase 1 report's single-wheel and first-card measurements.

```powershell
flutter build web --release --no-pub --no-web-resources-cdn --dart-define=CINEVAULT_PERF=true --output=build/phase2_web
python scripts/phase2_renderer_benchmark.py --chrome '<chrome.exe>' --baseline '<Phase 1 release>' --current build/phase2_web --samples 30 --scroll-samples 3 --scroll-seconds 20
python scripts/phase2_renderer_benchmark.py --chrome '<chrome.exe>' --current build/phase2_web --smoke
python scripts/phase2_screenshots.py --chrome '<chrome.exe>' --build build/phase2_web --out build/phase2-proof/web
python scripts/phase2_screenshots.py --chrome '<chrome.exe>' --build build/phase2_web --out build/phase2-proof/breakpoints --breakpoints
python scripts/phase2_android_screenshots.py --device '<isolated emulator serial>' --out build/phase2-proof/android
```

The tools use Python, `websockets`, Chrome, and Pillow for image handling. Live captures load the local app credential from the existing ignored asset. Fixture measurements substitute a dummy credential and export only timings, bytes, and counters.

## Release Web measurements

Thirty interactive samples per revision. Times are milliseconds and p95 uses the nearest rank. The title timing marker is the first visible 148-minute runtime, which can be present in the summary fixture.

| Measurement | Phase 1 p50 | Phase 1 p95 | Phase 2 p50 | Phase 2 p95 |
| --- | ---: | ---: | ---: | ---: |
| Document load → visible Home heading | 318.40 | 468.60 | 296.35 | 466.40 |
| Document load → first painted artwork | 1,426.85 | 1,593.70 | 976.50 | 1,181.80 |
| First image transfer | 135.21 | 152.25 | 136.79 | 150.76 |
| Artwork transferred before first paint (bytes) | 232,234 | 232,234 | 96,641 | 96,641 |
| JSON requests initiated before first artwork (count) | 2 | 2 | 3 | 3 |
| Search input → visible result | 941.40 | 1,065.10 | 713.05 | 740.30 |
| Fresh title click → visible runtime | 87.05 | 151.30 | 102.65 | 127.00 |
| JSON initiated before the fresh title marker (count) | 3 | 3 | 3 | 3 |
| Cached title click → visible runtime | 76.75 | 97.20 | 80.45 | 90.50 |
| Repeated title detail JSON before cached marker (count) | 0 | 0 | 0 | 0 |

The measured cold Home, first artwork, search, and cached title markers meet the respective timing targets in this environment. The third Home request loads the image configuration. First artwork uses 58% fewer bytes before paint and appears 26% sooner at p95. Search is 30% faster at p95. Fresh title navigation still initiates three JSON requests before the visible-runtime marker, one above the plan's request target.

### Sustained scrolling

Three 20-second runs per revision. Each cell reports the median run followed by the worst or highest observed run for that measurement.

| Measurement | Phase 1 median / highest | Phase 2 median / highest |
| --- | ---: | ---: |
| Catalogue pages requested | 8 / 8 | 8 / 8 |
| Artwork requests completed | 525 / 525 | 160 / 160 |
| Artwork transferred (MiB) | 29.89 / 29.89 | 1.94 / 1.94 |
| Median frame interval (ms) | 16.70 / 16.70 | 16.70 / 16.70 |
| p95 frame interval (ms) | 33.40 / 33.40 | 33.40 / 33.40 |
| Frame intervals over 16.7 ms | 41.22% / 44.86% | 41.98% / 44.77% |
| Frame intervals over 20 ms | 10.50% / 12.14% | 9.63% / 11.34% |
| JS heap at start of scroll (MiB) | 30.31 / 30.33 | 35.49 / 35.65 |
| Peak sampled JS heap (MiB) | 63.56 / 65.09 | 92.28 / 97.30 |
| JS heap back on Home (MiB) | 52.57 / 62.00 | 70.45 / 78.62 |
| JS heap back on Home after requested GC (MiB) | 27.00 / 27.04 | 28.12 / 28.14 |

Both builds fetched all eight fixture pages. Phase 2 transferred 94% less artwork and made 70% fewer completed image requests with HTTP caching disabled. Frame interval p95 was flat at 33.4 ms. Both revisions exceeded the plan's 5% threshold for intervals over 16.7 ms under software rendering. Phase 2's sampled peak JS heap rose 45%, while the post-GC difference was 1.12 MiB. Hardware frame traces and heap allocation profiling remain open.

## Remaining verification and scope

- The Web run uses headless software rendering with Flutter semantics exposed. A true cold-process startup, TalkBack/Narrator traversal, hardware-backed Web frame pacing, native frame/raster and GPU memory, Safari/iOS, macOS, Linux and physical Android performance remain unverified. The 600–1023 px tablet layout was checked in a browser using the Web app.
- The persistent cache holds fresh public JSON. Native artwork uses Flutter's bounded in-process image cache, and Web delegates transfer caching to the browser. Stale offline catalogue browsing and a native on-disk image cache remain open.
- Carry the reusable overview, facts, artwork and related-title sections into Phase 3. Credits/person/filmography, collections, studios, networks, keywords, and season and episode content still need data and rendered destinations. The production credential distribution and full TMDB attribution review remain release work.
