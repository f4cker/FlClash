import 'package:collection/collection.dart';
import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/l10n_labels.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:yaml/yaml.dart';

/// The value at [path], or [configKeyMissing] when the config has none.
const configKeyMissing = Object();

Object? readConfigPath(Map config, String path) {
  Object? value = config;
  for (final part in path.split('.')) {
    if (value is! Map || !value.containsKey(part)) {
      return configKeyMissing;
    }
    value = value[part];
  }
  return value;
}

/// mihomo's own value for a key a profile leaves out, only where it is
/// confirmed in DefaultRawConfig.
const kernelDefaults = <String, Object?>{
  'mixed-port': 0,
  'port': 0,
  'socks-port': 0,
  'redir-port': 0,
  'tproxy-port': 0,
  'mode': 'rule',
  'allow-lan': false,
  'log-level': 'info',
  'find-process-mode': 'strict',
  'external-controller': '',
  'authentication': <Object?>[],
  'hosts': <Object?, Object?>{},
  'disable-keep-alive': false,
  'geo-auto-update': false,
  'geo-update-interval': 24,
  'tun.enable': false,
  'tun.stack': 'mips',
  'tun.dns-hijack': ['0.0.0.0:53'],
  'tun.auto-route': true,
  'tun.auto-detect-interface': true,
  'profile.store-selected': true,
  'dns.enable': false,
  'routing-mark': 0,
};

/// Keys the old build forced with no control on the page.
const hiddenOverridePaths = [
  'profile.store-selected',
  'tun.dns-hijack',
  'tun.device',
  'tun.auto-route',
  'tun.auto-detect-interface',
  'skip-auth-prefixes',
  'external-ui',
  'external-ui-url',
  'routing-mark',
];

class PageSourceRow {
  final PageConfigKey key;
  final Object? pageValue;
  final Object? fileValue;

  const PageSourceRow({
    required this.key,
    required this.pageValue,
    required this.fileValue,
  });
}

class HiddenOverrideRow {
  final String path;
  final Object? oldValue;
  final Object? newValue;

  const HiddenOverrideRow({
    required this.path,
    required this.oldValue,
    required this.newValue,
  });
}

typedef PagePriorityChanges = ({
  List<PageSourceRow> pageRows,
  List<HiddenOverrideRow> hiddenRows,
});

/// What moving to page priority changes: [legacy] is the config built as
/// before, [page] the one built with every page field kept, and [file] the
/// one built with every page field following the profile.
PagePriorityChanges pagePriorityChanges({
  required Map legacy,
  required Map page,
  required Map file,
}) {
  const equality = DeepCollectionEquality();
  Object? effective(Map config, String path) {
    final value = readConfigPath(config, path);
    return identical(value, configKeyMissing)
        ? kernelDefaults[path] ?? configKeyMissing
        : value;
  }

  final pageRows = [
    for (final key in PageConfigKey.values)
      if (!equality.equals(
        effective(page, key.path),
        effective(file, key.path),
      ))
        PageSourceRow(
          key: key,
          pageValue: readConfigPath(page, key.path),
          fileValue: readConfigPath(file, key.path),
        ),
  ];
  final dnsPaths = {
    for (final config in [legacy, page])
      if (config['dns'] case final Map dns)
        for (final key in dns.keys) 'dns.$key',
  };
  final hiddenRows = [
    for (final path in [...hiddenOverridePaths, ...dnsPaths])
      if (!equality.equals(effective(legacy, path), effective(page, path)))
        HiddenOverrideRow(
          path: path,
          oldValue: readConfigPath(legacy, path),
          newValue: readConfigPath(page, path),
        ),
  ];
  return (pageRows: pageRows, hiddenRows: hiddenRows);
}

/// A config value as its setting shows it, [configKeyMissing] as not set;
/// with [withDefault], a missing value names the default mihomo uses.
String describeConfigValue(
  String path,
  Object? value, {
  bool withDefault = true,
}) {
  final l = currentAppLocalizations;
  if (identical(value, configKeyMissing)) {
    return switch (withDefault ? kernelDefaults[path] : null) {
      null => l.notSet,
      final fallback => l.notSetDefault(describeConfigValue(path, fallback)),
    };
  }
  return switch ((path, value)) {
    ('mode', final String mode) =>
      Mode.values.firstWhereOrNull((item) => item.name == mode)?.label ?? mode,
    ('log-level', final String level) =>
      LogLevel.values.firstWhereOrNull((item) => item.name == level)?.label ??
          level,
    ('find-process-mode', final String mode) => switch (mode) {
      'always' => l.findProcessAlways,
      'off' => l.findProcessOff,
      'strict' => l.findProcessStrict,
      _ => mode,
    },
    ('external-controller', '') => l.close,
    ('authentication', final List users) =>
      users.isEmpty
          ? l.none
          : users.map((item) => '$item'.split(':').first).join(', '),
    (_, final bool enabled) => enabled ? l.valueOn : l.valueOff,
    (_, '') => l.valueEmptyText,
    (_, final List items) =>
      items.isEmpty ? l.valueEmptyList : items.join(', '),
    (_, final Map entries) =>
      entries.isEmpty
          ? l.valueEmptyObject
          : entries.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join(', '),
    (_, null) => l.valueNull,
    _ => '$value',
  };
}

/// The name a profile key goes by where no page control shows it.
String configPathLabel(String path) {
  final l = currentAppLocalizations;
  if (path.startsWith('dns.')) {
    return '${l.fieldDnsSettings} · ${path.substring(4)}';
  }
  return switch (path) {
    'profile.store-selected' => l.fieldStoreSelected,
    'tun.dns-hijack' => l.dnsHijacking,
    'tun.auto-route' => l.fieldTunAutoRoute,
    'tun.auto-detect-interface' => l.fieldTunAutoDetectInterface,
    'skip-auth-prefixes' => l.fieldSkipAuthPrefixes,
    'external-ui' => l.fieldExternalUi,
    'routing-mark' => l.routingMark,
    _ => path,
  };
}

String pageConfigKeyLabel(PageConfigKey key) {
  final l = currentAppLocalizations;
  return switch (key) {
    PageConfigKey.mixedPort => l.mixedPort,
    PageConfigKey.port => l.port,
    PageConfigKey.socksPort => l.socksPort,
    PageConfigKey.redirPort => l.redirPort,
    PageConfigKey.tproxyPort => l.tproxyPort,
    PageConfigKey.mode => l.mode,
    PageConfigKey.allowLan => l.allowLan,
    PageConfigKey.logLevel => l.logLevel,
    PageConfigKey.findProcessMode => l.findProcessMode,
    PageConfigKey.externalController => l.externalController,
    PageConfigKey.authentication => l.authentication,
    PageConfigKey.globalUa => l.userAgent,
    PageConfigKey.hosts => 'Hosts',
    PageConfigKey.keepAliveIdle => l.keepAliveIdle,
    PageConfigKey.keepAliveInterval => l.keepAliveIntervalDesc,
    PageConfigKey.disableKeepAlive => l.disableKeepAlive,
    PageConfigKey.geoAutoUpdate => '${l.geoResources} ${l.autoUpdate}',
    PageConfigKey.geoUpdateInterval => l.resourceUpdateInterval,
    PageConfigKey.geoXUrl => l.geoResources,
    PageConfigKey.tunEnable => l.tun,
    PageConfigKey.tunStack => l.stackMode,
  };
}

const _inboundPaths = [
  'port',
  'socks-port',
  'redir-port',
  'tproxy-port',
  'mixed-port',
  'tun.enable',
];

/// The inbounds a built config asks for; a key it leaves out is mihomo's
/// default, which opens none.
Map<String, Object?> builtInboundsOf(String yaml) {
  final config = yaml.isEmpty ? null : loadYaml(yaml);
  if (config is! Map) {
    return const {};
  }
  return {
    for (final path in _inboundPaths)
      if (readConfigPath(config, path) case final value
          when !identical(value, configKeyMissing))
        path: value,
  };
}

/// A controller a file opens beyond this machine needs a secret; mihomo
/// would serve it to the network without one.
bool exposesControllerWithoutSecret(Map config) {
  final address = config['external-controller'];
  final secret = config['secret'];
  if (address is! String || address.isEmpty) {
    return false;
  }
  if (secret is String && secret.isNotEmpty) {
    return false;
  }
  final separator = address.lastIndexOf(':');
  final host = (separator < 0 ? address : address.substring(0, separator))
      .replaceAll('[', '')
      .replaceAll(']', '');
  return !(host == 'localhost' || host == '::1' || host.startsWith('127.'));
}

const _findProcessModes = {'always', 'strict', 'off'};

/// The find-process-mode mihomo runs [yaml] with; null if it would not run.
String? builtFindProcessModeOf(String yaml) {
  final config = yaml.isEmpty ? null : loadYaml(yaml);
  if (config is! Map) {
    return null;
  }
  final value = readConfigPath(config, 'find-process-mode');
  final mode = identical(value, configKeyMissing)
      ? kernelDefaults['find-process-mode']
      : value;
  if (mode is! String) {
    return null;
  }
  final spelled = mode.toLowerCase();
  return _findProcessModes.contains(spelled) ? spelled : null;
}

/// A controller address cut to host:port, dropping credentials and query.
String controllerHostPort(String address) {
  final uri = Uri.tryParse(address.contains('://') ? address : '//$address');
  if (uri == null || uri.host.isEmpty) {
    return address.split('@').last.split(RegExp('[/?#]')).first;
  }
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  return uri.hasPort ? '$host:${uri.port}' : host;
}
