import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/rules/rule_rows.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));
  const all = RulesBelow.values;

  test('the note names only the sources under it, the last after "and"', () {
    expect(rulesBelowText(zh, all), '以下是订阅配置、扩展脚本和模块的规则。');
    expect(
      rulesBelowText(zh, const [RulesBelow.subscription, RulesBelow.module]),
      '以下是订阅配置和模块的规则。',
    );
    expect(rulesBelowText(zh, const [RulesBelow.subscription]), '以下是订阅配置的规则。');
    expect(
      rulesBelowText(en, all),
      'The rules below come from the subscription profile, extension '
      'scripts and modules.',
    );
  });

  test('each source kind falls under one name', () {
    expect(
      rulesBelowOf(const RuleSource(kind: RuleSourceKind.custom)),
      RulesBelow.subscription,
    );
    expect(
      rulesBelowOf(const RuleSource(kind: RuleSourceKind.mitm)),
      RulesBelow.module,
    );
    expect(
      rulesBelowOf(const RuleSource(kind: RuleSourceKind.addedProfile)),
      isNull,
    );
    expect(rulesBelowOf(null), isNull);
  });
}
