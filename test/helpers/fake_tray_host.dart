import 'dart:async';
import 'dart:typed_data';

import 'package:rust_api/tray.dart';

class FakeTrayHost implements TrayHost {
  final List<TrayContent> shown = [];
  final List<String> titles = [];
  int hideCount = 0;
  int openMenuCount = 0;
  bool showResult = true;

  /// Replaces [showResult] for one show, e.g. to emit a signal while the
  /// show is still pending.
  bool Function(TrayContent content)? onShow;

  /// What an accepted show with a menu generation (macOS) reports back, as
  /// the native side does once the call has returned. Defaults to the new
  /// generation alone.
  List<int> Function(int generation)? generationsForShow;
  int? trackingGeneration;

  final StreamController<TraySignal> _signals =
      StreamController<TraySignal>.broadcast(sync: true);

  TrayContent? get lastShown => shown.isEmpty ? null : shown.last;

  int get callCount => shown.length + titles.length + hideCount + openMenuCount;

  void clear() {
    shown.clear();
    titles.clear();
    hideCount = 0;
    openMenuCount = 0;
  }

  void emit(TraySignalKind kind, [int itemId = 0, int menuGeneration = 0]) {
    _signals.add(
      TraySignal(
        kind: kind,
        itemId: itemId,
        menuGeneration: menuGeneration,
        generations: Uint32List(0),
      ),
    );
  }

  void emitMenuGenerations(List<int> generations, {int? tracking}) {
    _signals.add(
      TraySignal(
        kind: TraySignalKind.menuGenerations,
        itemId: 0,
        menuGeneration: 0,
        generations: Uint32List.fromList(generations),
        trackingGeneration: tracking,
      ),
    );
  }

  @override
  Stream<TraySignal> signals() => _signals.stream;

  @override
  bool show(TrayContent content) {
    shown.add(content);
    final accepted = onShow?.call(content) ?? showResult;
    final generation = content.menuGeneration;
    if (accepted && generation != 0) {
      final generations = generationsForShow?.call(generation) ?? [generation];
      final tracking = trackingGeneration;
      scheduleMicrotask(
        () => emitMenuGenerations(generations, tracking: tracking),
      );
    }
    return accepted;
  }

  @override
  bool setTitle(String title) {
    titles.add(title);
    return true;
  }

  @override
  void hide() {
    hideCount++;
  }

  @override
  bool openMenu() {
    openMenuCount++;
    return true;
  }
}
