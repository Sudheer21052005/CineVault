# Phase 6 user experience, visual identity and motion

28 November 2026 · `feature/ui-redesign` · Phase 5 comparison revision `c1ad104d7320d1c5e30fd9284b8ed248874c5e14`

## Navigation and detail pages

- Home, Discover, Search, and Library retain their own navigation on phones. Discover can resume Movies, TV Shows, or Now Playing, while Library can resume Watchlist or Statistics. Moving between primary destinations restores the last page and scroll position. Reselecting the active destination returns to its root. Desktop continues to expose labeled catalogue and library entries. Tablets keep the compact rail.
- Deep entities retain the shell, and the artwork viewer opens above it. Browser Back and Forward resolve the typed URL and its saved branch location. Android system Back closes the viewer, returns through the current exploration stack, then returns to the previous destination from a branch root when available. The headless Android emulator exposed a predictive Back bug after switching branches. The outer Navigator now advertises that the router handles Back, including when an inactive branch is at its own root.
- Movie and series pages open on a cinematic Overview with storyline, linked metadata, director or creators when available, top cast, regional availability, and related-title shelves. The horizontally scrollable section bar pins during vertical browsing. Cast & crew, Seasons, Related, Media, Details and Reviews load their secondary information when selected and near the viewport. Full credits, franchise and catalogue links, videos, review pagination, certifications and external links stay available.
- The palette derives a tone from a 20 × 20 sample of artwork already decoded by Flutter. A 32-entry cache stores sampled colors. The page falls back to a blue tone when the image or renderer cannot provide pixels. Warm gold still marks strong actions and catalogue score. The new aperture and gold shutter replace the mark in the shell, Android launcher, Windows executable, Web favicon and install icons. The About page retains Sudheer Prajapati’s original developer credit.

## Artwork and motion

- Title backdrops and posters, person photographs, and episode stills use the same viewer. The inline preview limits itself to two rows per type. The full grid and thumbnail strip build visible children lazily. Fullscreen displays artwork at its original aspect ratio, supports swipe and previous/next, and provides pinch, double-tap, mouse-wheel zoom, pan, fit reset, keyboard controls, and a position counter. Artwork starts at an adaptive CDN size. The HD control switches the active image to TMDB’s original. Logos are omitted from user-facing galleries.
- The download control saves the original from the TMDB image CDN with a 32 MiB transfer cap. The personal library and its storage format are independent of artwork downloads.
- Posters and portraits use shared artwork when the source and destination are both mounted. Direct URLs display artwork without an originating card. The carousel, navigation indicator, section tabs, fullscreen viewer, and favorite or watchlist controls use short feedback animations. The reduced-motion setting bypasses the shared artwork flight and the corresponding duration-based transitions.
- The five supplied concepts guided navigation, the open Overview, artwork colors, the brand mark, and the viewer. The short recording guided the poster transition. Catalogue screenshots came from the running app with live TMDB content.

## Visual evidence

| Screen | Capture |
| --- | --- |
| Desktop movie billboard and Overview | [Chrome at 1440 px](screenshots/phase6/desktop-detail.jpg) |
| Tablet movie billboard and navigation rail | [Chrome at 768 px](screenshots/phase6/tablet-detail.jpg) |
| Phone movie billboard and persistent bottom bar | [Chrome at 390 px](screenshots/phase6/phone-detail.jpg) |
| Director and top cast in Overview | [Chrome at 390 px](screenshots/phase6/phone-cast.jpg) |
| Person profile and retained Search destination | [Chrome at 390 px](screenshots/phase6/phone-person.jpg) |
| Filmography with the same retained navigation | [Chrome at 390 px](screenshots/phase6/phone-filmography.jpg) |
| Fullscreen artwork and thumbnail navigation | [Chrome at 1440 px](screenshots/phase6/desktop-viewer.jpg) |
| Artwork viewer on Android | [Pixel 9 emulator](screenshots/phase6/android-viewer.jpg) |
| Episode stills on Android | [Pixel 9 emulator](screenshots/phase6/android-episode.jpg) |

## Verification

| Check | Result |
| --- | --- |
| Flutter | Clean `flutter analyze --no-pub` and 41 passing tests. The suite covers route restoration, 200% text scaling on compact screens, backward-compatible Hive records, and keyboard, swipe, pinch, double-tap, pan, wheel zoom and dismissal in the artwork viewer. |
| Chrome desktop and phone | Live Iron Man and Breaking Bad runs. Tested title → person → filmography, destination reselection, browser Back/Forward, application Back, tabs, artwork grids, keyboard previous/next and close, zoom/reset, thumbnails, and series → season → episode → viewer. Desktop saved an original image. |
| Responsive Chrome | Live title captures at 320, 390, 599, 600, 768, 1023, 1024 and 1440 px. Inspected the compact billboard, the tablet rail, the desktop sidebar, and the viewer at phone and desktop sizes. |
| Android | Live Pixel 9 emulator release with host graphics. Verified movie → director, branch switch and restoration, system Back to the movie, fullscreen swipe, zoom and fit controls, system Back to the detail, and the episode stills viewer. |
| Release and credentials | Built Web, Windows x64, and Android. Scanned Git and the credential-free Web benchmark artifact without printing the configured key. `.env` and the live release directory are ignored. |

Physical Android, iOS, macOS and Safari remain unverified in this phase. Flutter’s gesture tests exercised pinch, double-tap and pan. Native Android QA used a single-touch swipe and the zoom controls. Android image saving remains a manual check. Windows x64 verification covered the release build. Interactive desktop checks and matched performance measurements ran in Chrome.

## Matched Chrome performance

The benchmark rebuilt the exact Phase 5 starting commit and the Phase 6 implementation on the same Windows host. Chrome 158.0.8127.37 reported hardware compositing and rasterization on Intel UHD Direct3D 11 at 1440 × 900 and DPR 1. Both builds used the same 350 ms JSON delay, 120 ms artwork delay, disabled HTTP cache and cold IndexedDB setup. The harness measures the first Home heading and painted artwork, Search input to an Inception result, and the title click to its visible runtime. Each revision ran 12 interactive samples and three 12-second Now Playing scroll sequences.

| Interactive measurement | Phase 5 p50 / p95 | Phase 6 p50 / p95 |
| --- | ---: | ---: |
| Home heading (ms) | 372.1 / 679.7 | 356.05 / 614.0 |
| First painted artwork (ms) | 995.45 / 1,327.6 | 997.5 / 1,213.8 |
| First artwork transfer (ms) | 136.34 / 164.66 | 134.53 / 150.99 |
| Search input to result (ms) | 707.45 / 725.2 | 708.85 / 724.7 |
| Fresh title to visible runtime (ms) | 87.4 / 109.6 | 112.75 / 158.6 |
| Cached title to visible runtime (ms) | 78.4 / 99.5 | 77.9 / 103.9 |
| JSON requests before fresh title marker | 2 / 2 | 2 / 2 |
| Repeat detail requests before cached marker | 0 / 0 | 0 / 0 |

| Sustained Now Playing scroll | Phase 5 p50 / p95 | Phase 6 p50 / p95 |
| --- | ---: | ---: |
| Run-level p95 animation interval (ms) | 8.7 / 9.0 | 16.4 / 16.5 |
| Animation callbacks over 16.7 ms (%) | 2.42 / 2.72 | 2.59 / 2.73 |
| Animation callbacks over 20 ms (%) | 1.81 / 1.97 | 1.98 / 1.98 |
| Peak JavaScript heap (MiB) | 92.05 / 92.28 | 85.65 / 98.11 |
| Return Home heap before requested GC (MiB) | 36.31 / 36.79 | 86.51 / 100.20 |
| Return Home heap after requested GC (MiB) | 27.18 / 27.21 | 27.65 / 27.67 |
| Completed artwork requests | 160 / 160 | 160 / 160 |
| Catalogue pages requested | 8 / 8 | 8 / 8 |
| Artwork transferred (MiB) | 1.94 / 1.94 | 1.94 / 1.94 |

Home p95 improved by 65.7 ms and search was effectively flat. Fresh title readiness increased by 25.35 ms at the median and 49.0 ms at p95 with the same two-request count. Cached title p95 increased by 4.4 ms. At the host’s roughly 120 Hz callback cadence, the scroll p95 interval increased. The median share above 16.7 ms moved from 2.42% to 2.59% with identical pages and artwork transferred. The return-to-Home heap was higher before explicit GC and settled within 0.47 MiB of Phase 5 at the median. These measurements describe browser callback intervals and JavaScript heap on this fixture.

## Local live releases

The private builds used the existing ignored `.env` through `--dart-define-from-file=.env`. Use a loopback server for the Web directory, install the Android APK on a test device, and keep the Windows executable with the files shipped beside it.

| Target | Workspace path |
| --- | --- |
| Web | `build/phase6-live/web/` |
| Windows x64 | `build/phase6-live/windows/cinevault.exe` |
| Android | `build/phase6-live/android/CineVault.apk` |

The Web release is JavaScript with a passing Wasm compatibility dry run. The Android release uses the project’s local QA signing configuration. Android release compilation printed the existing future support warnings for Gradle, the Android Gradle Plugin, and Kotlin.

## Reproduce

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --release --no-pub --no-web-resources-cdn --dart-define-from-file=.env --output=build/phase6-live/web
flutter build apk --release --no-pub --dart-define-from-file=.env
flutter build windows --release --no-pub --dart-define-from-file=.env
python scripts/phase6_web_verification.py --chrome '<chrome.exe>' --build build/phase6-live/web --out build/phase6-proof/web-desktop
python scripts/phase6_web_verification.py --chrome '<chrome.exe>' --build build/phase6-live/web --out build/phase6-proof/web-phone --phone
python scripts/phase6_web_verification.py --chrome '<chrome.exe>' --build build/phase6-live/web --out build/phase6-proof/breakpoints --breakpoints
python scripts/phase6_android.py --device '<isolated emulator serial>' --out build/phase6-proof/android
flutter build web --release --no-pub --no-web-resources-cdn --dart-define=TMDB_API_KEY=fixture-only --dart-define=CINEVAULT_PERF=true --output=build/phase6_web_fixture
python scripts/phase5_benchmark.py --chrome '<chrome.exe>' --baseline '<Phase 5 fixture release>' --build build/phase6_web_fixture --samples 12 --scroll-samples 3 --scroll-seconds 12 --library-samples 0
python scripts/phase5_scan_release.py build/phase6_web_fixture
python -m http.server 8766 --bind 127.0.0.1 --directory build/phase6-live/web
```

The scanner accepts credential-free artifacts. The live releases embed the configured key for catalog access and stay in the ignored build directory. The verification harnesses use an isolated Chrome profile and an expressly selected Android emulator.
