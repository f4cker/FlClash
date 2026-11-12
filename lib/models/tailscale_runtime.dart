import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:intl/intl.dart';

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
      rules = [appLocalizations.tsViewerNone];
      proxies = const [];
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
      if (rules.isEmpty) {
        rules.add(appLocalizations.tsViewerNone);
      }
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

/// The selectedMap key the exit group's choice is kept under, by account id.
const tailscaleExitSelectionKey = '\u0000tailscale-exit';

enum TailscaleExitState {
  applied,
  unavailable,
  unknown;

  static TailscaleExitState of(String value) => switch (value) {
    'applied' => applied,
    'unavailable' => unavailable,
    _ => unknown,
  };
}

/// Why an exit node is unavailable, as the Core reads it.
enum TailscaleExitReason {
  needsLogin,
  offline,
  notAuthorized,
  missing,
  unknown;

  static TailscaleExitReason? of(String value) => switch (value) {
    '' => null,
    'needs-login' => needsLogin,
    'offline' => offline,
    'not-authorized' => notAuthorized,
    'missing' => missing,
    _ => unknown,
  };
}

class TailscaleExitAccount {
  const TailscaleExitAccount({
    required this.id,
    required this.member,
    required this.exitNode,
    required this.state,
    this.reason,
  });

  factory TailscaleExitAccount.fromJson(Map<String, Object?> json) =>
      TailscaleExitAccount(
        id: json['id'] as String? ?? '',
        member: json['member'] as String? ?? '',
        exitNode: json['exit-node'] as String? ?? '',
        state: TailscaleExitState.of(json['state'] as String? ?? ''),
        reason: TailscaleExitReason.of(json['reason'] as String? ?? ''),
      );

  final String id;
  final String member;
  final String exitNode;
  final TailscaleExitState state;
  final TailscaleExitReason? reason;
}

class TailscaleExitParent {
  const TailscaleExitParent({
    required this.name,
    required this.now,
    this.members = const [],
    this.replacement,
  });

  factory TailscaleExitParent.fromJson(Map<String, Object?> json) =>
      TailscaleExitParent(
        name: json['name'] as String? ?? '',
        now: json['now'] as String? ?? '',
        members: [
          for (final member in json['members'] as List? ?? []) '$member',
        ],
        replacement: json['replacement'] as String?,
      );

  final String name;
  final String now;
  final List<String> members;

  /// The fallback once the exit group goes; null when the Core cannot tell.
  final String? replacement;
}

/// The exit group as the running config holds it, read back from the Core.
class TailscaleExitReport {
  const TailscaleExitReport({
    required this.profileId,
    required this.state,
    this.group = '',
    this.selected = '',
    this.parents = const [],
    this.accounts = const [],
  });

  const TailscaleExitReport.readFailed(this.profileId)
    : state = TailscaleRuntimeState.readFailed,
      group = '',
      selected = '',
      parents = const [],
      accounts = const [];

  factory TailscaleExitReport.fromJson(Map<String, Object?> json) =>
      TailscaleExitReport(
        profileId: json['profile-id'] as int? ?? 0,
        state: TailscaleRuntimeState.of(json['state'] as String? ?? ''),
        group: json['group'] as String? ?? '',
        selected: json['selected'] as String? ?? '',
        parents: [
          for (final parent in json['parents'] as List? ?? [])
            TailscaleExitParent.fromJson(
              Map<String, Object?>.from(parent as Map),
            ),
        ],
        accounts: [
          for (final account in json['accounts'] as List? ?? [])
            TailscaleExitAccount.fromJson(
              Map<String, Object?>.from(account as Map),
            ),
        ],
      );

  final int profileId;
  final TailscaleRuntimeState state;

  /// The group's name; empty while it holds no exit node.
  final String group;

  /// The account whose node the group uses.
  final String selected;
  final List<TailscaleExitParent> parents;
  final List<TailscaleExitAccount> accounts;

  bool get confirmed => state == TailscaleRuntimeState.confirmed;

  bool get offered => confirmed && group.isNotEmpty;

  TailscaleExitAccount? accountOf(String id) {
    for (final account in accounts) {
      if (account.id == id) {
        return account;
      }
    }
    return null;
  }

  TailscaleExitAccount? memberNamed(String name) {
    for (final account in accounts) {
      if (account.member == name) {
        return account;
      }
    }
    return null;
  }

  /// How a proxy card shows [name] when it is the exit group or one of its
  /// nodes; null for any other proxy.
  ({bool node, bool unavailable})? cardOf(String name) {
    if (!offered) {
      return null;
    }
    final account = name == group ? accountOf(selected) : memberNamed(name);
    if (account == null && name != group) {
      return null;
    }
    return (
      node: name != group,
      unavailable: account?.state == TailscaleExitState.unavailable,
    );
  }

  /// The groups that would lose the exit group once [accountId] turns its
  /// exit off: none while another account keeps a node in it.
  List<TailscaleExitParent> affectedWithout(String accountId) {
    if (!offered ||
        accounts.any(
          (account) => account.id != accountId && account.exitNode.isNotEmpty,
        )) {
      return const [];
    }
    return [
      for (final parent in parents)
        if (parent.now == group) parent,
    ];
  }
}

/// The exit group's grey note under the proxy groups.
String annotateTailscaleExit(
  String yaml,
  TailscaleExitReport report,
  AppLocalizations appLocalizations,
) {
  final List<String> notes;
  switch (report.state) {
    case TailscaleRuntimeState.none || TailscaleRuntimeState.otherProfile:
      return yaml;
    case TailscaleRuntimeState.confirmed when !report.offered:
      return yaml;
    case TailscaleRuntimeState.confirmed:
      final groups = [
        for (final parent in report.parents) _commentSafe(parent.name),
      ].join(Intl.getCurrentLocale().startsWith('zh') ? '、' : ', ');
      notes = [
        for (final account in report.accounts)
          if (account.exitNode.isNotEmpty)
            appLocalizations.tsViewerExit(
              _commentSafe(report.group),
              _commentSafe(account.member),
              groups,
            ),
      ];
    case TailscaleRuntimeState.readFailed
        when yaml.contains('# ${appLocalizations.tsViewerReadFailed}'):
      return yaml;
    case TailscaleRuntimeState.readFailed:
      notes = [appLocalizations.tsViewerReadFailed];
    case _:
      notes = [appLocalizations.tsViewerExitUnconfirmed];
  }
  if (notes.isEmpty) {
    return yaml;
  }
  final lines = yaml.split('\n');
  final at = lines.indexWhere((line) => line.startsWith('proxy-groups:'));
  if (at < 0) {
    return [yaml, for (final note in notes) '# $note'].join('\n');
  }
  final next = at + 1 < lines.length ? lines[at + 1] : '';
  final indent = RegExp(r'^\s*(?=-)').firstMatch(next)?.group(0) ?? '';
  lines.insertAll(at + 1, [for (final note in notes) '$indent# $note']);
  return lines.join('\n');
}
