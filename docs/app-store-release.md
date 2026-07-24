# Shipping an App Store update

How to get a new version of Tracket onto the App Store. Companion to
`dev-build-on-device.md`, which covers dev builds on the phone.

The app now embeds an app extension (`WorkoutWidgetExtension`, which renders
the workout Live Activity). That changes very little about releasing, because
the extension ships inside the app binary and is never submitted separately.
The parts it does change are called out under "The widget extension" below.

## Checklist

```sh
# 1. Bump the version in pubspec.yaml, e.g. 1.1.0+2 -> 1.2.0+3
# 2. Sanity check
flutter analyze
scripts/deploy.sh dev          # run it on the phone, exercise the new work

# 3. Build the App Store archive
scripts/deploy.sh prod         # -> build/ios/ipa/*.ipa

# 4. Upload with Transporter, then finish in App Store Connect
```

## 1. Bump the version

`pubspec.yaml` is the single source of truth:

```yaml
version: 1.2.0+3
```

The part before `+` is the version users see (`CFBundleShortVersionString`).
The part after is the build number (`CFBundleVersion`). Rules App Store
Connect enforces:

- The build number must be higher than any build already uploaded, even one
  you deleted or never submitted. It is easiest to just always increment.
- The version must be higher than the currently released version. Reuploading
  a build number under the same version is rejected.

Both the app and the widget extension read these numbers from here, so there
is nothing else to edit. That wiring is deliberate; see the note at the end.

## 2. Check before you build

```sh
flutter analyze
scripts/deploy.sh dev
```

Install on the phone and actually use the feature you are shipping. The dev
build is a release build with its own database, so it behaves like the real
thing without touching your live workout history.

For a Live Activity change specifically, the things worth checking are the
ones that only appear off the workout screen: lock the phone mid workout and
confirm the card is there, log a set and confirm the card updates, then hit
Finish and confirm the card disappears.

## 3. Build the archive

```sh
scripts/deploy.sh prod
```

This runs `flutter build ipa` with the prod identity (`com.cole.tracket`,
"Tracket") and leaves an `.ipa` in `build/ios/ipa/`. The script removes the
dev override first, so a prod build can never pick up dev bundle IDs.

If signing fails, open `ios/Runner.xcworkspace` in Xcode once, select each of
the Runner and WorkoutWidgetExtension targets, and let automatic signing
sort out the profiles. The CLI works from then on.

## 4. Upload

Easiest path is the Transporter app from the Mac App Store: sign in with your
Apple ID, drag in the `.ipa`, press Deliver.

CLI alternative, which needs an app-specific password from
appleid.apple.com rather than your account password:

```sh
xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios \
  -u colewesterveld@gmail.com -p "$APP_SPECIFIC_PASSWORD"
```

The build then takes anywhere from a few minutes to an hour to finish
processing before it appears in App Store Connect.

## 5. Submit in App Store Connect

1. Open the app, then the iOS App section, and add a new version with the
   same version string you put in `pubspec.yaml`.
2. Fill in "What's New in This Version". Release notes are user-facing copy,
   so the project copy rules apply: no em dashes, no emoji.
3. Attach the processed build.
4. Screenshots are only required if the visuals changed enough to make the
   existing ones misleading. A Live Activity does not appear in listing
   screenshots unless you decide to show it.
5. Answer the export compliance question. Tracket does not use non exempt
   encryption.
6. Submit for review. Reviews commonly land within a day, but leave room for
   longer.

Consider phased release for anything risky. It rolls the update out over
seven days and can be paused, which a plain release cannot.

## The widget extension

What genuinely changes now that the app embeds an extension:

**Versions must match, and now do automatically.** An extension whose
`CFBundleShortVersionString` or `CFBundleVersion` differs from its host app
is rejected at upload, with a message naming the appex and both values. This
bit us once: the extension was pinned at 1.0 (1) while the app tracked
pubspec. Both now derive from `FLUTTER_BUILD_NAME` and
`FLUTTER_BUILD_NUMBER`, so bumping pubspec is enough. If you ever see that
rejection again, check that `ios/Flutter/AppIdentity.xcconfig` still includes
`Generated.xcconfig`, since that include is what feeds the extension target
those variables.

**Two bundle IDs get signed, not one.** The extension is
`$(APP_BUNDLE_ID).WorkoutWidget`. Both need an App ID in the developer portal
with the App Group capability. Automatic signing registers them, but the
first archive after a signing change may need one pass through Xcode.

**Nothing extra to declare.** The Live Activity updates locally from the app,
with no push tokens, so it needs no push notification entitlement and no
server. `NSSupportsLiveActivities` is already in `ios/Runner/Info.plist`.

**Give App Review a hint.** The Live Activity is invisible unless the
reviewer starts a workout and then leaves or locks the screen, which they
have no reason to do. Put a line in App Review Notes, for example: "To see
the Live Activity, start any workout, then lock the screen. The card shows
the current exercise and time since the last logged set."

**The extension is not submitted separately.** It rides inside the app. There
is no second review, no separate listing.

## If the upload is rejected

- **Version mismatch naming the appex.** See above. Check the xcconfig
  include, rebuild, upload with a fresh build number.
- **Build number already used.** Bump the number after `+` in pubspec and
  rebuild. Uploaded build numbers are burned permanently.
- **Missing or invalid signature on the appex.** The extension's App ID or
  its App Group capability is not set up. Open the project in Xcode, select
  the WorkoutWidgetExtension target's Signing tab, and let it register.
- **Invalid bundle, wrong bundle ID.** Almost always a stale
  `ios/Flutter/AppIdentity-Local.xcconfig` left behind by an interrupted dev
  deploy. Delete it and rebuild. `scripts/deploy.sh prod` removes it for you.
