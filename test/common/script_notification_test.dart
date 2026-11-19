import 'package:fl_clash/common/script_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a script notification needs some text and falls back to the name', () {
    expect(ScriptNotification.fromData({'script': 'a'}), isNull);
    expect(ScriptNotification.fromData('text'), isNull);
    final notification = ScriptNotification.fromData({
      'script': '比价',
      'body': '降价了',
      'subtitle': 7,
    })!;
    expect(notification.toArguments(), {
      'script': '比价',
      'title': '比价',
      'subtitle': '',
      'body': '降价了',
    });
  });
}
