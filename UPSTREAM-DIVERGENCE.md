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

## 7. 2026-11-25 sync: what was taken from `41b05838..d7e0cb5c`

- Files: see each commit on `sync/upstream-20261125`; every pick is
  `cherry-pick -x` and carries a `Flash:` note where it was adapted.
- Upstream: 52 commits on `dev` after `41b05838`, up to `d7e0cb5c`.
- Flash decision:
  - Taken as is: `1a57072d`, `fee1b89f`, `a588140a`, `7a63bb47`,
    `f95f0f1c`, `6fc66dd6`, `1c4a5e25`, `44c88645`, `9b01010a`,
    `da96bd09`, `e6d330d5`, `49fc786c`, `c5c7ef0e`.
  - Adapted: `18eaaea7` (Flash's MITM, capture and module strings win
    where both changed), `fac7b07d` (on Flash's `_beginStart` and
    composition review; `needInitStatus` stays), `932826b5` and `06643c36`
    (test doubles get Flash's signatures), `83214b6c` (prism_ui pinned to
    Flash's integration merge, see section 9), `94288d79` (taken despite the
    skip list: the prism_ui pin removes the old unfold widgets and
    `e21abb48` builds on it; Flash's header with node fields and stacked
    actions stays), `a27fab5e` (compact text scale on Flash's own detail
    views; upstream's detail files stay out), `e21abb48` (the header cover
    keeps Flash's wrapped `headerHeight`), `edc67090` (the tick still waits
    for Flash's deferred running publication), `b2267cbc` (resources page
    keeps its read-failure banner), `8eb40a94` (list editor and covered-page
    tests only), `7393ea46` (regenerated providers), `09818359`
    (`Cargo.lock` without upstream's `gdk-pixbuf-sys`), `9281e122` (on
    `MitmView`), `c8d1e9d0` (Flash schema, restore commits and digest sink
    kept), `d6959982` (Flash's routing-rules row uses the builder too),
    `066d5cca` (without the connection filter test).
  - Flash follow-ups: `test(dashboard)` expects the one-minute recheck after
    a timeout (`a588140a`), `test(setup)` waits for the tick's traffic read
    (`edc67090`), `chore(build)` regenerates the setup provider hash,
    `build(prism_ui)` keeps the dock (section 9), `fix(requests)` lets the
    live feed use prism's own loading spinner (section 9).
  - Skipped, upstream-only targets: `bfa6a033`, `dfddcc44`, `048d88e3`,
    `784533f1`, `255fcadf`, `cd6326a8`, `d7e0cb5c` (section 10), and the
    request list commits in section 8.
  - Skipped by decision: `73a0182f`, `7b97a687`, `14e87f46` (update channel,
    section 3), `7f5972ca` (macOS swap script tests for upstream's
    updater), `219bc95a`, `32e40e42`, `6df83255`, `4abbd15a` (phone dock and
    navigation), `6e57e26a` (hooks).
- On sync: start the next range at `d7e0cb5c`.

## 8. Upstream request lists after 2026-11-23

- Files: `lib/views/connection/requests.dart`,
  `lib/views/dashboard/widgets/connections_table.dart`.
- Upstream: `76e0ac4c` and `3a1c050e` (HTTP segment), `bf6c3c28` (status
  segment size), `8682368b` (dashboard opens live connections on Active),
  `617223a0` (a status's own empty state), `2d1126f8` (counted status menu,
  one-line records, `record_label_line.dart`).
- Flash decision: not taken. They build on upstream's page (segments,
  `http_capture.dart`, `connection_filter_row.dart`, `connection_filters.dart`,
  `http_requests.dart`, `dns_queries.dart`), which Flash does not carry
  (section 2). Flash's dashboard already opens live connections on its live
  feed (`RequestFeed.live`), which is what `8682368b` fixes upstream.
- On sync: same as section 2; adopting the counted status menu would be its
  own change on Flash's page.

## 9. prism_ui integration branch for 2026-11-25

- Files: `plugins/prism_ui` (branch `flash/upsync-20261125`).
- Upstream: prism_ui `cae9a435`, the pin of FlClash `d7e0cb5c`.
- Flash decision: `aac2e14` merges `cae9a435` into Flash's `54de34c5`
  (no rebase). Conflicts: `null_status.dart` drops `holdsArrival` and keeps
  Flash's `animate`; `segmented_control.dart` keeps Flash's dense insets
  beside upstream's `_labelInsetOf`; `popup.dart` takes upstream's item
  detail and keeps `labelEmphasized`, `labelTrailing` and `leading`.
  `31ed1e4` then restores `navigation_dock.dart` to `54de34c5`, so the phone
  dock keeps Flash's layout while `219bc95a`, `6df83255` and `4abbd15a`
  stay skipped. With `holdsArrival` gone a loading page opens at once behind
  a spinner; Flash's live feed no longer passes its own spinner as the
  loading status, since prism waits for a caller's spinner to stop before it
  reveals the content.
- On sync: merge the next upstream prism_ui into `flash/upsync-20261125`'s
  tip and keep `navigation_dock.dart` unless the dock commits are taken.

## 10. Connection detail spacing that targets upstream's detail views

- Files: `lib/features/connection/tracker_info_item.dart`,
  `lib/features/connection/detail_tabs.dart`, `lib/widgets/record.dart`.
- Upstream: `bfa6a033` (4 dp under titles via `RecordLabelLine` and
  `DetailHeader`), `dfddcc44` and `255fcadf` (tabular hop delays in
  `tracker_info_detail.dart`), `048d88e3` (detail head gap),
  `784533f1` (docs for that spacing), `cd6326a8` and `d7e0cb5c` (tests for
  upstream rows and filters).
- Flash decision: not taken. Flash keeps its own record rows and detail view
  (route reasons, skipped rules, node badges) and has no detail head, hop
  delay row or `RecordLabelLine`; its custom profile members already leave
  4 dp. `784533f1` would document spacing Flash does not use.
- On sync: re-check if Flash adopts upstream's detail views.
