import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';

import 'tailscale.dart';

/// [readFailed] is the host's own: the read itself failed.
enum TailscaleRuntimeState {
  confirmed,
  unconfirmed,
  none,
  otherProfile,
  readFailed;

  static TailscaleRuntimeState of(String value) => switch (value) {
    'confirmed' => confirmed,
    'none' => none,
    'other-profile' => otherProfile,
    _ => unconfirmed,
  };
}

class TailscaleRuntimeAccount {
  const TailscaleRuntimeAccount({
    required this.id,
    required this.node,
    this.rules = const [],
  });

  factory TailscaleRuntimeAccount.fromJson(Map<String, Object?> json) =>
      TailscaleRuntimeAccount(
        id: json['id'] as String? ?? '',
        node: json['node'] as String? ?? '',
        rules: [for (final rule in json['rules'] as List? ?? []) '$rule'],
      );

  final String id;
  final String node;

  final List<String> rules;
}

class TailscaleRuntimeRules {
  const TailscaleRuntimeRules({
    required this.profileId,
    required this.state,
    this.revision = '',
    this.accounts = const [],
    this.proxies = const [],
  });

  const TailscaleRuntimeRules.readFailed(this.profileId)
    : state = TailscaleRuntimeState.readFailed,
      revision = '',
      accounts = const [],
      proxies = const [];

  factory TailscaleRuntimeRules.fromJson(Map<String, Object?> json) =>
      TailscaleRuntimeRules(
        profileId: json['profile-id'] as int? ?? 0,
        state: TailscaleRuntimeState.of(json['state'] as String? ?? ''),
        revision: json['revision'] as String? ?? '',
        accounts: [
          for (final account in json['accounts'] as List? ?? [])
            TailscaleRuntimeAccount.fromJson(
              Map<String, Object?>.from(account as Map),
            ),
        ],
        proxies: [for (final proxy in json['proxies'] as List? ?? []) '$proxy'],
      );

  final int profileId;
  final TailscaleRuntimeState state;
  final String revision;
  final List<TailscaleRuntimeAccount> accounts;
  final List<String> proxies;
}

/// The digest the Core keeps of the setup it injected.
String tailscaleRuntimeRevisionOf(TailscaleSetup setup) {
  final accounts = [
    for (final account in setup.managed)
      if (account.id.isNotEmpty) '${account.id}:${account.attached ? 1 : 0}',
  ];
  final unknown = setup.managedUnknown ? 1 : 0;
  return '${setup.profileId}|$unknown|${accounts.join(',')}'.toMd5();
}

/// Names and rules only when the Core runs [setup]'s revision.
String annotateTailscaleRuntime(
  String yaml,
  TailscaleRuntimeRules runtime,
  TailscaleSetup? setup,
  AppLocalizations appLocalizations,
) {
  final matched =
      setup != null &&
      runtime.profileId == setup.profileId &&
      runtime.revision == tailscaleRuntimeRevisionOf(setup);
  final List<String> rules;
  final List<String> proxies;
  switch (runtime.state) {
    case TailscaleRuntimeState.none || TailscaleRuntimeState.otherProfile:
      return yaml;
    case TailscaleRuntimeState.readFailed:
      rules = [appLocalizations.tsViewerReadFailed];
      proxies = const [];
    case TailscaleRuntimeState.confirmed when matched:
      rules = [
        for (final account in runtime.accounts) ...[
          appLocalizations.tsViewerRules(
            account.rules.length,
            _commentSafe(account.node),
          ),
          for (final rule in account.rules) '  - ${_commentSafe(rule)}',
        ],
      ];
      proxies = [
        for (final proxy in runtime.proxies)
          appLocalizations.tsViewerNode(_commentSafe(proxy)),
      ];
    case _:
      rules = [appLocalizations.tsViewerUnconfirmed];
      proxies = const [];
  }
  final notes = {'rules': rules, 'proxies': proxies};
  final section = RegExp(r'^([^\s#][^:]*):');
  final lines = yaml.split('\n');
  final out = <String>[];
  final placed = <String>{};
  for (final (index, line) in lines.indexed) {
    out.add(line);
    final name = section.firstMatch(line)?.group(1);
    final group = notes[name];
    if (group == null || group.isEmpty || !placed.add(name!)) {
      continue;
    }
    final next = index + 1 < lines.length ? lines[index + 1] : '';
    final indent = RegExp(r'^\s*(?=-)').firstMatch(next)?.group(0) ?? '';
    out.addAll([for (final note in group) '$indent# $note']);
  }
  for (final MapEntry(:key, :value) in notes.entries) {
    if (value.isNotEmpty && !placed.contains(key)) {
      out.addAll([for (final note in value) '# $note']);
    }
  }
  return out.join('\n');
}

String _commentSafe(String text) => text.replaceAll(RegExp(r'[\r\n]+'), ' ');
