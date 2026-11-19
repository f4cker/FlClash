# Deliberate divergences from upstream FlClash

Places where Flash intentionally keeps code that upstream (chen08209/FlClash)
removed or changed. Check every entry by hand on each upstream sync; do not
let a merge silently take upstream's side.

## 1. Resources status card in the live status deck

- Files: `lib/views/dashboard/widgets/live_status.dart` (`ResourcesStatus`,
  `_updatingResources`, its place in `composeLiveStatuses` and the bar
  entry) and `lib/views/dashboard/widgets/live_status_deck.dart` (the card:
  `_ResourcesHero`, `_ResourceRow`, the "View all" details list). Restored
  in Phase 2 (feat/upstream-sync-0.9.4).
- Upstream history: added in `a89b3399` ("gather live statuses into one bar
  button and alert-style card deck"), removed one day later in `c6d1b4da`
  ("show live status counts and progress, cycle the cards…", 2026-11-12) with
  no stated reason. Not present in upstream/main or upstream/dev as of
  `9f2759e2` / `5e579c49`.
- Flash decision (product, 2026-11-19): restore it. The user asked for core,
  update and resources to sit together in the one status entry, and the 0.9.4
  changelog promises resources there too.
- Scope: re-attach the card exactly as upstream had it in `a89b3399`, fed only
  by the existing `updatingKeysProvider` (profiles, geo resources,
  `provider_*`). No new download or refresh flow, no separate resources page.
  Order and count follow the same rules as the other cards (design spec).
- On sync: if upstream touches `live_status.dart` or the deck, re-check that
  the resources card still compiles against the new `LiveStatus` shape, still
  participates in ordering/counting, and that upstream has not reintroduced
  its own version (in which case drop ours and take theirs).
