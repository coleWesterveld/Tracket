// workout_widget_service.dart
//
// Manages the iOS home-screen widget for an active workout session.
// Uses the home_widget package to write data into an App Group shared
// UserDefaults container that the WorkoutWidget extension (Swift) reads.
//
// SETUP REQUIRED (one-time, in Xcode):
//   1. Add a Widget Extension target named "WorkoutWidget".
//   2. Enable an App Group (e.g. "group.com.tracket.workoutwidget") on both
//      the Runner target and the WorkoutWidget target.
//   3. Set the kAppGroupId constant below to match.
//   4. The Swift widget source lives in ios/WorkoutWidget/.
//
// Once set up, call WorkoutWidgetService.update() whenever workout state
// changes and WorkoutWidgetService.clear() when a workout ends.

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class WorkoutWidgetService {
  // Must match the App Group configured in Xcode for both Runner and WorkoutWidget targets.
  static const String kAppGroupId = 'group.com.tracket.workoutwidget';

  // Widget name must match the struct name in WorkoutWidget.swift.
  static const String kWidgetName = 'WorkoutWidget';

  /// Saves current workout state and refreshes the iOS widget.
  ///
  /// [currentExercise]   Name of the exercise being performed right now.
  /// [setInfo]           E.g. "Set 2 of 4 — 8–10 reps @ RPE 8".
  /// [nextExercise]      Name of the upcoming exercise (null = none / last exercise).
  /// [elapsedSeconds]    Total workout elapsed time in seconds.
  /// [restSeconds]       Seconds since the last set was logged (rest timer). -1 = not resting.
  /// [isResting]         True when the user is between sets.
  static Future<void> update({
    required String currentExercise,
    String setInfo = '',
    String? nextExercise,
    int elapsedSeconds = 0,
    int restSeconds = -1,
    bool isResting = false,
  }) async {
    if (!defaultTargetPlatform.toString().contains('iOS')) {
      // Widget only exists on iOS — bail silently on other platforms.
      if (kDebugMode) debugPrint('[WorkoutWidget] Skipping update — not iOS');
      return;
    }

    try {
      await HomeWidget.setAppGroupId(kAppGroupId);

      await HomeWidget.saveWidgetData<String>('current_exercise', currentExercise);
      await HomeWidget.saveWidgetData<String>('set_info', setInfo);
      await HomeWidget.saveWidgetData<String>('next_exercise', nextExercise ?? '');
      await HomeWidget.saveWidgetData<int>('elapsed_seconds', elapsedSeconds);
      await HomeWidget.saveWidgetData<int>('rest_seconds', restSeconds);
      await HomeWidget.saveWidgetData<bool>('is_resting', isResting);
      await HomeWidget.saveWidgetData<bool>('is_active', true);

      await HomeWidget.updateWidget(
        iOSName: kWidgetName,
        qualifiedAndroidName: '', // iOS-only
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[WorkoutWidget] update error: $e');
    }
  }

  /// Clears the widget (call when workout ends or is cancelled).
  static Future<void> clear() async {
    if (!defaultTargetPlatform.toString().contains('iOS')) return;

    try {
      await HomeWidget.setAppGroupId(kAppGroupId);
      await HomeWidget.saveWidgetData<bool>('is_active', false);
      await HomeWidget.saveWidgetData<String>('current_exercise', '');
      await HomeWidget.saveWidgetData<String>('set_info', '');
      await HomeWidget.saveWidgetData<String>('next_exercise', '');

      await HomeWidget.updateWidget(
        iOSName: kWidgetName,
        qualifiedAndroidName: '',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[WorkoutWidget] clear error: $e');
    }
  }
}
