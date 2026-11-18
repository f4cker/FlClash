import 'dart:io';

import 'package:flutter/services.dart';

/// A decryption script's `$notification.post`, as the Core sent it after
/// its rate limit.
class ScriptNotification {
  final String script;
  final String title;
  final String subtitle;
  final String body;

  const ScriptNotification({
    required this.script,
    required this.title,
    this.subtitle = '',
    this.body = '',
  });

  static ScriptNotification? fromData(Object? data) {
    if (data is! Map) return null;
    String text(String key) => switch (data[key]) {
      final String value => value,
      _ => '',
    };
    final notification = ScriptNotification(
      script: text('script'),
      title: text('title'),
      subtitle: text('subtitle'),
      body: text('body'),
    );
    if (notification.title.isEmpty &&
        notification.subtitle.isEmpty &&
        notification.body.isEmpty) {
      return null;
    }
    return notification;
  }

  Map<String, Object> toArguments() => {
    'script': script,
    // A notification with no title shows the script's name instead.
    'title': title.isEmpty ? script : title,
    'subtitle': subtitle,
    'body': body,
  };
}

class ScriptNotifier {
  const ScriptNotifier([this._channel = const MethodChannel(channelName)]);

  static const channelName = 'com.layoute.flash/script_notification';

  final MethodChannel _channel;

  Future<void> post(ScriptNotification notification) async {
    if (!Platform.isMacOS) return;
    await _channel.invokeMethod<void>('post', notification.toArguments());
  }
}
