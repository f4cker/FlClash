import 'package:fl_clash/widgets/version_label.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const build = TextStyle(color: Color(0xFF000001));

  test('a build label sets its build apart in one span', () {
    final span = versionLabelSpan('1.0.0+2026111903', buildStyle: build);
    expect(span.text, '1.0.0');
    final child = span.children!.single as TextSpan;
    expect(child.text, ' (2026111903)');
    expect(child.style, build);
    expect(versionLabelSpan('1.0.0', buildStyle: build).children, isEmpty);
  });

  test('message placeholders take version spans in their own order', () {
    final span = versionMessageSpan(
      (slots) => 'Current: ${slots[0]}\nAvailable: ${slots[1]} · Beta',
      ['0.9.0+1', '1.0.0-beta.1+2'],
      buildStyle: build,
    );
    expect(
      span.toPlainText(),
      'Current: 0.9.0 (1)\nAvailable: 1.0.0-beta.1 (2) · Beta',
    );
    final versions = span.children!
        .whereType<TextSpan>()
        .where((child) => child.children?.isNotEmpty ?? false)
        .map((child) => child.text);
    expect(versions, ['0.9.0', '1.0.0-beta.1']);
  });
}
