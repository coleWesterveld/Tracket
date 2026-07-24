# iOS widget: where things stand

Updated 2026-07-24. Supersedes the earlier handoff note that described the
abandoned home-screen widget attempt mid-cleanup.

## Summary

The original attempt built a WidgetKit **home-screen widget** when what was
wanted was a **Live Activity** (ActivityKit). The home-screen widget work is
now parked, complete and self-contained, on branch **`feat/homescreen-widget`**
(commit `8a85f14`). Merge that branch back if the home-screen widget is ever
resumed; nothing of it remains on `main`.

## What main keeps (shared scaffolding, all committed)

The Live Activity is declared inside a widget extension target, so the manual
Xcode setup carries over:

- `WorkoutWidgetExtension` target (product name `WorkoutWidget`),
  deployment target 17.6. Runner stays at 13.0.
- App Group `group.com.tracket.workoutwidget` on both targets, via
  `ios/Runner/Runner.entitlements` and `ios/WorkoutWidgetExtension.entitlements`.
  Note: ActivityKit itself does not need the App Group; it is kept for any
  future widget or shared-defaults use.
- `ios/WorkoutWidget/` is a `PBXFileSystemSynchronizedRootGroup`: any Swift
  file dropped in that folder joins the target automatically, no pbxproj edits.
- `ios/WorkoutWidget/WorkoutWidgetBundle.swift` currently ships an inert
  `PlaceholderWidget` so the target compiles. It gets replaced by the Live
  Activity's `ActivityConfiguration`.
- Bundle IDs are back on production values: `com.cole.tracket` and
  `com.cole.tracket.WorkoutWidget`.

## What was stripped from main

- `WorkoutWidget.swift` home-screen views, `WorkoutWidgetControl.swift`
  (unused Control Center boilerplate).
- `lib/notifications/workout_widget_service.dart` and its 4 call sites in
  `active_workout_provider.dart` (the file is back at its pre-widget state;
  those 4 state-change moments are the map for Live Activity updates).
- The `home_widget` dependency and its pod.

## Toolchain gotcha (fixed, do not regress)

Creating the extension target rewrote `project.pbxproj` with
`objectVersion = 70` (Xcode 16.0 format). The installed CocoaPods stack
(cocoapods 1.16.2 / xcodeproj 1.27.0 on system Ruby) does not know `70`, only
`63` and `77`, so every `pod install` (and therefore every `flutter run`)
died with:

    Unable to find compatibility version string for object version `70`.

Fix applied: `objectVersion` is now `77` (Xcode 16.3+ format), which the gem
and Xcode 26 both understand. If Xcode ever rewrites it back to 70, bump it
to 77 again.

## Live Activity: not started

Design and open questions live in `docs/live-activity-design.md`. Nothing of
the Live Activity is implemented yet: no `NSSupportsLiveActivities` in
`ios/Runner/Info.plist`, no `ActivityAttributes`, no `ActivityConfiguration`,
no Dart bridge.
