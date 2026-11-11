import 'dart:io';

import 'package:flutter/foundation.dart';

import 'proxy_command.dart';

const _networksetup = '/usr/sbin/networksetup';

class MacosProxy {
  final ProxyCommandRunner _commandRunner;

  MacosProxy({required ProxyCommandRunner commandRunner})
    : _commandRunner = commandRunner;

  Future<bool> start(int port, List<String> bypassDomain) async {
    final services = await _networkServices();
    return _commandRunner.run(
      services.expand(
        (service) => MacosProxyCommands.buildStart(service, port, bypassDomain),
      ),
    );
  }

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

  /// Puts [before] back on every service still set exactly as [applied];
  /// false when a service could not be read or written, so a later call can
  /// try again.
  Future<bool> restore(
    Map<String, MacosServiceProxy> before,
    MacosServiceProxy applied,
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
      ])
        _output(getter, service),
    ]);
    if (outputs.contains(null)) {
      return null;
    }
    final web = MacosProxyEndpoint.parse(outputs[0]!);
    final secure = MacosProxyEndpoint.parse(outputs[1]!);
    final socks = MacosProxyEndpoint.parse(outputs[2]!);
    if (web == null || secure == null || socks == null) {
      return null;
    }
    return MacosServiceProxy(
      web: web,
      secure: secure,
      socks: socks,
      bypassDomain: MacosProxyCommands.parseBypassDomains(outputs[3]!),
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

/// The proxy settings of one network service that Flash writes on start.
@immutable
class MacosServiceProxy {
  final MacosProxyEndpoint web;
  final MacosProxyEndpoint secure;
  final MacosProxyEndpoint socks;
  final List<String> bypassDomain;

  MacosServiceProxy({
    required this.web,
    required this.secure,
    required this.socks,
    required List<String> bypassDomain,
  }) : bypassDomain = List.unmodifiable(bypassDomain);

  /// What [MacosProxyCommands.buildStart] leaves on a service.
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
      bypassDomain: bypassDomain,
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
    return MacosServiceProxy(
      web: web,
      secure: secure,
      socks: socks,
      bypassDomain: bypassDomain.whereType<String>().toList(),
    );
  }

  Map<String, Object?> toJson() => {
    'web': web.toJson(),
    'secure': secure.toJson(),
    'socks': socks.toJson(),
    'bypassDomain': bypassDomain,
  };

  /// networksetup may hand the bypass list back in another order.
  @override
  bool operator ==(Object other) =>
      other is MacosServiceProxy &&
      other.web == web &&
      other.secure == secure &&
      other.socks == socks &&
      setEquals(other.bypassDomain.toSet(), bypassDomain.toSet());

  @override
  int get hashCode =>
      Object.hash(web, secure, socks, Object.hashAllUnordered(bypassDomain));

  @override
  String toString() =>
      'MacosServiceProxy(web: $web, secure: $secure, socks: $socks, '
      'bypass: $bypassDomain)';
}

class MacosProxyCommands {
  static List<ProxyCommand> buildStart(
    String service,
    int port,
    List<String> bypassDomain,
  ) {
    return [
      ProxyCommand(_networksetup, [
        '-setwebproxy',
        service,
        proxyHost,
        '$port',
      ]),
      ProxyCommand(_networksetup, [
        '-setsecurewebproxy',
        service,
        proxyHost,
        '$port',
      ]),
      ProxyCommand(_networksetup, [
        '-setsocksfirewallproxy',
        service,
        proxyHost,
        '$port',
      ]),
      buildProxyBypass(service, bypassDomain),
      ProxyCommand(_networksetup, ['-setwebproxystate', service, 'on']),
      ProxyCommand(_networksetup, ['-setsecurewebproxystate', service, 'on']),
      ProxyCommand(_networksetup, [
        '-setsocksfirewallproxystate',
        service,
        'on',
      ]),
    ];
  }

  /// Values go before states: setting a server also turns its proxy on.
  static List<ProxyCommand> buildRestore(
    String service,
    MacosServiceProxy settings,
  ) {
    final kinds = [
      (settings.web, '-setwebproxy', '-setwebproxystate'),
      (settings.secure, '-setsecurewebproxy', '-setsecurewebproxystate'),
      (settings.socks, '-setsocksfirewallproxy', '-setsocksfirewallproxystate'),
    ];
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
      for (final (endpoint, _, stateSetter) in kinds)
        ProxyCommand(_networksetup, [
          stateSetter,
          service,
          endpoint.enabled ? 'on' : 'off',
        ]),
    ];
  }

  /// The services to put back: those still holding exactly what Flash
  /// applied. One that changed since belongs to whoever changed it, and one
  /// that could not be read is not guessed at.
  static Map<String, MacosServiceProxy> restorePlan({
    required Map<String, MacosServiceProxy> before,
    required MacosServiceProxy applied,
    required Map<String, MacosServiceProxy> current,
  }) {
    return {
      for (final MapEntry(key: service, value: settings) in before.entries)
        if (current[service] == applied && settings != applied)
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
