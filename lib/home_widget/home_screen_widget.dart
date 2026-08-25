import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:firstapp/providers_and_settings/program_provider.dart';
import 'package:firstapp/providers_and_settings/settings_provider.dart';
import 'widget_snapshot.dart';

/// Which tab a widget tap should land on. The slugs match the strings the widget
/// puts in its `tracket://open?tab=` deep links, and the indexes match the
/// NavigationBar destinations in main.dart.
enum WidgetTab {
  workout('workout', 0),
  schedule('schedule', 1),
  analytics('analytics', 3);

  const WidgetTab(this.slug, this.pageIndex);

  final String slug;
  final int pageIndex;

  static WidgetTab? fromSlug(String? slug) {
    for (final tab in WidgetTab.values) {
      if (tab.slug == slug) return tab;
    }
    return null;
  }
}

/// Dart half of the home screen widget bridge. The native half is
/// ios/Runner/HomeWidgetBridge.swift; the widget itself is rendered by
/// WorkoutWidgetExtension (ios/WorkoutWidget/ProgramWidget*.swift).
///
/// The widget cannot run Dart or open the app's database, so the app writes a
/// plain JSON snapshot into the shared App Group and the widget reads only that.
/// Everything here is fire-and-forget and a no-op off iOS: a home screen widget
/// is a nice-to-have and must never be able to break the app.
class HomeScreenWidget {
  HomeScreenWidget._();

  static const MethodChannel _channel = MethodChannel('tracket/home_widget');

  /// Coalesces the burst of notifications a single user action can produce, most
  /// obviously dragging an exercise up a list.
  static const Duration _debounce = Duration(milliseconds: 1200);

  static Future<void>? _pending;
  static bool _queued = false;

  /// Rebuilds the snapshot and hands it to the widget, at most once per
  /// [_debounce] window. Safe to call from a listener that fires on every frame
  /// of a drag.
  static void scheduleRefresh({
    required Profile profile,
    required SettingsModel settings,
  }) {
    if (!_isSupported) return;

    if (_pending != null) {
      // A refresh is already waiting out its window. Flag it so the snapshot is
      // rebuilt once more afterwards: whatever changed just now is not in the
      // payload that is about to be sent.
      _queued = true;
      return;
    }

    _pending = Future.delayed(_debounce, () async {
      _pending = null;
      await _push(profile: profile, settings: settings);
      if (_queued) {
        _queued = false;
        scheduleRefresh(profile: profile, settings: settings);
      }
    });
  }

  /// Rebuilds and pushes straight away, skipping the debounce. For the moments
  /// where a stale widget would be obvious: launch, backgrounding, and finishing
  /// a workout.
  static Future<void> refreshNow({
    required Profile profile,
    required SettingsModel settings,
  }) async {
    if (!_isSupported) return;
    await _push(profile: profile, settings: settings);
  }

  static Future<void> _push({
    required Profile profile,
    required SettingsModel settings,
  }) async {
    try {
      final String json = await buildWidgetSnapshotJson(
        profile: profile,
        useMetric: settings.useMetric,
      );
      await _channel.invokeMethod('writeSnapshot', {'json': json});
    } on MissingPluginException {
      // Native build without the bridge (hot restart against an old binary).
    } on PlatformException catch (e) {
      debugPrint('Home widget writeSnapshot failed: ${e.message}');
    } catch (e) {
      // A snapshot that cannot be built is not worth an exception reaching the
      // UI. The widget keeps showing the last good one.
      debugPrint('Home widget snapshot failed: $e');
    }
  }

  /// The tab a widget tap asked for, or null. Returns it once, then null again.
  ///
  /// The tap opens `tracket://open?tab=schedule`, which the native side records
  /// as a flag rather than pushing to Dart, because the URL can land during a
  /// cold launch before the engine exists. Draining it on resume covers that and
  /// a warm foreground alike: the same shape as the Live Activity Finish pill.
  static Future<WidgetTab?> takePendingTab() async {
    if (!_isSupported) return null;
    try {
      final String? slug = await _channel.invokeMethod<String>('takePendingTab');
      return WidgetTab.fromSlug(slug);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Home widget takePendingTab failed: ${e.message}');
      return null;
    }
  }

  static bool get _isSupported => !kIsWeb && Platform.isIOS;
}
