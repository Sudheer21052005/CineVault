# Phase 1 implementation and verification

27 November 2026 · `feature/ui-redesign`

Comparison baseline `7587a85d61f5c9dbf85ab9db36aa0832e0223ab0` · Implementation `429ece99945239c8fc78c7d7540a1fb09a0cf9bc`

This phase implements the storage, network and navigation foundations behind the existing CineVault screens. The [baseline audit](BASELINE_AUDIT.md) describes the original behavior. The [upgrade plan](UPGRADE_PLAN.md) remains the roadmap for the responsive UI, richer catalogue and personal library.

## Implemented

| Boundary | Implementation |
| --- | --- |
| Application | `lib/main.dart` composes an instance-scoped transport, catalogue and Hive repository. The Router shell renders without a timed splash. Hive opens independently after the first frame, and Watchlist and Stats have a recoverable open state. Home starts its visible catalogue shelves only. Other tabs mount on first use and retain state afterward. Hidden tabs suppress animation, focus and Hero collection. |
| Navigation | `lib/app/route_contract.dart` parses and serializes typed routes for tabs and the entity namespaces. Movie, TV, browse and search are live. Person, filmography, collection, company, network, keyword, season and episode contracts reserve valid URLs for Phase 3. The Router preserves nested origins and search state. Now Playing Back explicitly selects Home at the shell level. On web, direct loads use Flutter's hash strategy, for example `/#/movie/27205`. |
| Catalogue | `lib/catalogue` owns feeds, separate typed text scopes and Discover filters, title fetches and the shared pagination controller. Movie and TV scope issue their own TMDB endpoints. Discovery has a separate mode with per-kind genre dictionaries, year and sort parameters. Input changes immediately invalidate older work, and a failed refresh or next page has an explicit retry while retaining the last successful grid. Title and related sections own their request lifecycles and show local errors. |
| Network | `lib/core/network/tmdb_transport.dart` coalesces canonical reads and limits concurrent JSON operations to four. Its in-memory LRU is bounded at 150 responses and 12 MiB of response bytes. It cancels timed-out attempts on supported clients and limits request time and retries. 429 uses a shared cooldown and honors exposed `Retry-After` values within the caller's budget. Failures are typed and redact credential-bearing transport errors. Fresh retry can bypass a successful cached response without discarding it on failure. |
| Library | The repository uses the same Hive box names, type ID, positional record format, status names and media keys. It reads records before reconciling achievements, preserves older earned IDs and never implicitly adds demo titles to an empty box. It publishes snapshots after item commits, serializes mutations, merges disjoint edits from the same snapshot, rejects stale edits to removed records, and reconciles failed achievement writes independently. The existing edit sheet supports clearing personal ratings and watched dates. |
| Platform config and dependencies | Android's main manifest includes internet access, and AGP moved from 9.1.0 to 9.1.1 to meet the installed Flutter SDK's minimum. The Gradle wrapper was already compatible with 9.1.1. macOS Debug/Profile and Release entitlements enable sandboxed outbound connections. HTTP's declared minimum now supports cancellation, with the existing locked 1.6.0 resolution. Material imports use a single compatibility boundary for Flutter's SDK deprecation. [AGP 9.1.1 compatibility](https://developer.android.com/build/releases/agp-9-1-0-release-notes) |

## Verification

The tested host is Windows 11 with an Intel Core i5-13450HX, Flutter 3.50.1, Dart 3.14.0 and Chrome 158.0.8127.37. Fixture checks keep a separate browser profile and use the deterministic payloads in `test/fixtures/tmdb_catalogue.json`. The six original tests cover the original model and pagination contracts. The new regressions cover typed TMDB routes and genres, deduplication, request caps, 429, cache replacement, key redaction, invalidation during search/clear/pagination, Hive records with each historic tail length, failure and recovery, and navigation through the existing screen entry points.

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | Passed with zero findings. |
| `flutter test --no-pub --reporter expanded` | All 21 tests passed, including the six original tests. |
| Flutter Web release | Release build and Wasm compatibility dry run passed. Chrome fixture smoke at 390 × 844 confirmed Now Playing Back, nested title browser Back/Forward, TV title scope, TV discovery and an empty library. A separate live smoke passed title search and a canonical movie link. |
| Android release | Release APK built, packaged manifest contains `android.permission.INTERNET`, and the APK installed on the isolated Pixel 9 emulator. Live search returned Inception, the detail screen showed its 148-minute runtime, and Android system Back restored the result. The SDK still emits advance notices for Gradle, AGP and Kotlin versions. |
| Windows release | The Windows x64 release application built with Visual Studio 2022 Build Tools. The smoke runs did not open a native app against the host's existing user storage. |
| macOS, iOS, Linux and physical Android | Both macOS entitlements parse and are assigned to the expected Xcode configurations. Xcode/macOS and iOS/Safari runtime, Linux release runtime, and physical Android hardware were unavailable on this Windows host. |

## Comparable performance protocol

Use `scripts/phase1_web_benchmark.py` with installed Chrome and Python's `websockets` package. Build the baseline from the exact audit commit in a scratch directory with a dummy dotenv value, and use the same SDK and resolved packages. Build both with local CanvasKit assets and enable marks for the current build:

```powershell
flutter build web --release --no-pub --no-web-resources-cdn --dart-define=CINEVAULT_PERF=true
python scripts/phase1_web_benchmark.py --chrome '<chrome.exe>' --baseline '<baseline build/web>' --current build/web --samples 30
python scripts/phase1_web_benchmark.py --chrome '<chrome.exe>' --current build/web --smoke
python scripts/phase1_web_benchmark.py --chrome '<chrome.exe>' --current build/web --live
```

Fixture comparisons use headless Chromium at 1440 × 900 CSS pixels, DPR 1, loopback assets, browser HTTP caching disabled, and a 350 ms simulated JSON response delay. Each iteration loads a new document in the same isolated process and storage origin. Title navigation is measured after search. Scroll runs once into a 39-title Now Playing fixture and measures the header leaving the viewport. The shell readiness marker is the visible Now Playing control. The first card marker excludes artwork. The harness injects a dummy credential and emits only named durations, counts and percentiles. Live smoke uses the local, undistributed build with the configured credential.

### Release-web results

Thirty samples per revision and row. Timings are milliseconds. The p95 uses the nearest rank. These are comparable to each other and use a separate protocol from the manual debug-web timings in the original audit.

| Measurement | Baseline p50 | Baseline p95 | Phase 1 p50 | Phase 1 p95 |
| --- | ---: | ---: | ---: | ---: |
| Document load → visible shell | 2,207.45 | 2,348.40 | 390.95 | 629.70 |
| Document load → first title card | 2,659.40 | 2,787.30 | 893.20 | 1,118.70 |
| JSON requests initiated before first card (count) | 8 | 8 | 2 | 2 |
| Search input → visible result | 883.45 | 924.20 | 728.10 | 754.60 |
| Search HTTP request under simulated delay | 359.16 | 375.98 | 365.33 | 381.23 |
| Title click → visible detail Back control | 86.20 | 100.30 | 67.20 | 88.60 |
| Wheel input → header offscreen | 84.40 | 113.60 | 85.15 | 140.10 |
| Dart startup → post-frame shell marker | — | — | 89.65 | 128.80 |
| Dart search input → accepted result frame | — | — | 697.95 | 709.80 |

The median shell time fell by 82%, pre-card JSON requests by 75%, and search time by 18%. Median scroll-response time moved by less than 1 ms, while p95 rose by 26.5 ms. The wheel probe reports one viewport transition. It cannot establish whether frame pacing improved. Phase 2 should measure long scrolls, image decode and paint, and memory on real devices before setting renderer targets. The small HTTP increase is under simulated service delay and does not estimate a live TMDB latency change.

For the instrumented build, `CINEVAULT_PERF=true` enables named Dart timeline events and release-web `cinevault.*` performance marks. The marks report startup first frame and shell, library open, search input and accepted result paint, navigation to first frame, TMDB outcome/attempts/bytes including cache and join counters, and vertical scroll. Native profile mode adds frame duration and missed-budget samples when the engine reports them. Fields are bounded numbers and allowlisted labels. The events exclude raw URLs, query text, entity IDs, credentials and library contents.

## Remaining scope

- Phase 2 owns the responsive layout, dedicated artwork measurements, persistent catalogue caching, and renderer tuning. Phase 3 enables the additional typed destinations and graph relationships. Private watch events and export/import stay in Phase 4.
- Development `.env` continues to be a local Flutter asset. Distributed-client credential isolation remains a release requirement. The benchmark uses dummy data for fixture runs and does not publish assets.
- Browser instrumentation compares a controlled release build. A physical Android profile trace, Safari/iOS and macOS runtime measurements, Linux release runtime, true new-process percentiles, first-artwork paint and the 20-second frame/peak-memory budget remain separate release checks.
