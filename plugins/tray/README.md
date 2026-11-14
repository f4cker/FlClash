# tray

System tray integration for FlClash on Linux, macOS and Windows.

## API

The plugin owns call ordering, idempotency, call serialization and unchanged-payload suppression.
Callers declare the desired tray state; they never sequence platform calls themselves.

```dart
await Tray.instance.show(
  TraySpec(
    icon: TrayIcon.asset('assets/images/tray/unix/status_1.png', isTemplate: true),
    toolTip: 'FlClash',
    menu: [
      TrayMenuAction(label: 'Show', onSelected: showWindow),
      const TrayMenuSeparator(),
      TrayMenuCheckbox(label: 'TUN', checked: true, onSelected: toggleTun),
      TrayMenuSubmenu(label: 'Proxy', items: proxyItems),
    ],
  ),
);

await Tray.instance.setTitle('↑ 1.2 MB/s');
await Tray.instance.hide();
```

- `show` creates the tray on first call and reconciles it afterwards. Re-sending a structurally
  identical `TraySpec` performs no platform call, so callbacks may be rebuilt freely.
- `setTitle` is the incremental path for high-frequency text. It is a no-op where
  `capabilities.title` is false, and while no tray is visible.
- `hide` is idempotent and returns native state to "`show` was never called", so a later `show`
  rebuilds the tray from scratch.
- `openMenu` is a no-op where `capabilities.menuControl` is false.

`TrayIcon.asset` names a bundled PNG and follows Flutter's resolution-aware layout: every
`2.0x/`, `3.0x/`, `4.0x/` sibling that exists is loaded too. macOS receives them all as
representations of one `size`-point image; Linux is handed the largest raster on disk and lets the
indicator scale it; Windows loads the path as-is, so point it at a multi-size `.ico` instead.

Menu item ids are assigned by pre-order position, so an unchanged menu serializes identically across
rebuilds. On macOS each menu also has an internal generation. Updates to the same ordered row identities
(type, label, ID and recursive submenu structure) reconcile the retained native items and views live,
including badges, enabled/check state, tooltips and accessibility metadata, without resizing tracked rows.
Structural changes become the desired menu for the next open. Unique shared rows within each parent
still update their presentation and enabled/check state live, preserving retained tags and callbacks;
removed or ambiguous rows are disabled, never guessed. Rows initially disabled in a structurally retained
session stay disabled until reopening; rows initially enabled can safely disable and re-enable. New rows
are not inserted during tracking.
The active callback snapshot mirrors those enabled/removed states, so an old positional ID cannot target
an inserted or reordered desired row. Native references
retain only desired, active and most recently closed generations; the closed snapshot and native tree
survive `menuDidClose`, since AppKit can deliver its action afterwards. Unchanged payloads refresh callbacks
without a native show. Disabled actions and checkboxes cannot dispatch callbacks or selection events,
even from a programmatic event.

Actions, checkboxes and submenus take an optional `detail`, secondary text shown after the label, such as
a shortcut or a measured latency:

| macOS | Windows | Linux |
| --- | --- | --- |
| right-aligned column in the color of a native key equivalent | the menu's accelerator column | appended in parentheses |

AppIndicator menus travel over dbusmenu, which carries no column for free text, hence the Linux fallback.

## macOS menu presentation

Actions, checkboxes and submenus additionally accept `TrayMenuIcon? icon`, `TrayMenuBadge? badge`, and
`String? accessibilityLabel`. These are additive; Linux and Windows ignore them and keep `detail`'s
existing plain-text behavior. Colors are resolved ARGB32 integers, not Flutter `Color` objects.

```dart
const TrayMenuAction(
  label: 'Hong Kong',
  icon: TrayMenuIcon(monogram: 'HK', background: 0xffeeeeee, foreground: 0xff333333),
  badge: TrayMenuBadge(label: '88 ms', background: 0xffe1f5e8, foreground: 0xff185c30),
  accessibilityLabel: 'Hong Kong, latency 88 milliseconds',
);
```

`TrayMenuIcon.pngBytes` optionally supplies local PNG bytes, serialized as base64 `png`; no URL or
network lookup occurs. Valid PNGs retain their original colors at 16 pt. Missing, malformed or oversized
images fall back to the 10 pt semibold monogram. Native colors are validated with safe defaults and
contrast fallback. Badges use 12 pt medium monospaced digits, 6 × 2 pt padding, radius 5 and a 46 pt
minimum width. Delay columns reserve at least 60 pt, or 76 pt for five or more digits, and grow to the measured
label width before sacrificing title space. The badge font never shrinks. Only a label exceeding the
entire available row budget uses middle truncation, preserving its trailing units and full AX label.

Root custom row widths are bounded to 320–380 pt, submenu rows to 320–420 pt. Titles share one leading
column across commands and groups, with separate check and icon slots. Plain details have at most
110 pt and truncate; full names and details remain in tooltips and accessibility labels. Rows use the
13 pt menu font (or the larger system menu font), heights 28 pt on macOS 26 and 26 pt on earlier macOS,
and never less than the font size plus 10 pt.

`NSMenu` owns the menu surface and tracking. Normal custom rows are transparent. The only effect view
is the highlighted row's `NSVisualEffectView` with `.selection`, `.withinWindow` and `isEmphasized`;
the installed AppKit SDK documents `.selection` as the material for selection in tables and menus.
There is no full-menu card, extra glass background, or opaque manually painted accent selection.

The existing custom-view route is retained because it positions trailing details and badges together.
As documented in Apple's [Views in Menu Items](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MenuList/Articles/ViewsInMenuItems.html),
AppKit keeps key equivalents and type-selection, but custom views do not receive keyboard events.
Native `NSMenuItem` titles, checkbox states, targets/actions, and real submenus remain intact; accessibility
presses forward to the native action, and submenu presses expose the actual submenu. No key-event
replacement is installed. Row identities and geometry stay fixed during tracking, but compatible content
updates redraw live. Geometry is measured again before the next open; structural replacements are deferred.
Opening is scheduled after the method reply so native tracking cannot block subsequent serialized shows.

**Actual Mac validation is pending:** light/dark appearance, selection material and text contrast,
Reduce Transparency/Increase Contrast, enlarged fonts, keyboard navigation/checks/submenu arrows,
VoiceOver labels/state/press/submenu traversal, long titles and delay units, and updates during tracking.
Dart tests, native source assertions and standalone Swift checks do not establish those runtime results.

## Events

`Tray.instance.events` is a broadcast stream of `TrayIconActivated`, `TrayMenuRequested` and
`TrayMenuItemSelected`. Per-item `onSelected` callbacks fire before the corresponding stream event.
On Windows a left click is `TrayIconActivated` and a right click `TrayMenuRequested`; macOS opens the
menu from either button, as status items do there, so it only sends `TrayMenuRequested`.

## Capabilities

`Tray.instance.capabilities` reports what the current platform can do, so callers branch on ability
rather than on `Platform.isX`.

| | macOS | Windows | Linux |
| --- | --- | --- | --- |
| `title` | yes | no | yes |
| `toolTip` | yes | yes | yes |
| `iconEvents` | yes | yes | no |
| `menuControl` | yes | yes | no |

Linux runs on AppIndicator/StatusNotifierItem, where the desktop shell owns the menu; the application
cannot receive icon clicks or open the menu itself.

## Linux requirements

`libayatana-appindicator3-dev`, or `libappindicator3-dev` as a fallback.
