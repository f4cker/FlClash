import 'package:fl_clash/l10n/l10n_en.dart';
import 'package:fl_clash/l10n/l10n_zh.dart';
import 'package:fl_clash/plugins/mac_updater.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final zh = AppLocalizationsZh();
  final en = AppLocalizationsEn();
  const location =
      '/Users/u/Library/Application Support/Flash/update-rescue/Flash-100.app';

  MacUpdateResult answer(Map<String, Object> fields) =>
      MacUpdateResult.fromAnswer(fields);

  group('macUpdateMessage', () {
    test('names the kept copy only when it was found after the move', () {
      final kept = answer({
        'code': 'rollbackFailed',
        'detail': 'installed app signature: x; swap back: Resource busy',
        'rescued': location,
        'rescueMoved': true,
        'rescueVerified': true,
      });
      expect(macUpdateMessage(kept, zh), '更新未完成，也未能自动恢复原版本。原版本保存在「$location」。');
      expect(macUpdateMessage(kept, en), contains(location));
      expect(kept.details, contains('swap back: Resource busy'));
      expect(kept.details, contains(location));

      for (final unverified in [
        answer({
          'code': 'rollbackFailed',
          'rescued': location,
          'rescueVerified': false,
        }),
        answer({'code': 'rollbackFailed', 'rescueVerified': true}),
        answer({'code': 'rollbackFailed'}),
      ]) {
        expect(macUpdateMessage(unverified, zh), '更新未完成，也未能自动恢复原版本。请查看详情。');
        expect(macUpdateMessage(unverified, zh), isNot(contains('保存')));
        expect(macUpdateMessage(unverified, en), isNot(contains('saved')));
      }
    });

    test('says the previous version is unchanged only when confirmed', () {
      for (final code in ['swapFailed', 'unpackFailed', 'failed', 'odd']) {
        expect(
          macUpdateMessage(answer({'code': code, 'unchanged': true}), zh),
          '更新未完成，原版本未更改。请查看详情。',
          reason: code,
        );
        expect(
          macUpdateMessage(answer({'code': code}), zh),
          '更新未完成，请查看详情。',
          reason: code,
        );
        expect(
          macUpdateMessage(answer({'code': code, 'unchanged': false}), en),
          isNot(contains('unchanged')),
        );
      }
      expect(
        macUpdateMessage(const MacUpdateResult('failed'), zh),
        '更新未完成，请查看详情。',
      );
    });

    test('says the previous version was restored only when confirmed', () {
      expect(
        macUpdateMessage(answer({'code': 'rolledBack', 'unchanged': true}), zh),
        '更新未完成，已恢复原版本。',
      );
      expect(
        macUpdateMessage(answer({'code': 'rolledBack'}), zh),
        '更新未完成，请查看详情。',
      );
    });

    test('keeps codes out of the message and in the details', () {
      final result = answer({
        'code': 'swapFailed',
        'detail': 'Operation not permitted',
        'unchanged': true,
      });
      expect(macUpdateMessage(result, zh), isNot(contains('swapFailed')));
      expect(
        macUpdateMessage(result, zh),
        isNot(contains('Operation not permitted')),
      );
      expect(result.details, 'swapFailed\nOperation not permitted');
    });

    test('hints at the version record only for an installable update', () {
      const ready = MacUpdateResult(
        'ok',
        staged: '/Applications/.Flash-update-x/Flash.app',
        recordUnreadable: true,
      );
      expect(
        macUpdateReadyText(ready, '0.9.16', zh),
        '${zh.macUpdateReadyMessage('0.9.16')}\n\n${zh.macUpdateRecordHint}',
      );
      for (final notInstallable in const [
        MacUpdateResult('ok', recordUnreadable: true),
        MacUpdateResult('rejected', recordUnreadable: true),
        MacUpdateResult(
          'ok',
          staged: '/Applications/.Flash-update-x/Flash.app',
        ),
      ]) {
        expect(
          macUpdateReadyText(notInstallable, '0.9.16', zh),
          isNot(contains(zh.macUpdateRecordHint)),
        );
      }
      for (final code in ['notWritable', 'rejected', 'rollbackFailed']) {
        expect(
          macUpdateMessage(MacUpdateResult(code, recordUnreadable: true), zh),
          isNot(contains(zh.macUpdateRecordHint)),
        );
      }
    });

    test('uses the final copy for the install button and the core stop', () {
      expect(zh.macUpdateRestartNow, '退出并安装');
      expect(en.macUpdateRestartNow, 'Quit and install');
      expect(zh.macUpdateCoreStopFailed, '无法确认内核已停止，已取消安装更新。');
      expect(
        macUpdateMessage(const MacUpdateResult('coreStopFailed'), zh),
        zh.macUpdateCoreStopFailed,
      );
    });
  });
}
