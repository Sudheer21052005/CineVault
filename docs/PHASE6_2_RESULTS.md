# Phase 6.2 full filmography sorting and presentation

Continued from Phase 6.1 (`7239d3192bf1a84b62f7b4139c5c10d195a22747`) on `feature/ui-redesign`, with the subsequent README-only commit preserved.

## Sorting and browsing

The old Popularity sort ranked the title’s TMDB popularity alone. The person’s billing, role and episode count had no effect. On the original release, Jackie Chan’s first rows were *Running Man*, *The Daily Show* and *Late Show with David Letterman*. Jason Statham’s started with *The Tonight Show Starring Jimmy Fallon*, *Raw* and *Jimmy Kimmel Live!*.

Full filmographies now default to Relevance. It scores the strongest matching credit using billing, credited episode count, department alignment and type of contribution. Bounded title popularity and vote volume contribute alongside the vote-weighted rating. Popularity gives title popularity more weight while still accounting for the person’s contribution. Talk and news genres, self and guest credits, archive or uncredited roles, and one-episode appearances rank lower when stronger credits are available. Both modes keep those entries browsable. The separate Known for shelf keeps its Phase 6.1 ranking and optional TMDB hints. The full filmography adds no network requests for ranking.

Grid is the default from 600 px. Phones start in List, and both offer a Grid and List toggle. The choice stays with the current navigation entry, including when a title is opened and Back returns to the filmography. Both views share the same filters, sorting and result count. Poster cards show title, media type, year, rating when available and the strongest role matching the active role filter. The list keeps the existing detail rows and all role labels. Both render lazily using the existing sliver and artwork components.

Bare filmography links select Relevance. An explicit `?sort=popularity` still selects Popularity. The existing rating, date and alphabetical sorts and all facets keep their URL contracts.

## Verification

| Check | Result |
| --- | --- |
| Flutter | `flutter analyze --no-pub` reported no issues. All 46 regression tests passed, including focused checks for both ranking modes, role-specific card labels, combined filtering and sorting, layout switching, and Back restoration. |
| Jackie Chan, live Chrome release | Relevance began with *The Shadow’s Edge*, *Rush Hour*, *Rush Hour 2*, *Police Story*, *The Legend of Drunken Master* and *Drunken Master*. Popularity kept major film credits in the first row and also surfaced a 24-episode TV credit. The unfiltered count remained 295 titles. |
| Jason Statham, live Chrome release | Relevance began with *Snatch*, *Mutiny*, *Shelter*, *Wrath of Man* and *The Beekeeper*. Popularity moved *Mutiny* and *Shelter* ahead of *Snatch*, with no guest credits in the first row of either sort. The unfiltered count remained 77 titles. |
| Filters and responsive layout | At 1440 px, both actors opened in Grid. Applying the TV filter with Popularity active kept the same filter and sort when switching to List and back to Grid. The filtered list still displayed guest credits. At 390 px, Jason Statham opened in List and switched to a two-column Grid. |

Live rankings reflect TMDB data at verification time. Native runtime checks were outside this phase’s verification.

[Jackie Chan before](screenshots/phase62/chan-before.jpg) · [Jackie Chan grid](screenshots/phase62/chan-relevance.jpg) · [Jason Statham before](screenshots/phase62/statham-before.jpg) · [Jason Statham grid](screenshots/phase62/statham-relevance.jpg) · [TV-filtered list](screenshots/phase62/statham-filtered-list.jpg)

```powershell
flutter analyze --no-pub
flutter test --no-pub test/knowledge_graph_test.dart
flutter build web --release --no-web-resources-cdn --dart-define-from-file=.env --output=build/phase62-live/web
python scripts/phase62_verification.py --chrome '<chrome.exe>' --build build/phase62-live/web --out build/phase62-proof
```
