import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/views/profiles/edit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an edit its mounts refuse is held with the reason', () async {
    expect(
      await mountEditIssue(() async => 'mount source 2 is missing'),
      '${currentAppLocalizations.profileEditMountRejected}\n'
      'mount source 2 is missing',
    );
  });

  test('an edit that passes, or has no mounts, saves as before', () async {
    expect(await mountEditIssue(() async => null), isNull);
  });

  test('a preflight that cannot run does not hold the edit', () async {
    expect(
      await mountEditIssue(() async => throw StateError('core gone')),
      isNull,
    );
  });
}
