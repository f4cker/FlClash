# Deliberate divergences from upstream FlClash

Places where Flash intentionally keeps code that upstream (chen08209/FlClash)
removed or changed. Check every entry by hand on each upstream sync; do not
let a merge silently take upstream's side.

Standing rule: 上游同步只跟踪 chen08209/FlClash 的 dev 分支，不再审计或合并上游
main（白小飞 2026-11-23）。

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

## 2. Requests page, large connection list and connection navigation

- Files: `lib/views/connection/requests.dart`, `lib/views/dns_queries.dart`,
  `lib/features/connection/*`, `lib/widgets/record_filter.dart`
  (`keywordsOf(pinned:)`, grouping), `lib/models/config.dart`
  (`requestFeed`, `recordGroupings`), `lib/enum/enum.dart` (`RequestFeed`,
  `RecordGrouping`), `lib/views/navigation.dart`,
  `lib/providers/state/navigation.dart`, `core/hooks.go`, `core/method.go`,
  `core/protocol.go`.
- Upstream (sync to `41b05838`, 2026-11-23): `9c931f74` turns connections into
  a requests page, `243c76c1` / `8736f487` redesign it around one list of open,
  closed and failed connections, `888a1df6` adds desktop app icons,
  `f18f92ef` / `46522eb5` move connections and logs in the navigation,
  `b3b32ae1` / `41b05838` mark MITM requests by what acted on them.
- Flash decision: keep Flash's own requests page and large-list work
  (`38f3b938` perf/conn-list). The upstream page, its models, app icons, the
  new navigation order and the MITM request marks are not taken; their
  strings are not added to `arb/`. In the Core, `tunnel.DefaultDialFailureNotify`
  stays unset (Flash reads every `RequestMessage` as an open connection) and
  `mitm.query` is not registered. `rule.list` is registered, but to Flash's
  own `handleListRules` (`core/rule_list.go`, the rules page's list,
  `lib/views/rules/rules.dart`), not to upstream's `handleGetRules`. The
  Core-side files upstream added (`dial_failure*.go`, `rule_index.go`,
  `dns_link.go`) are kept so later syncs merge cleanly. `RecordFilterController` gains upstream's `keywords` and
  `optionMenuItems()` so upstream's logs page (`0db670d4`, `ef7dc6ed`) runs on
  Flash's controller.
- On sync: re-check these files by hand; if upstream's page is to be adopted,
  do it as its own change, not inside a sync merge.

## 3. Update channel and release file names

- Files: `lib/common/app_update.dart`, `lib/common/request.dart`,
  `lib/common/package.dart`, `lib/common/release_asset.dart`, the settings
  page, `test/common/release_asset_test.dart`.
- Upstream: `562e11fe` (stable/prerelease channel setting), `afe71360` (open
  the release page when the update file is missing), `a8c4144e` /
  `816afbfd` (file names without the line, release contract check).
- Flash decision: Flash updates through its signed-manifest beta channel and
  publishes to flash-releases under its own names, so these are not taken.
  Upstream's CI and publish tooling (`tool/publish.dart`, `tool/src/publish/*`,
  `lib/common/release_version.dart`) is kept as is; it does not drive Flash
  releases. `test/common/release_version_test.dart` drops the
  `installedReleaseVersion` / `installedVersionLabel` groups that test
  upstream's updater.

## 4. Tray failure reporting

- Upstream `746f7b00` makes `show_tray` return why the tray failed. Flash's
  rust_api tray (v2, update arrow, decryption dot) diverged, so it is not
  taken in this sync; port it as a separate change if wanted.

## 5. MITM fixture host lint

- Upstream `20695e9b` adds `test/lint/mitm_fixtures_test.dart` and
  `test/lint/mitm_fixture_hosts.txt`, and `57abcd4a` renames its own MITM
  fixtures to neutral samples.
- Flash decision: not taken yet. About 15 Flash-only MITM test files (and
  `test/helpers/mitm_host_policy.dart`, which needs real Apple hosts) still use
  real hosts, so the lint would fail. Flash's MITM test files stay as they
  were. Moving the fixtures to reserved hosts and adding the lint is a
  separate change. `.agents/rules.md` says so.

## 6. Profile cards keep a 16 dp margin and row padding

- Upstream `79d5a598` / `8fc89098` set lists in by `context.listInsets`
  (20 dp on desktop). Flash takes that everywhere except the profiles grid
  (`lib/views/profiles/profiles.dart`): its cards carry Flash's mount pill,
  update time and groups chip, and `_pillBelowFor` measures the row with a
  16 dp margin and 16 dp row padding. With upstream's insets the pill
  overflows while a maximized window restores (`test/pages/home_test.dart`).
  Revisit if the card is redesigned.
