import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';

const _longHost =
    'a-very-long-decrypted-hostname.api.edge.static.cdn.example-content.com';

TrackerInfo _tracker(
  String id, {
  String host = _longHost,
  bool mitm = true,
  MitmConnectionRewrite? rewrite,
}) => TrackerInfo(
  id: id,
  start: DateTime(2026, 1, 1, 10, 30),
  metadata: Metadata(
    network: 'tcp',
    host: host,
    destinationIP: '1.1.1.1',
    destinationPort: '443',
    process: 'curl',
    mitm: mitm,
  ),
  chains: const ['DIRECT'],
  rule: 'MATCH',
  rulePayload: '',
  mitmRewrite: rewrite,
);

void main() {
  late bool feature;

  setUp(() => feature = mitmFeature);
  tearDown(() => mitmFeature = feature);

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget child, {
    bool mitmEnabled = true,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(patchClashConfigProvider, (_, _) {});
    container.read(patchClashConfigProvider.notifier).value = PatchClashConfig(
      mitm: Mitm(enable: mitmEnabled),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          homeBuilder: (child) => HostScaffold(body: child),
          child: child,
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  Finder hostText(String host) =>
      find.textContaining(host, findRichText: true).first;

  RenderParagraph paragraphOf(
    WidgetTester tester,
    String host,
  ) => tester.renderObject<RenderParagraph>(
    find
        .byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains(host),
        )
        .first,
  );

  testWidgets('a table cell puts the decryption mark before the host, and '
      'only the host gives way', (tester) async {
    await pump(
      tester,
      SizedBox(
        width: 220,
        child: TrackerTargetText(
          _tracker('a', rewrite: const MitmConnectionRewrite(applied: true)),
        ),
      ),
    );

    final badge = tester.getRect(find.byGlyph(MitmBadge.decrypted.glyph));
    final host = tester.getRect(hostText(_longHost));
    final rewrite = tester.getRect(
      find.byGlyph(MitmRewriteBadge.applied.glyph),
    );
    expect(badge.left, 0);
    expect(badge.width, MitmBadge.iconSize);
    expect(host.left, MitmBadgeSlot.width);
    expect(badge.right, lessThanOrEqualTo(host.left));
    // The rewrite mark stays on its own, after the host, and in view.
    expect(rewrite.left, greaterThanOrEqualTo(host.right));
    expect(rewrite.right, lessThanOrEqualTo(220));
    expect(paragraphOf(tester, _longHost).didExceedMaxLines, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row without a mark keeps the place while decryption is on, '
      'so hosts line up', (tester) async {
    mitmFeature = true;
    await pump(
      tester,
      SizedBox(
        width: 400,
        child: Column(
          children: [
            TrackerTargetText(_tracker('a', host: 'decrypted.test')),
            TrackerTargetText(_tracker('b', host: 'plain.test', mitm: false)),
          ],
        ),
      ),
    );

    expect(
      tester.getRect(hostText('plain.test')).left,
      tester.getRect(hostText('decrypted.test')).left,
    );
    expect(find.byGlyph(MitmBadge.decrypted.glyph), findsOneWidget);
  });

  testWidgets('with decryption off a row without a mark keeps no place', (
    tester,
  ) async {
    mitmFeature = true;
    await pump(
      tester,
      SizedBox(
        width: 400,
        child: TrackerTargetText(
          _tracker('b', host: 'plain.test', mitm: false),
        ),
      ),
      mitmEnabled: false,
    );

    expect(tester.getRect(hostText('plain.test')).left, 0);
  });

  testWidgets('a card keeps the app icon first, then the mark, then the host, '
      'the only part that truncates', (tester) async {
    await pump(
      tester,
      SizedBox(
        width: 320,
        child: TrackerInfoItem(
          trackerInfo: _tracker('a'),
          detailTitle: 'detail',
          isLive: true,
        ),
      ),
    );

    final badge = tester.getRect(find.byGlyph(MitmBadge.decrypted.glyph));
    final host = tester.getRect(hostText(_longHost));
    final icon = tester.getRect(find.byType(ProcessIcon).first);
    expect(icon.right, lessThanOrEqualTo(badge.left));
    expect(badge.right, lessThanOrEqualTo(host.left));
    expect(badge.right, lessThan(320));
    expect(paragraphOf(tester, _longHost).didExceedMaxLines, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a card without a report has no mark', (tester) async {
    await pump(
      tester,
      SizedBox(
        width: 320,
        child: TrackerInfoItem(
          trackerInfo: _tracker('a', mitm: false),
          detailTitle: 'detail',
        ),
      ),
    );

    expect(find.byGlyph(MitmBadge.decrypted.glyph), findsNothing);
  });
}
