import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

class _GeoReview extends SetupAction {
  Future<bool> open() => super.reviewComposition(
    '''
geox-url: {geoip: synthetic-equal, generated: synthetic-unknown}
''',
    pagePaths: {'geox-url', 'geox-url.geoip'},
    basePaths: {'geox-url.geoip'},
  );
}

void main() {
  testWidgets('GeoX child is Page even when file value is equal', (
    tester,
  ) async {
    final review = _GeoReview();
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        child: Center(
          child: GestureDetector(
            onTap: () async {
              await review.open();
            },
            child: const Text('Review GeoX'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review GeoX'));
    await tester.pumpAndSettle();
    final strings = currentAppLocalizations;
    expect(
      find.text('geox-url.geoip: "synthetic-equal" · ${strings.sourcePage}'),
      findsOneWidget,
    );
    expect(
      find.text('geox-url.geoip: "synthetic-equal" · ${strings.sourceBase}'),
      findsNothing,
    );
    expect(
      find.text(
        'geox-url.generated: "synthetic-unknown" · '
        '${strings.compositionSourceUnconfirmed}',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(strings.cancel));
    await tester.pumpAndSettle();
  });
}
