import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';

/// Searches connections as [TrackerInfosStateExt.list] does, but keeps each
/// connection's search text by id: a live poll decodes every connection
/// anew, so a text kept by identity would be rebuilt for all of them at every
/// poll. A text is reused only while the fields it was read from are equal,
/// and the kept texts are only those of the last list searched.
class TrackerSearch {
  final _texts = <String, _SearchText>{};
  var _pass = 0;
  final _appsChanges = ProcessAppsChanges();

  List<TrackerInfo>? _source;
  String? _query;
  List<TrackerInfo> _result = const [];

  @visibleForTesting
  int textsBuilt = 0;

  List<TrackerInfo> apply(List<TrackerInfo> trackerInfos, String query) {
    final searchQuery = SearchQuery(query);
    if (searchQuery.isEmpty) {
      return trackerInfos;
    }
    final appsChanged = _appsChanges.take();
    if (!appsChanged && identical(trackerInfos, _source) && query == _query) {
      return _result;
    }
    final pass = ++_pass;
    final recheckLabels = appsChanged && !system.isAndroid;
    final result = <TrackerInfo>[];
    for (final trackerInfo in trackerInfos) {
      var text = _texts[trackerInfo.id];
      if (text == null ||
          !text.isFor(trackerInfo) ||
          (recheckLabels &&
              text.pass != pass &&
              !text.hasLabelsOf(trackerInfo))) {
        text = _texts[trackerInfo.id] = _SearchText(trackerInfo);
        textsBuilt++;
      }
      text.pass = pass;
      if (searchQuery.matchesText(text.text)) {
        result.add(trackerInfo);
      }
    }
    if (_texts.length > trackerInfos.length) {
      _texts.removeWhere((_, text) => text.pass != pass);
    }
    _source = trackerInfos;
    _query = query;
    return _result = result;
  }

  void dispose() {
    _appsChanges.dispose();
    _texts.clear();
    _source = null;
    _result = const [];
  }
}

/// Whether [processApps] notified since the last [take]: an app name or a
/// local address read since can change what a connection is found and
/// filtered by.
class ProcessAppsChanges {
  ProcessApps? _apps;
  var _changed = true;

  bool take() {
    final apps = processApps;
    if (!identical(apps, _apps)) {
      _apps?.removeListener(_mark);
      _apps = apps..addListener(_mark);
      _changed = true;
    }
    final changed = _changed;
    _changed = false;
    return changed;
  }

  void _mark() => _changed = true;

  void dispose() {
    _apps?.removeListener(_mark);
    _apps = null;
  }
}

class _SearchText {
  final Metadata metadata;
  final String rule;
  final String rulePayload;
  final List<String> chains;
  final List<String> labels;
  final String text;
  int pass = 0;

  _SearchText(TrackerInfo trackerInfo)
    : metadata = trackerInfo.metadata,
      rule = trackerInfo.rule,
      rulePayload = trackerInfo.rulePayload,
      chains = trackerInfo.chains,
      labels = _labelsOf(trackerInfo),
      text = SearchQuery.textOf(trackerInfo.searchFields);

  static List<String> _labelsOf(TrackerInfo trackerInfo) => system.isAndroid
      ? const []
      : processApps.searchLabelsOf(trackerInfo.metadata);

  bool hasLabelsOf(TrackerInfo trackerInfo) =>
      listEquals(labels, _labelsOf(trackerInfo));

  bool isFor(TrackerInfo trackerInfo) =>
      rule == trackerInfo.rule &&
      rulePayload == trackerInfo.rulePayload &&
      (identical(chains, trackerInfo.chains) ||
          listEquals(chains, trackerInfo.chains)) &&
      _searchesSame(metadata, trackerInfo.metadata);

  /// Whether [a] and [b] agree on every field [TrackerInfoExt.searchFields]
  /// reads, the process and its path giving the app labels among them.
  static bool _searchesSame(Metadata a, Metadata b) =>
      identical(a, b) ||
      (a.network == b.network &&
          a.host == b.host &&
          a.destinationIP == b.destinationIP &&
          a.destinationPort == b.destinationPort &&
          a.sourceIP == b.sourceIP &&
          a.sourcePort == b.sourcePort &&
          a.process == b.process &&
          a.processPath == b.processPath &&
          a.remoteDestination == b.remoteDestination &&
          a.destinationIPASN == b.destinationIPASN &&
          a.specialProxy == b.specialProxy &&
          a.specialRules == b.specialRules &&
          listEquals(a.destinationGeoIP, b.destinationGeoIP));
}
