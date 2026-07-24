# Installing a dev build alongside the App Store app

The App Store copy of Tracket and a local dev build can't share a bundle
identifier — installing with the release ID overwrites the real app on the
phone (and its database). To keep both on the device at once, temporarily
swap the iOS bundle identifier to a dev-only one, build, then revert.

| | Bundle ID |
|---|---|
| Release / App Store | `com.cole.tracket` |
| Local dev build | `com.example.coleAppTesting` |

## Steps

1. Swap the identifier in all three Runner configs (Debug, Release, Profile):

   ```sh
   sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com.cole.tracket;/PRODUCT_BUNDLE_IDENTIFIER = com.example.coleAppTesting;/g' ios/Runner.xcodeproj/project.pbxproj
   ```

2. Build and install to the phone:

   ```sh
   flutter run --release -d Kevin
   ```

   `Kevin` is the phone's device name; `flutter devices` lists what's
   connected, and plain `flutter run --release` works when it's the only
   device attached.

3. Revert before committing:

   ```sh
   git checkout -- ios/Runner.xcodeproj/project.pbxproj
   ```

   This touches only the project file, so any other in-progress work in the
   tree is left alone. Confirm with `git status` that the pbxproj no longer
   shows as modified — committing the dev identifier would break the next
   App Store build.

## Notes

- The dev app gets its own sandbox and therefore its own **empty database**.
  Real workout history lives in the App Store app and will not appear in the
  dev build. That's expected, not a bug.
- To reverse the swap without discarding other edits to the project file, run
  the `sed` with the two identifiers exchanged instead of using `git checkout`.
- The `RunnerTests` target still uses the old template identifier
  (`com.example.firstapp.RunnerTests`). It never ships, so the swap above
  deliberately leaves it alone.
