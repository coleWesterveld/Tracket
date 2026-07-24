# Dev and prod builds side by side

The App Store app ("Tracket", `com.cole.tracket`) and a dev build
("Tracket Dev", `com.example.coleAppTesting`) coexist on the phone, each with
its own sandbox and SQLite database. Deploying dev updates the dev app in
place, so its history is preserved; the App Store app is never touched.

The old workflow of sed-ing `project.pbxproj` and reverting it is dead. Do
not resurrect it: it broke once the widget extension arrived (two bundle IDs
to swap, entitlements along for the ride) and once left dev IDs committed.

## Usage

```sh
scripts/deploy.sh dev            # release build on Kevin as Tracket Dev
scripts/deploy.sh dev "Phone 2"  # any other device name from `flutter devices`
scripts/deploy.sh prod           # App Store .ipa as Tracket
```

## How it works

Bundle ID and display name are xcconfig variables, resolved in
`ios/Flutter/AppIdentity.xcconfig`:

- `AppIdentity-Prod.xcconfig` is the committed default: `com.cole.tracket`,
  "Tracket". The widget extension's ID is derived as
  `$(APP_BUNDLE_ID).WorkoutWidget` in the project file.
- `AppIdentity-Dev.xcconfig` holds the dev identity.
- `AppIdentity-Local.xcconfig` is a gitignored override. `deploy.sh dev`
  writes it (one include line pointing at the dev file) for the duration of
  the run and deletes it on exit.

Because the override cannot be committed and is absent at rest, any build
run outside the script, including a bare `flutter build ipa`, is prod.

## Notes

- The dev app keeps its own database across deploys, same as any iOS app
  update. Real workout history lives in the App Store app and will not
  appear in the dev build. Expected, not a bug.
- Both flavors currently share the App Group
  `group.com.tracket.workoutwidget`. Live Activities do not use the group,
  so this is harmless today. If the home-screen widget (branch
  `feat/homescreen-widget`) ever ships, split the group per flavor first so
  the two apps cannot clobber each other's shared widget data.
- First dev deploy after the widget extension was added may hit a signing
  error for `com.example.coleAppTesting.WorkoutWidget` (new app ID plus App
  Group capability). If it does, open the project in Xcode once, select the
  WorkoutWidgetExtension target's Signing tab, and let automatic signing
  register it; the CLI works from then on.
