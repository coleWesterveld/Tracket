import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart half of the workout Live Activity bridge. The native half is
/// ios/Runner/LiveActivityBridge.swift; the card itself is rendered by
/// WorkoutWidgetExtension (ios/WorkoutWidget/WorkoutLiveActivity.swift).
///
/// Every method is fire-and-forget and a no-op off iOS: the Live Activity is
/// a nice-to-have, so it must never be able to break the workout flow.
class WorkoutLiveActivity {
  WorkoutLiveActivity._();

  static const MethodChannel _channel =
      MethodChannel('tracket/workout_live_activity');

  /// Requests the activity when a workout starts (or re-attaches to one that
  /// survived an app relaunch, when restoring a snapshot).
  static void start(Map<String, dynamic> state) => _invoke('start', state);

  /// Pushes a new content state: set logged, exercise change, pause/resume.
  static void update(Map<String, dynamic> state) => _invoke('update', state);

  /// Ends the activity on finish or discard.
  static void end() => _invoke('end');

  static Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _channel.invokeMethod(method, args);
    } on MissingPluginException {
      // Native build without the bridge (hot restart against an old binary).
    } on PlatformException catch (e) {
      debugPrint('Live Activity $method failed: ${e.message}');
    }
  }
}
