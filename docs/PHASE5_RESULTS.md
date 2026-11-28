# Phase 5 performance optimization and release hardening

28 November 2026 · `feature/ui-redesign` · Phase 4 comparison revision `63ef4abe1633e55a5c8f10da775fbd6ba27e640d`

## Changes and findings

- The previous poster grid used a `SliverLayoutBuilder` whose inputs included the scroll offset and remaining paint extent. Catalogue grids now read box width from the containing viewport and keep their delegate stable between scroll frames. Pagination schedules at most one next-page callback per frame, keeps sequential requests and retries, and exposes a keyboard-operable Load more control. Discovery grids now have a scroll storage key.
- Artwork only invalidates consumers whose resolved image provider changed. Native decode-size hints and bounded decoded caches stay in place. Production image loads skip per-image stopwatches and timing callbacks unless a consumer needs readiness.
- Cache pressure is measured with separate pre-scroll, peak, and post-GC browser heap snapshots. Configured cache bounds are 180 decoded image entries and 64 MiB, up to 150 memory JSON entries and 12 MiB, and up to 350 persisted JSON entries with 15 MiB on Web or 40 MiB on native. Flutter’s decoded-image cap applies to retained cache entries. Live images, browser textures, and native process memory have separate lifetimes.
- Recommendation ranking keeps the best three seeds during a single selection pass. Home and Statistics reuse the current relevant library projection across rebuilds and remounts. Recording an unrelated history visit leaves the recommendation request and statistics intact. Home network results have a five-minute memo window; the underlying TMDB cache retains its existing operation-specific limits.
- Native visual QA showed text from two destinations overlapping during a translucent route fade. The route uses a short opaque translation now and retains the bypass for reduced-motion users. Desktop-window titles and Web install metadata identify CineVault.
- Desktop route barriers previously hid navigation from assistive technology, and the About label could merge with the parent surface. The catalogue now has its own semantics boundary, and navigation buttons expose separate labels and actions. Chrome and Windows UI Automation verified those labels, including on a nested route.
- TMDB’s official logo and notice are in About with Sudheer Prajapati’s original credit. JustWatch is named alongside catalogue availability. `.env` has been removed from Flutter assets. A key is now an explicit build input for local live access; default builds and packaged assets omit the key. Android supports owner-controlled signing with an optional build gate. [TMDB attribution](https://developer.themoviedb.org/docs/faq) · [Provider documentation](https://developer.themoviedb.org/reference/movie-watch-providers)

## Matched release-Web performance

Both revisions use Flutter 3.50.1 / Dart 3.14.0 on Windows, Chrome 158.0.8127.37 with verified Intel UHD Direct3D 11 hardware compositing and rasterization, 1440 × 900 at DPR 1, a 350 ms JSON delay, and a 120 ms artwork delay. The harness keeps the credential redacted, clears IndexedDB before the cold Home sequence, and disables the browser HTTP cache. The Now Playing fixture uses a 20-second wheel sequence and a fresh Chrome profile per scroll. The populated fixture restores 1,000 watchlist items plus a rated diary entry and a favorite, then measures Home recommendations and personal statistics in the same browser profile. Those timings include app load, the scripted scroll to the relevant heading, and fixture network responses when necessary.

| Interactive measurement, 30 samples | Phase 4 p50 / p95 | Phase 5 p50 / p95 |
| --- | ---: | ---: |
| Home heading (ms) | 446.2 / 621.9 | 376.6 / 712.3 |
| First painted artwork (ms) | 1,119.15 / 1,285.8 | 1,078.8 / 1,380.4 |
| First artwork transfer (ms) | 138.73 / 165.68 | 141.59 / 158.26 |
| Search input to result (ms) | 720.35 / 745.7 | 717.05 / 736.8 |
| Fresh title to visible runtime (ms) | 100.55 / 169.3 | 87.15 / 133.1 |
| Cached title to visible runtime (ms) | 81.2 / 98.2 | 83.05 / 94.0 |
| JSON requests before fresh title marker | 2 / 2 | 2 / 2 |
| Repeated detail JSON before cached marker | 0 / 0 | 0 / 0 |

| Sustained scrolling, five 20-second runs | Phase 4 p50 / p95 | Phase 5 p50 / p95 |
| --- | ---: | ---: |
| Run-level p95 animation interval (ms) | 8.60 / 8.70 | 8.60 / 8.60 |
| Animation callbacks over 16.7 ms (%) | 3.36 / 3.85 | 2.72 / 2.95 |
| Animation callbacks over 20 ms (%) | 2.90 / 3.10 | 1.95 / 2.13 |
| Peak JavaScript heap (MiB) | 90.48 / 111.43 | 109.49 / 110.11 |
| Return Home heap after requested GC (MiB) | 27.96 / 27.96 | 27.85 / 27.88 |
| Completed artwork requests | 160 / 160 | 160 / 160 |
| Catalogue pages requested | 8 / 8 | 8 / 8 |
| Artwork transferred (MiB) | 1.94 / 1.94 | 1.94 / 1.94 |

| Populated library, 12 samples | Phase 4 p50 / p95 | Phase 5 p50 / p95 |
| --- | ---: | ---: |
| Home recommendations ready (ms) | 645.65 / 1,443.8 | 638.35 / 1,517.4 |
| Personal statistics heading (ms) | 620.65 / 715.1 | 605.65 / 790.4 |

Fresh detail improved by 36.2 ms at p95; Home and both populated-library operations improved at the median and were slower at p95. The scroll fixture used hardware callbacks at approximately 120 Hz. Both revisions stayed below 5% over 16.7 ms on this configuration. The Phase 5 median peak JavaScript heap was higher and the p95 after-GC heap was essentially flat. These browser results do not establish performance on physical Android hardware.

The two six-second diagnostic traces recorded 66 → 70 Chrome `Layout` events (35.5 → 39.9 ms total), 54.4 → 62.2 ms of minor GC, and 72.4 → 72.4 ms of major GC. CanvasKit image decode and upload were not independently attributable in this trace. The application’s grid regression counts widget builders directly and confirms that moving within an already-mounted row adds no builds. The benchmark revision includes the layout, artwork, pagination, library and transition changes. The independent desktop semantics fix followed this capture.

## Native profile observations

- **Android Pixel 9 emulator with host GPU acceleration.** SurfaceFlinger reported the RTX 3050 via OpenGL ES translator. The live profile run recorded 501 Flutter frames across 18 gesture samples, with 87 over the 16.7 ms build-or-raster threshold. Median gesture build p95 was 1.92 ms and median raster p95 was 17.42 ms. The worst gesture recorded 5.21 / 27.12 ms build / raster p95. Android process PSS sampled 120.36 MiB before scrolling, 126.19 MiB after scrolling, and 130.04 MiB on return to Home. The raster results show that emulator jank remained with low Dart build times. The profile run used live artwork and network, so its timings are separate from the matched browser fixtures.
- **Windows x64.** The native profile displayed live Home artwork and paginated the Now Playing grid. The tested Windows process had a 194.1 MiB working set and a 273.2 MiB peak working set after browsing and file operations. Dart start to shell was 173.55 ms and Now Playing navigation to its rendered frame was 25.25 ms. In a separate live scroll trace, Flutter recorded 112 `Animator::BeginFrame` events at 3.91 ms p95 and 105 `GPURasterizer::Draw` events at 13.48 ms p95. These are spot measurements from a native profile, with the VM endpoint and all trace arguments excluded.
- **Long Web exploration.** In the final live movie → cast → person → filtered filmography → movie → director chain, JavaScript heap sampled 34.18 MiB initially, 75.83 MiB at the director, and 42.54 MiB after returning and requested garbage collection. Filmography filters and scroll position survived Back/Forward. The franchise and TV season → episode → guest chains also passed, including a reload and stills on the pilot.

## Verification matrix

| Check | Outcome |
| --- | --- |
| Analysis and Flutter regression | Clean analysis, 39 tests passed. Coverage includes failed and concurrent writes, same-day repeats, 1,000 offline records, legacy Hive compatibility, memoization invalidation, stable poster builders while scrolling, desktop sidebar semantics beside nested routes, search state, nested Back, and 200% mobile text. |
| Chrome live catalogue and personal library | Responsive catalogue captures across 320, 390, 599, 600, 768, 1023, 1024 and 1440 px. Desktop and phone captures cover the graph and personal library. Both Web profiles exported JSON and CSV, reloaded with TMDB disabled, imported the JSON twice on a fresh profile, and exported the same records. |
| Keyboard, semantics and motion | Chrome Ctrl+K focused Search and the browser accessibility tree identified the live Inception result as a button. Under emulated reduced motion, the Home hero did not auto-advance during a nine-second check. Windows Tab focus and UI Automation labels were inspected. Full Narrator and TalkBack speech traversal remains open. |
| Native Windows JSON and release runtime | Restored a synthetic QA backup into isolated Hive storage using the Windows picker, then saved a new JSON file. The parsed exports matched, including both repeat viewings, lists, favorites, and episode progress. The final credential-free Windows release reopened both diary entries, and UI Automation exposed sidebar buttons beside the nested diary route. |
| Native Android JSON | Saved the native JSON file to Downloads, cleared the test installation, restored the file twice through Android’s system picker, and verified that the diary retained exactly one viewing. |
| Android release rollback | Restored the 1,000-record fixture in the credential-free release and reopened the diary after force-stop. Reinstalled the signed Phase 4 local QA APK over the same installation and reopened the diary and live Home. |
| Release artifacts | Web JavaScript (Wasm compatibility dry run), Android APK, and Windows x64 release built. Scanned Web assets, APK members, Windows release files, and Git patches without logging the local credential. The Android signing gate rejected a production build without owner keys. Production certificates and Apple signing were unavailable. |
| Platform toolchains | Available targets were Chrome, Windows, and an isolated Android emulator. Physical Android, iOS, macOS, Safari, and desktop Linux runtime remain open. The installed Ubuntu WSL environment lacked a Linux Flutter toolchain, GTK development packages, and build utilities. |

## Visual evidence

- [Desktop catalogue](screenshots/phase5/catalogue-desktop.jpg) and [mobile catalogue](screenshots/phase5/catalogue-mobile.jpg)
- [Desktop entity graph](screenshots/phase5/graph-desktop.jpg) and [mobile entity graph](screenshots/phase5/graph-mobile.jpg)
- [Desktop personal library](screenshots/phase5/library-desktop.jpg) and [mobile personal library](screenshots/phase5/library-mobile.jpg)
- [Android backup picker and repeated restore](screenshots/phase5/android-backup.jpg)
- [TMDB and original developer credits](screenshots/phase5/attribution.jpg) and [JustWatch attribution beside market availability](screenshots/phase5/availability.jpg)

## Remaining release gates

- Physical Android and the Apple, Safari and Linux matrix still need builds or runtime verification on suitable hardware. TalkBack was installed on the emulator, which ran headless without audio. Narrator speech remains unverified. The injected Windows Ctrl+K chord did not move focus in the test harness, while native Tab navigation, the Windows accessibility tree, and Chrome Ctrl+K were verified directly.
- Android emulator raster p95 remained above the 16.7 ms target in several live-artwork gestures. The cold Home and populated-library p95 regressions should remain visible in the release review. The hardware Chrome scroll result covers this host and fixture.
- Production store signing, project-level licensing, and a public authentication design for managed live TMDB access remain distribution decisions. The default builds work with the local library and cached data. Live QA builds with a supplied key should remain private.

## Reproduce

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --release --no-pub --no-web-resources-cdn --dart-define=CINEVAULT_PERF=true --dart-define=TMDB_API_KEY=fixture-only --output=build/phase5_web_fixture
python scripts/phase5_benchmark.py --chrome '<chrome.exe>' --baseline '<Phase 4 instrumented release>' --build build/phase5_web_fixture --samples 30 --scroll-samples 5 --scroll-seconds 20 --library-samples 12 --trace
flutter build apk --profile --no-pub --dart-define-from-file=.env --dart-define=CINEVAULT_PERF=true --dart-define=CINEVAULT_PERF_OUTPUT=true
adb -s '<isolated emulator serial>' install -r build/app/outputs/flutter-apk/app-profile.apk
python scripts/phase5_android.py --device '<isolated emulator serial>' --out build/phase5-proof/android
flutter build windows --profile --no-pub --dart-define-from-file=.env --dart-define=CINEVAULT_PERF=true --dart-define=CINEVAULT_PERF_OUTPUT=true --dart-define=CINEVAULT_QA_STORAGE='<absolute test Hive directory>'
python scripts/phase5_web_qa.py --chrome '<chrome.exe>' --live '<local live Web directory>' --offline '<credential-free Web directory>' --out build/phase5-proof/accessibility
python scripts/phase5_scan_release.py '<credential-free Web directory>' '<credential-free APK>' '<credential-free Windows directory>'
```

The Android round-trip command clears CineVault data on the selected test emulator after exporting its fixture. Use a fresh isolated emulator, and keep live QA releases and exported test records out of Git.
