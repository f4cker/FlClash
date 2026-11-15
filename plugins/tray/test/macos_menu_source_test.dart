import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String name) {
  final relative = 'macos/tray/Sources/tray/$name.swift';
  final direct = File(relative);
  return (direct.existsSync() ? direct : File('plugins/tray/$relative'))
      .readAsStringSync();
}

void main() {
  final menu = _source('TrayMenu');
  final view = _source('TrayMenuItemView');
  final plugin = _source('TrayPlugin');
  final segments = _source('TrayMenuSegmentsView');

  test('segments use confirmed state and selectable button accessibility', () {
    expect(
      segments,
      contains('segment.selected = entry["checked"] as? Bool == true'),
    );
    expect(segments, contains('setAccessibilityRole(.button)'));
    expect(segments, contains('setAccessibilitySelected(selected)'));
    expect(segments, contains('setAccessibilityEnabled(enabled)'));
    expect(segments, contains('override func accessibilityPerformPress()'));
    expect(segments, contains('notification: .valueChanged'));
    final activation = segments.substring(
      segments.indexOf('private func activate('),
      segments.indexOf('func activateFocused'),
    );
    expect(activation, isNot(contains('selected =')));
    expect(activation, contains('onSelect(id)'));
    expect(segments, isNot(contains('checkmark')));
    expect(segments, isNot(contains('NSSegmentedControl')));
    expect(segments, contains('alert.messageText = error'));
  });

  test('segment keyboard focus is separate and preserves other menu keys', () {
    expect(segments, contains('case 123, 124:'));
    expect(segments, contains('case 36, 49, 76:'));
    expect(segments, contains('self.activateFocused()'));
    expect(segments, contains('self.refreshFocus()'));
    expect(segments, contains('default:\n                return event'));
    expect(segments, contains('NSEvent.removeMonitor(monitor)'));
    expect(menu, contains('TrayMenuSegmentsView)?.updateHighlight(true)'));
    expect(menu, contains('TrayMenuTopology.grouped(items)'));
    expect(menu, contains('self.onSelect(id, self.generation)'));
    expect(menu, contains('child["id"] = old["id"]'));
  });

  test('segments share menu geometry and use neutral light and dark fills', () {
    expect(segments, contains('NSFont.menuFont(ofSize: max(13,'));
    expect(segments, contains('bounds.insetBy(dx: 5, dy: 4)'));
    expect(segments, contains('track.layer?.cornerRadius = 8'));
    expect(segments, contains('layer?.cornerRadius = 5'));
    expect(segments, contains('cornerCurve = .continuous'));
    expect(segments, contains('dark ? 0.17 : 0.82'));
    expect(segments, contains('white.withAlphaComponent(0.07)'));
    expect(segments, contains('black.withAlphaComponent(0.05)'));
    expect(segments, contains('white.withAlphaComponent(0.08)'));
    expect(segments, contains('black.withAlphaComponent(0.04)'));
    expect(segments, contains('.foregroundColor: NSColor.labelColor'));
    expect(segments, isNot(contains('controlAccentColor')));
    expect(segments, contains('borderWidth = keyboardFocused ? 2 : 0'));
  });

  test(
    'native menu retains titles, checkbox state, actions and actual submenus',
    () {
      expect(menu, contains('item.title = entry["label"]'));
      expect(menu, contains('item.state = type == "checkbox"'));
      expect(menu, contains('item.target = self'));
      expect(menu, contains('item.action = #selector(didSelectItem(_:)'));
      expect(menu, contains('setSubmenu(TrayMenu('));
      expect(menu, contains('guard sender.isEnabled else'));
      expect(view, contains('autoresizingMask = [.width]'));
      expect(view, isNot(contains('override func keyDown')));
    },
  );

  test(
    'normal rows remain transparent and highlighted rows use AppKit selection',
    () {
      expect(view, contains('selection.material = .selection'));
      expect(view, contains('selection.blendingMode = .withinWindow'));
      expect(view, contains('selection.isEmphasized = true'));
      expect(view, contains('selection.isHidden = true'));
      expect(view, isNot(contains('controlAccentColor')));
      expect(view, isNot(contains('NSGlassEffectView')));
      expect(menu, contains('updateHighlight(true)'));
    },
  );

  test(
    'native layout shares one leading slot without a system state column',
    () {
      expect(menu, contains('isSubmenu ? 420 : 380'));
      expect(menu, contains('showsStateColumn = false'));
      expect(menu, isNot(contains('minimumWidth = 320')));
      expect(menu, contains('min(maximumWidth, measuredContents.map'));
      expect(
        view,
        contains('} else if !content.isCheckbox, let icon = content.icon'),
      );
      expect(view, isNot(contains('stateX')));
      expect(view, isNot(contains('iconX')));
      expect(view, contains('x: metrics.leadingX + (metrics.leadingWidth'));
      expect(view, contains('NSRect(x: metrics.leadingX,'));
      expect(view, contains('leadingX + leadingWidth + titleGap'));
      expect(view, contains('detailGap: CGFloat = 12'));
      expect(
        view,
        contains('lineBreakMode: NSLineBreakMode = .byTruncatingTail'),
      );
      expect(view, contains('drawSymbol(Self.arrow'));

      for (final metric in [
        'leadingX: CGFloat = 12',
        'leadingWidth: CGFloat = 16',
        'titleGap: CGFloat = 8',
        'height = 28',
        'height = 26',
        'font.pointSize + 10',
      ]) {
        expect(view, contains(metric));
      }
      expect(view, contains('min(110, Self.width(detail'));
      expect(view, contains('label.filter(\\.isNumber).count >= 5 ? 76 : 60'));
      expect(view, contains('width - 12'));
    },
  );

  test(
    'PNG bytes are bounded and decoded locally without template tinting',
    () {
      expect(view, contains('Data(base64Encoded: encoded)'));
      expect(
        view,
        contains('data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10])'),
      );
      expect(view, contains('image.isTemplate = false'));
      expect(view, contains('encoded.utf8.count <= 2_800_000'));
      expect(
        view,
        contains('font: .systemFont(ofSize: 10, weight: .semibold)'),
      );
      expect(view, isNot(contains('URL(')));
      expect(view, isNot(contains('URLSession')));
    },
  );

  test(
    'full AX labels and native action forwarding preserve checkbox semantics',
    () {
      for (final source in [
        'toolTip = content.fullLabel',
        'setAccessibilityLabel(content.fullLabel)',
        'setAccessibilityEnabled(content.enabled)',
        'setAccessibilitySelected(content.checked)',
        'override func accessibilityPerformPress()',
        'override func accessibilityPerformShowMenu()',
        'setAccessibilityChildren([submenu])',
        'NSApp.sendAction(action, to: item.target, from: item)',
      ]) {
        expect(view, contains(source));
      }
    },
  );

  test(
    'native selection echoes the generation of the reconciled or retained menu',
    () {
      expect(
        plugin,
        contains('let generation = arguments["menuGeneration"] as? Int ?? 0'),
      );
      expect(
        plugin,
        contains('arguments: ["id": id, "menuGeneration": selectedGeneration]'),
      );
    },
  );
  test(
    'same-identity rows reconcile native and drawn state without replacing tracked views',
    () {
      expect(menu, contains('if TrayMenuTopology.matches(entries, items)'));
      expect(
        menu,
        contains('old["label"] as? String == new["label"] as? String'),
      );
      expect(menu, contains('old["id"] as? Int == new["id"] as? Int'));
      expect(menu, contains('submenu.apply(items:'));
      expect(menu, contains('TrayMenu.configure(item, entry)'));
      expect(menu, contains('contents[index] = content'));
      expect(
        menu,
        contains('(item.view as? TrayMenuItemView)?.update(content: content)'),
      );
      expect(view, contains('private var content: Content'));
      expect(view, contains('self.content = content'));
      expect(view, contains('updateAccessibility()'));
      expect(view, contains('canvas.needsDisplay = true'));
      expect(view, contains('notification: .valueChanged'));
      final apply = menu.substring(
        menu.indexOf('private func apply'),
        menu.indexOf('func prepareForOpening'),
      );
      expect(apply, isNot(contains('item.view =')));
      expect(apply, isNot(contains('addItem(')));
      expect(
        plugin,
        contains('active.reconcile(items: items, generation: generation)'),
      );
      expect(menu, contains('if item.view == nil, let content = content'));
    },
  );

  test(
    'active desired and closed sessions retain distinct callback generations',
    () {
      expect(plugin, contains('private var trackingMenu: TrayMenu?'));
      expect(plugin, contains('private var closedMenu: TrayMenu?'));
      expect(plugin, contains('closedMenu = active'));
      expect(plugin, contains('closedGeneration = generation'));
      expect(
        plugin,
        contains(
          '[menu?.generation, trackingMenu?.generation, closedGeneration]',
        ),
      );
      expect(plugin, contains('channel.invokeMethod("onMenuGenerations"'));
      expect(menu, contains('onSelect(sender.tag, generation)'));
      expect(menu, contains('onClose?(generation)'));
      expect(
        plugin,
        contains(
          'DispatchQueue.main.async { [weak self] in self?.presentMenu() }',
        ),
      );
      final presentation = plugin.substring(
        plugin.indexOf('private func presentMenu()'),
        plugin.indexOf('private func makeStatusItem()'),
      );
      expect(
        presentation.indexOf('menu.prepareForOpening()'),
        lessThan(presentation.indexOf('trackingMenu = menu')),
      );
    },
  );

  test('highlight text is semantic and long delay digits keep the badge font', () {
    expect(
      view,
      contains(
        'highlighted ? NSColor.selectedMenuItemTextColor : Self.readable(icon.foreground',
      ),
    );
    expect(
      view,
      contains(
        'highlighted ? NSColor.selectedMenuItemTextColor : Self.readable(badge.foreground',
      ),
    );
    expect(view, isNot(contains('highlighted ? NSColor.white :')));
    expect(
      view,
      contains(r'max(label.filter(\.isNumber).count >= 5 ? 76 : 60, measured)'),
    );
    expect(
      view,
      contains(
        'font: Self.badgeFont, alignment: .right, lineBreakMode: .byTruncatingMiddle',
      ),
    );
    expect(view, isNot(contains('Self.badgeFont.pointSize *')));
  });
  test(
    'structural updates patch shared rows without changing retained tags or generation',
    () {
      expect(menu, contains('reconcileRetained(items: items)'));
      expect(
        menu,
        contains(
          'TrayMenuTopology.sharedIndex(entry, current: original, desired: desired)',
        ),
      );
      expect(menu, contains('entry["id"] = original[index]["id"]'));
      expect(menu, contains('entry["enabled"] = false'));
      expect(menu, contains('&& initiallyEnabled[index]'));
      expect(menu, contains('initiallyEnabled.append(item.isEnabled)'));
      expect(menu, contains('item.isEnabled = false'));
      expect(menu, contains('current.filter(sameIdentity).count == 1'));
      expect(menu, contains('matches.count == 1 ? matches[0] : nil'));
      expect(
        plugin,
        contains('arguments["trackingGeneration"] = active.generation'),
      );
      final partial = menu.substring(
        menu.indexOf('private func reconcileRetained'),
        menu.indexOf('private func apply'),
      );
      expect(partial, isNot(contains('self.generation =')));
      expect(partial, isNot(contains('addItem(')));
      expect(partial, isNot(contains('item.view =')));
    },
  );
}
