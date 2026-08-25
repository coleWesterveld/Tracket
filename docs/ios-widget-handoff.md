# iOS widget: where things stand

Historical note. Updated 2026-08-25.

Both widgets now ship. **The live document for the home screen widget is
`docs/home-screen-widgets.md`**; this file is kept for the Xcode setup notes and
the toolchain gotcha further down, which still apply.

## Summary

The first attempt built a WidgetKit **home-screen widget** when what was wanted
was a **Live Activity** (ActivityKit), and it showed the workout in progress:
current exercise, set number, rest timer. That made it blank whenever a session
was not running, which is most of the time. It was parked on branch
`feat/homescreen-widget` (commit `8a85f14`) and never merged.

The home screen widget was rebuilt from scratch in 2026-08 as a program-level
widget instead: next workout, this week, goal progress. It shares the extension
target and the App Group described below, and reuses the `tracket://` URL scheme
the Live Activity registered, but none of the parked branch's code. That branch
can be deleted.

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
- `ios/WorkoutWidget/WorkoutWidgetBundle.swift` now ships both widgets:
  `ProgramWidget` (home screen) and `WorkoutLiveActivity`.
- Bundle IDs are back on production values: `com.cole.tracket` and
  `com.cole.tracket.WorkoutWidget`.

## What was stripped from main

- `WorkoutWidget.swift` home-screen views, `WorkoutWidgetControl.swift`
  (unused Control Center boilerplate).
- `lib/notifications/workout_widget_service.dart` and its 4 call sites in
  `active_workout_provider.dart` (the file is back at its pre-widget state;
  those 4 state-change moments are the map for Live Activity updates).
- The `home_widget` dependency and its pod. It stayed out: the rebuilt widget
  uses a hand-written MethodChannel instead, so there is no pod to install.

## Toolchain gotcha (do not regress)

Creating the extension target rewrote `project.pbxproj` with
`objectVersion = 70` (Xcode 16.0 format). The installed CocoaPods stack
(cocoapods 1.16.2 / xcodeproj 1.27.0 on system Ruby) does not know `70`, so
every `pod install` (and therefore every `flutter run`) died with:

    Unable to find compatibility version string for object version `70`.

The file currently sits at `objectVersion = 54`, which the gem understands and
`pod install` is happy with. The rule is only that it must not go back to `70`:
if Xcode ever rewrites it, set it to a version the gem knows (`54`, `63` or
`77`).

Adding a Swift file under `ios/Runner/` means hand-editing this file, since the
Runner group is a plain `PBXGroup`. Four entries are needed: a `PBXBuildFile`, a
`PBXFileReference`, an entry in the group's `children`, and one in the target's
`PBXSourcesBuildPhase`. Copy the shape of the `LiveActivityBridge.swift` lines,
then check the result parses with

    ruby -rxcodeproj -e 'Xcodeproj::Project.open("ios/Runner.xcodeproj")'

Files under `ios/WorkoutWidget/` need none of this.

## Live Activity

Implemented. Design notes in `docs/live-activity-design.md`; the code is
`ios/WorkoutWidget/WorkoutLiveActivity.swift`,
`ios/Runner/LiveActivityBridge.swift`,
`ios/Shared/WorkoutActivityAttributes.swift` and
`lib/live_activity/workout_live_activity.dart`.
