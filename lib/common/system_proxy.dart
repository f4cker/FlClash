// Flash's restore-only-own system proxy, carried over from the removed
// `proxy` plugin. Setting the proxy goes through the Rust bridge on every
// platform (which also serves a PAC script); on macOS the settings are read
// before and compared after, so a stop only undoes what Flash itself set.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:rust_api/rust_api.dart' as rust_api;

const proxyHost = '127.0.0.1';

/// The path the Rust PAC server serves its script at.
const pacPath = '/flclash.pac';

const _networksetup = '/usr/sbin/networksetup';

typedef ProxyProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      bool runInShell,
    });

typedef NativeProxyStart =
    Future<bool> Function(
      int port,
      List<String> bypassDomain,
      String? pacScript,
    );

typedef NativeProxyStop = Future<bool> Function();

@immutable
class ProxyCommand {
  final String executable;
  final List<String> args;
  final bool runInShell;
  final bool optional;

  ProxyCommand(
    this.executable,
    List<String> args, {
    this.runInShell = false,
    this.optional = false,
  }) : args = List.unmodifiable(args);
}

class ProxyCommandRunner {
  final ProxyProcessRunner _processRunner;

  ProxyCommandRunner(this._processRunner);

  Future<ProcessResult> process(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
  }) {
    return _processRunner(executable, arguments, runInShell: runInShell);
  }

  Future<bool> run(Iterable<ProxyCommand> commands) async {
    var executed = false;
    for (final command in commands) {
      executed = true;
      if (!await _succeeds(command) && !command.optional) {
        return false;
      }
    }
    return executed;
  }

  Future<bool> _succeeds(ProxyCommand command) async {
    try {
      final result = await process(
        command.executable,
        command.args,
        runInShell: command.runInShell,
      );
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}

/// What the system proxy held before Flash pointed it at itself, and what
/// Flash set. [services] is null where the platform cannot be read back, and
/// there a restore falls back to turning the proxy off.
@immutable
class SystemProxySnapshot {
  final Map<String, MacosServiceProxy>? services;
  final int port;
  final List<String> bypassDomain;

  /// Whether Flash pointed the system at its PAC script rather than at the
  /// mixed port.
  final bool pac;

  SystemProxySnapshot({
    required Map<String, MacosServiceProxy>? services,
    required this.port,
    required List<String> bypassDomain,
    this.pac = false,
  }) : services = services == null ? null : Map.unmodifiable(services),
       bypassDomain = List.unmodifiable(bypassDomain);

  bool get restorable => services != null;

  SystemProxySnapshot applying(
    int port,
    List<String> bypassDomain, {
    bool pac = false,
  }) {
    return SystemProxySnapshot(
      services: services,
      port: port,
      bypassDomain: bypassDomain,
      pac: pac,
    );
  }

  static SystemProxySnapshot? fromJson(Object? json) {
    if (json case {
      'services': final Map services,
      'port': final int port,
      'bypassDomain': final List bypassDomain,
    }) {
      final parsed = <String, MacosServiceProxy>{};
      for (final MapEntry(:key, :value) in services.entries) {
        final settings = MacosServiceProxy.fromJson(value);
        if (key is! String || settings == null) {
          return null;
        }
        parsed[key] = settings;
      }
      return SystemProxySnapshot(
        services: parsed,
        port: port,
        bypassDomain: bypassDomain.whereType<String>().toList(),
        pac: json['pac'] == true,
      );
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'services': {
      for (final MapEntry(:key, :value) in (services ?? const {}).entries)
        key: value.toJson(),
    },
    'port': port,
    'bypassDomain': bypassDomain,
    if (pac) 'pac': true,
  };
}

Future<bool> _nativeStart(
  int port,
  List<String> bypassDomain,
  String? pacScript,
) {
  return rust_api.startSystemProxy(
    port: port,
    bypassDomain: bypassDomain,
    pacScript: pacScript,
  );
}

class Proxy {
  static const int _minPort = 1;
  static const int _maxPort = 65535;

  final NativeProxyStart _start;
  final NativeProxyStop _stop;
  final bool _isMacOS;
  late final MacosProxy _macosProxy;

  Proxy({
    ProxyProcessRunner? processRunner,
    NativeProxyStart? start,
    NativeProxyStop? stop,
    bool? isMacOS,
  }) : _start = start ?? _nativeStart,
       _stop = stop ?? rust_api.stopSystemProxy,
       _isMacOS = isMacOS ?? Platform.isMacOS {
    _macosProxy = MacosProxy(
      commandRunner: ProxyCommandRunner(processRunner ?? Process.run),
    );
  }

  Future<bool> startProxy(
    int port, [
    List<String> bypassDomain = const [],
    String? pacScript,
  ]) async {
    if (port < _minPort || port > _maxPort) {
      return false;
    }
    return _start(port, bypassDomain, pacScript);
  }

  /// Reads what the system proxy holds before [startProxy] replaces it.
  /// Null when it cannot be read, and then it must not be replaced.
  Future<SystemProxySnapshot?> snapshotProxy(
    int port, [
    List<String> bypassDomain = const [],
    String? pacScript,
  ]) async {
    if (!_isMacOS) {
      return SystemProxySnapshot(
        services: null,
        port: port,
        bypassDomain: bypassDomain,
        pac: pacScript != null,
      );
    }
    final services = await _macosProxy.read();
    if (services == null) {
      return null;
    }
    return SystemProxySnapshot(
      services: services,
      port: port,
      bypassDomain: bypassDomain,
      pac: pacScript != null,
    );
  }

  /// Undoes a [startProxy] recorded in [snapshot]. On macOS only services
  /// still set exactly as Flash left them are put back; others are left to
  /// whoever changed them. False when something could not be read or
  /// written, so the caller can try again.
  Future<bool> restoreProxy(SystemProxySnapshot snapshot) async {
    final services = snapshot.services;
    if (services == null) {
      return stopProxy();
    }
    if (!_isMacOS) {
      return false;
    }
    return _macosProxy.restore(
      services,
      snapshot.pac
          ? const MacosAppliedProxy.pac()
          : MacosAppliedProxy.manual(snapshot.port, snapshot.bypassDomain),
    );
  }

  /// macOS never turns the proxy off blindly; it goes through
  /// [restoreProxy].
  Future<bool> stopProxy() async {
    if (_isMacOS) {
      return false;
    }
    return _stop();
  }
}

class MacosProxy {
  final ProxyCommandRunner _commandRunner;

  MacosProxy({required ProxyCommandRunner commandRunner})
    : _commandRunner = commandRunner;

  /// Null when any enabled service cannot be read, since a partial snapshot
  /// could not put every service back.
  Future<Map<String, MacosServiceProxy>?> read() async {
    final services = await _networkServices();
    if (services.isEmpty) {
      return null;
    }
    final settings = await _readServices(services);
    if (settings.length != services.length) {
      return null;
    }
    return settings;
  }

  /// Puts back every service of [before] that still holds what [applied]
  /// describes; false when a service could not be read or written, so a
  /// later call can try again.
  Future<bool> restore(
    Map<String, MacosServiceProxy> before,
    MacosAppliedProxy applied,
  ) async {
    final listed = await _networkServices();
    if (listed.isEmpty) {
      return false;
    }
    final present = [
      for (final service in before.keys)
        if (listed.contains(service)) service,
    ];
    final current = await _readServices(present);
    final plan = MacosProxyCommands.restorePlan(
      before: before,
      applied: applied,
      current: current,
    );
    var restored = current.length == present.length;
    for (final MapEntry(key: service, value: settings) in plan.entries) {
      final ok = await _commandRunner.run(
        MacosProxyCommands.buildRestore(service, settings),
      );
      restored &= ok;
    }
    return restored;
  }

  Future<Map<String, MacosServiceProxy>> _readServices(
    List<String> services,
  ) async {
    final settings = await Future.wait(services.map(_readService));
    return {
      for (var i = 0; i < services.length; i++) services[i]: ?settings[i],
    };
  }

  Future<MacosServiceProxy?> _readService(String service) async {
    final outputs = await Future.wait([
      for (final getter in const [
        '-getwebproxy',
        '-getsecurewebproxy',
        '-getsocksfirewallproxy',
        '-getproxybypassdomains',
        '-getautoproxyurl',
      ])
        _output(getter, service),
    ]);
    if (outputs.contains(null)) {
      return null;
    }
    final web = MacosProxyEndpoint.parse(outputs[0]!);
    final secure = MacosProxyEndpoint.parse(outputs[1]!);
    final socks = MacosProxyEndpoint.parse(outputs[2]!);
    final auto = MacosAutoProxy.parse(outputs[4]!);
    if (web == null || secure == null || socks == null || auto == null) {
      return null;
    }
    return MacosServiceProxy(
      web: web,
      secure: secure,
      socks: socks,
      bypassDomain: MacosProxyCommands.parseBypassDomains(outputs[3]!),
      auto: auto,
    );
  }

  Future<String?> _output(String getter, String service) async {
    try {
      final result = await _commandRunner.process(_networksetup, [
        getter,
        service,
      ]);
      return result.exitCode == 0 ? result.stdout.toString() : null;
    } on ProcessException {
      return null;
    }
  }

  Future<List<String>> _networkServices() async {
    try {
      final result = await _commandRunner.process(_networksetup, [
        '-listallnetworkservices',
      ]);
      if (result.exitCode != 0) {
        return [];
      }
      return MacosProxyCommands.parseNetworkServices(result.stdout.toString());
    } on ProcessException {
      return [];
    }
  }
}

Map<String, String> _fields(String stdout) {
  final fields = <String, String>{};
  for (final line in stdout.split('\n')) {
    final separator = line.indexOf(':');
    if (separator <= 0) {
      continue;
    }
    fields[line.substring(0, separator).trim()] = line
        .substring(separator + 1)
        .trim();
  }
  return fields;
}

/// One of the web, secure web and SOCKS proxies of a network service.
@immutable
class MacosProxyEndpoint {
  final bool enabled;
  final String host;
  final int port;

  const MacosProxyEndpoint({
    required this.enabled,
    required this.host,
    required this.port,
  });

  /// Reads the `Enabled`, `Server` and `Port` lines networksetup prints.
  static MacosProxyEndpoint? parse(String stdout) {
    final fields = _fields(stdout);
    final enabled = fields['Enabled'];
    final host = fields['Server'];
    final port = int.tryParse(fields['Port'] ?? '');
    if (enabled == null || host == null || port == null) {
      return null;
    }
    return MacosProxyEndpoint(
      enabled: enabled == 'Yes',
      host: host,
      port: port,
    );
  }

  static MacosProxyEndpoint? fromJson(Object? json) {
    if (json case {
      'enabled': final bool enabled,
      'host': final String host,
      'port': final int port,
    }) {
      return MacosProxyEndpoint(enabled: enabled, host: host, port: port);
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'host': host,
    'port': port,
  };

  MacosProxyEndpoint disabled() =>
      MacosProxyEndpoint(enabled: false, host: host, port: port);

  @override
  bool operator ==(Object other) =>
      other is MacosProxyEndpoint &&
      other.enabled == enabled &&
      other.host == host &&
      other.port == port;

  @override
  int get hashCode => Object.hash(enabled, host, port);

  @override
  String toString() => 'MacosProxyEndpoint($enabled, $host:$port)';
}

/// The automatic proxy configuration (PAC URL) of a network service.
@immutable
class MacosAutoProxy {
  final bool enabled;

  /// Empty when none is set.
  final String url;

  const MacosAutoProxy({required this.enabled, required this.url});

  static const off = MacosAutoProxy(enabled: false, url: '');

  /// Reads the `URL` and `Enabled` lines of `-getautoproxyurl`.
  static MacosAutoProxy? parse(String stdout) {
    final fields = _fields(stdout);
    final url = fields['URL'];
    final enabled = fields['Enabled'];
    if (url == null || enabled == null) {
      return null;
    }
    return MacosAutoProxy(
      enabled: enabled == 'Yes',
      url: url == '(null)' ? '' : url,
    );
  }

  /// Whether this is the PAC script the Rust side serves for Flash.
  bool get isFlashPac {
    final uri = Uri.tryParse(url);
    return enabled &&
        uri != null &&
        uri.scheme == 'http' &&
        uri.host == proxyHost &&
        uri.path == pacPath;
  }

  static MacosAutoProxy? fromJson(Object? json) {
    if (json case {'enabled': final bool enabled, 'url': final String url}) {
      return MacosAutoProxy(enabled: enabled, url: url);
    }
    return null;
  }

  Map<String, Object?> toJson() => {'enabled': enabled, 'url': url};

  @override
  bool operator ==(Object other) =>
      other is MacosAutoProxy && other.enabled == enabled && other.url == url;

  @override
  int get hashCode => Object.hash(enabled, url);

  @override
  String toString() => 'MacosAutoProxy($enabled, $url)';
}

/// The proxy settings of one network service that Flash writes on start.
@immutable
class MacosServiceProxy {
  final MacosProxyEndpoint web;
  final MacosProxyEndpoint secure;
  final MacosProxyEndpoint socks;
  final List<String> bypassDomain;

  /// Null in snapshots recorded before Flash read the automatic proxy; then
  /// it is neither compared nor put back.
  final MacosAutoProxy? auto;

  MacosServiceProxy({
    required this.web,
    required this.secure,
    required this.socks,
    required List<String> bypassDomain,
    this.auto,
  }) : bypassDomain = List.unmodifiable(bypassDomain);

  /// What a manual start leaves on a service: the three proxies at the
  /// mixed port and the automatic proxy off. networksetup has no notion of
  /// WinINet's `<local>`, so it never reaches the service.
  factory MacosServiceProxy.applied(int port, List<String> bypassDomain) {
    final endpoint = MacosProxyEndpoint(
      enabled: true,
      host: proxyHost,
      port: port,
    );
    return MacosServiceProxy(
      web: endpoint,
      secure: endpoint,
      socks: endpoint,
      bypassDomain: _withoutWininetLocal(bypassDomain),
    );
  }

  static MacosServiceProxy? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final web = MacosProxyEndpoint.fromJson(json['web']);
    final secure = MacosProxyEndpoint.fromJson(json['secure']);
    final socks = MacosProxyEndpoint.fromJson(json['socks']);
    final bypassDomain = json['bypassDomain'];
    if (web == null ||
        secure == null ||
        socks == null ||
        bypassDomain is! List) {
      return null;
    }
    final auto = json['auto'];
    final parsedAuto = auto == null ? null : MacosAutoProxy.fromJson(auto);
    if (auto != null && parsedAuto == null) {
      return null;
    }
    return MacosServiceProxy(
      web: web,
      secure: secure,
      socks: socks,
      bypassDomain: bypassDomain.whereType<String>().toList(),
      auto: parsedAuto,
    );
  }

  Map<String, Object?> toJson() => {
    'web': web.toJson(),
    'secure': secure.toJson(),
    'socks': socks.toJson(),
    'bypassDomain': bypassDomain,
    if (auto case final auto?) 'auto': auto.toJson(),
  };

  bool _sameManual(MacosServiceProxy other) =>
      other.web == web &&
      other.secure == secure &&
      other.socks == socks &&
      setEquals(other.bypassDomain.toSet(), bypassDomain.toSet());

  /// networksetup may hand the bypass list back in another order.
  @override
  bool operator ==(Object other) =>
      other is MacosServiceProxy && _sameManual(other) && other.auto == auto;

  @override
  int get hashCode => Object.hash(
    web,
    secure,
    socks,
    Object.hashAllUnordered(bypassDomain),
    auto,
  );

  @override
  String toString() =>
      'MacosServiceProxy(web: $web, secure: $secure, socks: $socks, '
      'bypass: $bypassDomain, auto: $auto)';
}

List<String> _withoutWininetLocal(List<String> bypassDomain) =>
    bypassDomain.where((domain) => domain.trim() != '<local>').toList();

/// What a start left on every service, to tell whether a service still
/// holds it when the proxy is stopped.
@immutable
sealed class MacosAppliedProxy {
  const MacosAppliedProxy();

  const factory MacosAppliedProxy.pac() = _AppliedPac;

  factory MacosAppliedProxy.manual(int port, List<String> bypassDomain) =
      _AppliedManual;

  /// Whether [current] is still exactly what Flash set on a service that
  /// held [before].
  bool heldBy(MacosServiceProxy current, MacosServiceProxy before);
}

final class _AppliedManual extends MacosAppliedProxy {
  final MacosServiceProxy settings;

  _AppliedManual(int port, List<String> bypassDomain)
    : settings = MacosServiceProxy.applied(port, bypassDomain);

  @override
  bool heldBy(MacosServiceProxy current, MacosServiceProxy before) {
    if (!settings._sameManual(current)) {
      return false;
    }
    // The start turns the automatic proxy off and leaves its URL.
    final auto = current.auto;
    return before.auto == null || auto == null || !auto.enabled;
  }
}

final class _AppliedPac extends MacosAppliedProxy {
  const _AppliedPac();

  @override
  bool heldBy(MacosServiceProxy current, MacosServiceProxy before) {
    // The start turns the three proxies off and leaves their servers and
    // the bypass list, and points the automatic proxy at Flash's script.
    return current.auto?.isFlashPac == true &&
        current.web == before.web.disabled() &&
        current.secure == before.secure.disabled() &&
        current.socks == before.socks.disabled();
  }
}

class MacosProxyCommands {
  /// Values go before states: setting a server also turns its proxy on, and
  /// so does setting an automatic proxy URL.
  static List<ProxyCommand> buildRestore(
    String service,
    MacosServiceProxy settings,
  ) {
    final kinds = [
      (settings.web, '-setwebproxy', '-setwebproxystate'),
      (settings.secure, '-setsecurewebproxy', '-setsecurewebproxystate'),
      (settings.socks, '-setsocksfirewallproxy', '-setsocksfirewallproxystate'),
    ];
    final auto = settings.auto;
    return [
      for (final (endpoint, setter, _) in kinds)
        if (endpoint.host.isNotEmpty)
          ProxyCommand(_networksetup, [
            setter,
            service,
            endpoint.host,
            '${endpoint.port}',
          ]),
      buildProxyBypass(service, settings.bypassDomain),
      if (auto != null && auto.url.isNotEmpty)
        ProxyCommand(_networksetup, ['-setautoproxyurl', service, auto.url]),
      for (final (endpoint, _, stateSetter) in kinds)
        ProxyCommand(_networksetup, [
          stateSetter,
          service,
          endpoint.enabled ? 'on' : 'off',
        ]),
      if (auto != null)
        ProxyCommand(_networksetup, [
          '-setautoproxystate',
          service,
          auto.enabled ? 'on' : 'off',
        ]),
    ];
  }

  /// The services to put back: those still holding exactly what Flash
  /// applied. One that changed since belongs to whoever changed it, and one
  /// that could not be read is not guessed at.
  static Map<String, MacosServiceProxy> restorePlan({
    required Map<String, MacosServiceProxy> before,
    required MacosAppliedProxy applied,
    required Map<String, MacosServiceProxy> current,
  }) {
    return {
      for (final MapEntry(key: service, value: settings) in before.entries)
        if (current[service] case final now?
            when applied.heldBy(now, settings) && now != settings)
          service: settings,
    };
  }

  static ProxyCommand buildProxyBypass(
    String service,
    List<String> bypassDomain,
  ) {
    return ProxyCommand(_networksetup, [
      '-setproxybypassdomains',
      service,
      if (bypassDomain.isEmpty) 'Empty' else ...bypassDomain,
    ]);
  }

  static List<String> parseBypassDomains(String stdout) {
    final lines = stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines case [final only] when only.startsWith("There aren't any")) {
      return [];
    }
    return lines;
  }

  static List<String> parseNetworkServices(String stdout) {
    return stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !line.startsWith('*'))
        .where((line) => !line.startsWith('An asterisk '))
        .toList();
  }
}
