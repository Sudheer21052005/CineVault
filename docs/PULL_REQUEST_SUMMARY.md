# CineVault upgrade pull request summary

**Review base** `7d9440c` on `main` · **Feature branch** `feature/ui-redesign`

CineVault has evolved from a movie and TV discovery watchlist into a responsive cinema reference and personal library. The upgrade preserves the original blue-and-gold identity, developer credit, Hive records, and achievement IDs.

## What changed

| Phase | Changes and evidence |
| --- | --- |
| Audit and roadmap | Documented the original architecture, TMDB coverage, performance baselines, UX issues, and upgrade gates. [Baseline audit](BASELINE_AUDIT.md) · [Upgrade plan](UPGRADE_PLAN.md) |
| Foundation | Split catalogue, transport, navigation, and storage boundaries. Removed the boot delay, fixed nested Back and search races, added typed routes, and made Hive writes safe and compatible with prior records. [Phase 1 results](PHASE1_RESULTS.md) |
| Responsive browsing | Added the shared cinematic design system, desktop sidebar, tablet rail, mobile navigation, featured Home, virtualized grids, adaptive artwork, and durable catalogue cache. [Phase 2 results](PHASE2_RESULTS.md) |
| Cinema knowledge graph | Added rich movie and TV metadata, credits, people and filmographies, collections, studios, networks, genres, keywords, episodes, reviews, trailers, and regional providers. Deep links and browser history support exploration across entities. [Phase 3 results](PHASE3_RESULTS.md) |
| Personal library | Added repeat-viewing diary, episode marks and schedules, custom lists, favorites, exploration history, source-linked suggestions, personal statistics, and JSON/CSV tools. [Phase 4 results](PHASE4_RESULTS.md) |
| Release hardening | Stabilized poster grid layout during scrolling, reduced unnecessary artwork invalidation, bounded repeated library projections and pagination scheduling, restored catalogue scroll keys, and polished route transitions. Made credentials opt-in at build time and added an Android signing gate and official TMDB mark. [Phase 5 results](PHASE5_RESULTS.md) |

## Review the upgrade

- Home and the catalogue at desktop, tablet, and phone widths. Check keyboard focus, image cropping, reduced motion, loading and retry, and stable position while paginating. [Responsive gallery](screenshots/phase2/breakpoints-gallery.jpg)
- Follow movie → cast → person → filmography → another movie, title → collection, and TV → season → episode → guest. Use browser Back/Forward, reload, and native system Back. [Graph gallery](screenshots/phase3/web-desktop-gallery.jpg)
- Use the Watchlist and personal library with a backed-up existing installation. Log a repeat viewing, mark an episode, and build a list before exporting and restoring. [Personal library gallery](screenshots/phase4/desktop-overview.jpg)
- Inspect the original developer and TMDB credits in About and JustWatch attribution in regional watch availability. [Provider verification](screenshots/phase3/regional-availability-desktop.jpg)

## Compatibility and rollout

- Legacy watchlist and achievement boxes retain their identifiers and adapter. Phase 4 data lives in the versioned `cinevault_personal_v1` box. The bounded catalogue cache can repopulate independently of the library.
- Create a JSON export before upgrading an installation with valuable data. Restores merge stable IDs and keep existing entries on conflicts. A prior version can continue reading the legacy boxes. Keep the JSON export when rolling back so newer personal records can be recovered in a later upgrade.
- Use credential-free release artifacts for distribution review. A local live build requires an explicit key. Use owner-controlled signing for an Android store build. Keep the original application ID for upgrades signed with the same certificate.
- Before distribution, close the remaining release checks in the Phase 5 matrix. The original repository has no project-level license file. The bundled fonts carry their own licenses and the TMDB mark is subject to TMDB’s attribution rules. Project licensing and distribution remain owner decisions.

## Release review results

The hardware Chrome comparison preserved the two-request fresh title budget and zero-request cached detail budget. Fresh runtime p95 improved from 169.3 to 133.1 ms. The median share of animation callbacks exceeding 16.7 ms during the 20-second scroll dropped from 3.36% to 2.72%. Cold Home p95 increased from 621.9 to 712.3 ms. Android and Windows picker round-trips used isolated test libraries.

[Phase 5 test matrix, benchmark comparisons, and remaining gates](PHASE5_RESULTS.md)
