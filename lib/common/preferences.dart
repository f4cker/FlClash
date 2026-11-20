import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/boot_record.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/release_history.dart';
import 'package:fl_clash/common/system_dns.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_clash/common/system_proxy.dart' show SystemProxySnapshot;
import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static Preferences? _instance;
  static var _initialCompositionRevision = 0;

  var _store = ResolveOnce(_open);

  Future<bool> get isInit async => await _store.value != null;

  Preferences._internal();

  static Future<SharedPreferences?> _open() async {
    try {
      final store = await SharedPreferences.getInstance();
      _initialCompositionRevision =
          store.containsKey(configKey) || store.containsKey(clashConfigKey)
          ? 0
          : 1;
      if (_initialCompositionRevision == 1 &&
          !store.containsKey('compositionRevision')) {
        await store.setInt('compositionRevision', 1);
      }
      return store;
    } catch (_) {
      _initialCompositionRevision = 0;
      return null;
    }
  }

  @visibleForTesting
  Future<void> rebind() async {
    _store = ResolveOnce(_open);
    await _store.value;
  }

  factory Preferences() {
    _instance ??= Preferences._internal();
    return _instance!;
  }

  static const mitmSafetyLockKey = 'mitmSafetyLock';

  /// The settings copy of the MITM safety lock, read fresh from the store;
  /// null when the store cannot be opened.
  Future<String?> readMitmSafetyLock() async {
    final store = await _store.value;
    if (store == null) return null;
    await store.reload();
    return store.getString(mitmSafetyLockKey);
  }

  /// Whether [value] was saved and reads back fresh from the store.
  Future<bool> writeMitmSafetyLock(String value) async {
    final store = await _store.value;
    if (store == null) return false;
    if (!await store.setString(mitmSafetyLockKey, value)) return false;
    await store.reload();
    return store.getString(mitmSafetyLockKey) == value;
  }

  /// Whether the lock is gone, read back fresh from the store.
  Future<bool> clearMitmSafetyLock() async {
    final store = await _store.value;
    if (store == null) return true;
    await store.remove(mitmSafetyLockKey);
    await store.reload();
    return !store.containsKey(mitmSafetyLockKey);
  }

  Future<String?> getReleaseHistoryCache() async => (await _store.value)
      ?.getString('releaseHistoryCache:$releaseHistoryRepository');

  Future<void> saveReleaseHistoryCache(String value) async {
    await (await _store.value)?.setString(
      'releaseHistoryCache:$releaseHistoryRepository',
      value,
    );
  }

  Future<bool> getMacHelperInvitationShown() async {
    final store = await _store.value;
    return store == null ||
        (store.getBool('macHelperInvitationShown') ?? false);
  }

  Future<void> markMacHelperInvitationShown() async {
    final store = await _store.value;
    await store?.setBool('macHelperInvitationShown', true);
  }

  Future<int> getVersion() async {
    final preferences = await _store.value;
    return preferences?.getInt('version') ?? 0;
  }

  Future<void> setVersion(int version) async {
    final preferences = await _store.value;
    await preferences?.setInt('version', version);
  }

  Future<int> getUpgradeVersion() async {
    final preferences = await _store.value;
    return preferences?.getInt('upgradeVersion') ?? 0;
  }

  Future<void> setUpgradeVersion(int version) async {
    final preferences = await _store.value;
    await preferences?.setInt('upgradeVersion', version);
  }

  Future<void> saveShareState(SharedState shareState) async {
    final preferences = await _store.value;
    await preferences?.setString('sharedState', json.encode(shareState));
  }

  /// The md5 of the config.yaml the Core last accepted, which is also what
  /// the Android service applies when it starts without Flutter.
  Future<String?> getAppliedConfigMd5() async {
    final preferences = await _store.value;
    return preferences?.getString(appliedConfigMd5Key);
  }

  Future<void> saveAppliedConfigMd5(String? md5) async {
    final preferences = await _store.value;
    if (md5 == null) {
      await preferences?.remove(appliedConfigMd5Key);
    } else {
      await preferences?.setString(appliedConfigMd5Key, md5);
    }
  }

  Future<int> getCompositionRevision() async {
    try {
      final store = await _store.value;
      return store == null
          ? 0
          : store.getInt('compositionRevision') ?? _initialCompositionRevision;
    } catch (_) {
      // An unreadable marker is unknown, never evidence of a fresh install.
      return 0;
    }
  }

  Future<bool> saveCompositionRevision() async {
    final store = await _store.value;
    return await store?.setInt('compositionRevision', 1) ?? false;
  }

  Future<Map<String, Object?>?> getConfigMap() async {
    try {
      final preferences = await _store.value;
      final configString = preferences?.getString(configKey);
      if (configString == null) return null;
      final Map<String, Object?>? configMap = json.decode(configString);
      return configMap;
    } catch (e) {
      commonPrint.log(
        'getConfigMap error ${e.toString()}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  Future<Map<String, Object?>?> getClashConfigMap() async {
    try {
      final preferences = await _store.value;
      final clashConfigString = preferences?.getString(clashConfigKey);
      if (clashConfigString == null) return null;
      return json.decode(clashConfigString);
    } catch (e) {
      commonPrint.log(
        'getClashConfigMap error ${e.toString()}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  Future<void> clearClashConfig() async {
    try {
      final preferences = await _store.value;
      await preferences?.remove(clashConfigKey);
      return;
    } catch (e) {
      commonPrint.log(
        'clearClashConfig error ${e.toString()}',
        logLevel: LogLevel.warning,
      );
      return;
    }
  }

  Future<Config?> getConfig() async {
    final configMap = await getConfigMap();
    if (configMap == null) {
      return null;
    }
    return Config.fromJson(configMap);
  }

  Future<bool> saveConfig(Config config) async {
    final preferences = await _store.value;
    return preferences?.setString(configKey, json.encode(config)) ?? false;
  }

  Future<SystemDnsRecord?> getSystemDnsRecord() async {
    try {
      final sharedPreferencesIns = await _store.value;
      final raw = sharedPreferencesIns?.getString(systemDnsRecordKey);
      if (raw == null) {
        return null;
      }
      return SystemDnsRecord.fromJson(json.decode(raw));
    } catch (e) {
      commonPrint.log(
        'getSystemDnsRecord error ${e.toString()}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  Future<void> clearSystemDnsRecord() async {
    final sharedPreferencesIns = await _store.value;
    await sharedPreferencesIns?.remove(systemDnsRecordKey);
  }

  Future<SystemProxySnapshot?> getSystemProxySnapshot() async {
    try {
      final sharedPreferencesIns = await _store.value;
      final raw = sharedPreferencesIns?.getString(systemProxySnapshotKey);
      if (raw == null) {
        return null;
      }
      return SystemProxySnapshot.fromJson(json.decode(raw));
    } catch (e) {
      commonPrint.log(
        'getSystemProxySnapshot error ${e.toString()}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  Future<void> saveSystemProxySnapshot(SystemProxySnapshot snapshot) async {
    final sharedPreferencesIns = await _store.value;
    await sharedPreferencesIns?.setString(
      systemProxySnapshotKey,
      json.encode(snapshot.toJson()),
    );
  }

  Future<void> clearSystemProxySnapshot() async {
    final sharedPreferencesIns = await _store.value;
    await sharedPreferencesIns?.remove(systemProxySnapshotKey);
  }

  Future<BootRecord?> getBootRecord() async {
    try {
      final sharedPreferencesIns = await _store.value;
      final raw = sharedPreferencesIns?.getString(bootRecordKey);
      if (raw == null) {
        return null;
      }
      return BootRecord.fromJson(json.decode(raw));
    } catch (e) {
      commonPrint.log(
        'getBootRecord error ${e.toString()}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  Future<void> saveBootRecord(BootRecord record) async {
    final sharedPreferencesIns = await _store.value;
    await sharedPreferencesIns?.setString(bootRecordKey, json.encode(record));
  }

  Future<List<TailscaleNodeRecord>> getTailscaleNodeRecords() async {
    try {
      final sharedPreferencesIns = await _store.value;
      final raw = sharedPreferencesIns?.getString(tailscaleNodeRecordsKey);
      if (raw == null) {
        return const [];
      }
      return [
        for (final item in json.decode(raw) as List)
          TailscaleNodeRecord.fromJson(Map<String, Object?>.from(item as Map)),
      ];
    } catch (e) {
      commonPrint.log(
        'getTailscaleNodeRecords error ${e.toString()}',
        logLevel: LogLevel.warning,
      );
      return const [];
    }
  }

  Future<bool> saveTailscaleNodeRecords(
    List<TailscaleNodeRecord> records,
  ) async {
    final sharedPreferencesIns = await _store.value;
    return await sharedPreferencesIns?.setString(
          tailscaleNodeRecordsKey,
          json.encode(records),
        ) ??
        false;
  }

  /// Null when the stored records cannot be read, so nothing overwrites them.
  Future<List<TailscaleManagedRecord>?> getTailscaleManagedRecords() async {
    try {
      final sharedPreferencesIns = await _store.value;
      final raw = sharedPreferencesIns?.getString(tailscaleManagedRecordsKey);
      if (raw == null) {
        return const [];
      }
      return [
        for (final item in json.decode(raw) as List)
          TailscaleManagedRecord.fromJson(
            Map<String, Object?>.from(item as Map),
          ),
      ];
    } catch (e) {
      commonPrint.log(
        'getTailscaleManagedRecords error ${e.toString()}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  Future<bool> saveTailscaleManagedRecords(
    List<TailscaleManagedRecord> records,
  ) async {
    final sharedPreferencesIns = await _store.value;
    return await sharedPreferencesIns?.setString(
          tailscaleManagedRecordsKey,
          json.encode(records),
        ) ??
        false;
  }

  Future<TailscaleLegacyMigration?> getTailscaleLegacyMigration() async {
    try {
      final sharedPreferencesIns = await _store.value;
      final raw = sharedPreferencesIns?.getString(tailscaleLegacyMigrationKey);
      if (raw == null) {
        return null;
      }
      return TailscaleLegacyMigration.fromJson(
        Map<String, Object?>.from(json.decode(raw) as Map),
      );
    } catch (e) {
      commonPrint.log(
        'getTailscaleLegacyMigration error ${e.toString()}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  Future<bool> saveTailscaleLegacyMigration(
    TailscaleLegacyMigration migration,
  ) async {
    final sharedPreferencesIns = await _store.value;
    return await sharedPreferencesIns?.setString(
          tailscaleLegacyMigrationKey,
          json.encode(migration),
        ) ??
        false;
  }

  Future<void> clearPreferences() async {
    final sharedPreferencesIns = await _store.value;
    await sharedPreferencesIns?.clear();
  }
}

final preferences = Preferences();
