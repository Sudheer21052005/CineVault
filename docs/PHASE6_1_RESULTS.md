# Phase 6.1 final UX bug fixes

Base revision `cd0cdc564f4c0992021b6578f7a0db131fbb0974` on `feature/ui-redesign`.

## Reviews

The rectangle had two sources. A delayed review response reproduced the generic 92 px `GraphLoad` skeleton under Viewer reviews. After a scroll offset had been saved, the unkeyed `ExpansionTile` could also fail to build. Flutter’s `Expansible` tried to read the parent scroll view’s stored `double` as a `bool?`. Its release error widget can render as a blank grey area. The regression test reproduces the type error with a delayed review body after scrolling.

Viewer reviews now has a labeled loading indicator, separate empty and unavailable messages, and a retry action for failed requests. The retry regression exposed a callback that returned a `Future` from `setState`. The request now starts before the synchronous state update. Each card keeps its own expansion state and has a distinct storage key, author, date and rating when available, a two-line preview, expandable selectable text, and its source link. Translation rows in the same detail viewport also have distinct storage keys.

## Known for

The shelf used the full filmography’s default popularity sorting. It now ranks the strongest contribution to each title using cast billing, episode counts, department alignment, writing and production roles, and bounded popularity and vote scores. Talk and news appearances, self credits, and one-episode roles receive lower weight. A cached person search supplies optional TMDB known-for hints only for an exact person ID match. The hints run alongside combined credits and have a 650 ms shelf wait limit. The full filmography retains every credit and all existing sorts. [TMDB person search](https://developer.themoviedb.org/reference/search-person) · [TMDB combined credits](https://developer.themoviedb.org/reference/person-combined-credits)

## Overview and section tabs

The Overview used a lazy variable-height sliver list. An offscreen block could be disposed and re-enter as a shorter loading placeholder, even when its fetch completed from cache. This changes the geometry Flutter uses to lay out earlier children during a scroll back up. The small set of lazily mounted blocks is now kept alive, retaining resolved data, layout and controls on viewport re-entry. The visited Overview is retained across tab switches with focus and animation ticks disabled while hidden. It can restore its saved depth without first laying out loading placeholders.

The original section handler swapped the body and then called `Scrollable.ensureVisible` on the header. Short content could first clamp the old offset and move the header. The explicit reveal could then move it a second time. In Chrome the original Reviews switch moved the tab center from 93.5 to 616.3 CSS px. The revised handler stops any current scrolling, leaves an unpinned header in place, restores pinned section offsets during scroll layout, and reserves enough trailing space to keep the header pinned even on short sections.

## Verification

| Target | Result |
| --- | --- |
| Flutter | Clean analysis and 45 passing tests. New cases exercise billing and credit relevance, review loading and expansion after a saved scroll offset, error retry and empty results, Overview state retention on re-entry, and exact offset restoration across long and short tabs. The isolated control test failed when block retention was disabled. |
| Chrome release | The pinned tab center stayed at 93.5 CSS px through seven Inception and eight Breaking Bad section switches. The live Millie Bobby Brown shelf began with Stranger Things, Enola Holmes and Enola Holmes 2. |
| Windows x64 | An isolated native release walkthrough exercised slow upward scrolling around availability and The Wire’s Seasons & episodes, plus repeated switches between Avengers: Doomsday’s empty Reviews, full credits and Overview. The bar stayed in place and Overview restored the prior viewport. Robert Downey Jr.’s shelf placed Iron Man among the leading cards, and Iron Man’s live review expanded to selectable text and its source link. |
| Pixel 9 emulator | Live movie and TV Overview checks exercised slow upward gestures around the availability and season sections, repeated tab switches, review cards and the Millie Bobby Brown shelf. The exact intermittent snap from the manual report did not recur in the original APK’s live emulator samples. The controlled Flutter test confirmed the offscreen disposal path and the fix. |

[Expanded live review](screenshots/phase61/expanded-review.jpg) · [Live Known for ranking](screenshots/phase61/known-for.jpg)

## Private live builds

All three builds used the existing ignored `.env` through `--dart-define-from-file=.env`. The final Web build passed Flutter’s Wasm compatibility dry run. Android continued to print the existing Gradle, Android Gradle Plugin and Kotlin support warnings.

| Build | Workspace path |
| --- | --- |
| Web | `build/phase61-live/web/` |
| Windows x64 | `build/phase61-live/windows/cinevault.exe` |
| Android | `build/phase61-live/android/CineVault.apk` |

Run the focused checks with `flutter test --no-pub test/knowledge_graph_test.dart`. The live Chrome and Android walkthroughs are in `scripts/phase61_verification.py` and keep credentials out of their output.
