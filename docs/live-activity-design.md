# Workout Live Activity: design

Status: **implemented.** The open questions at the bottom are settled; answers
recorded there. Key files:

- `ios/Shared/WorkoutActivityAttributes.swift`: attributes + content state,
  compiled into both Runner and WorkoutWidgetExtension (explicit references
  in project.pbxproj).
- `ios/WorkoutWidget/WorkoutLiveActivity.swift`: the card UI.
- `ios/Runner/LiveActivityBridge.swift`: ActivityKit calls, driven by the
  `tracket/workout_live_activity` MethodChannel.
- `lib/live_activity/workout_live_activity.dart`: Dart half, no-op off iOS.
- `lib/workout_page/finish_workout.dart`: `finishActiveWorkout()`, shared by
  the in-app Finish button and the card's Finish pill.
- `lib/providers_and_settings/active_workout_provider.dart`: pushes state
  from `_syncLiveActivity()` at the event call sites.

One deviation from the mock below: the target line has no "@ 185 lbs". The
data model plans rep ranges and RPE, not weight, so the line reads
"8-10 reps @ RPE 8". Pause/resume also pushes an update, since pausing shifts
the timestamp anchors the clocks render from.

Reworked 2026-08-25 to match the rest of the app: app ground instead of the
system default black, the Tracket mark instead of an SF Symbol dumbbell, a
two-column body, orange dots in place of the "Set 3 of 5" line, and a Finish
pill. See "Content and layout" below.

This is an iOS **Live Activity** (ActivityKit): the persistent card on the
Lock Screen and in the Dynamic Island while a workout is in progress, like a
delivery tracker or the Clock timer. It is not a home-screen widget (that
attempt is parked on `feat/homescreen-widget`, see `ios-widget-handoff.md`).

## Core decisions

- **Exists only while a workout is active.** `Activity.request` when the
  workout starts, `Activity.end` on finish or discard. No idle state, ever.
- **One layout, no phases.** The app does not track "doing a set" vs
  "resting"; the user just logs each set after doing it. So the card has a
  single always-on layout centered on time since the last logged set.
- **Rest is a count-up tracker, not a countdown.** No target, no draining
  progress bar, no "+30s" or "skip" buttons. Big ticking clock counting up
  from the last set log.
- **Timers render natively.** `Text(timerInterval:)` ticks every second with
  zero app updates and zero battery cost. The app only pushes an update on
  real events: set logged, exercise changed, workout ended. Sync is inherent:
  Flutter passes the epoch timestamps and the system renders from them.
- **One button: Finish.** A pill on the note row opens `tracket://finish`,
  which AppDelegate hands to `LiveActivityBridge`; the bridge only records a
  flag and the Dart side drains it on its next resume, then runs the same
  `finishActiveWorkout()` the in-app button does. Deliberately not a
  `LiveActivityIntent` that ends the workout on the Lock Screen: the summary
  is where a workout actually closes, an intent can only stamp a flag the app
  might not drain for hours, and a pocket tap should not be able to end a
  session with no way back. Tapping anywhere else on the card still just opens
  the app.

## Content and layout (Lock Screen / expanded island)

```
┌──────────────────────────────────────────┐
│ T Push Day A                       32:14 │  mark + workout name + total elapsed
│                                          │
│ Bench Press                              │  exercise headline
│ ● ● ○ ○ ○  8-10 reps @ RPE 8       4:07  │  dots + target | rest count-up
│                                          │
│ Slight incline, pause at chest   ⟨Finish⟩│  note, 1 line, + the Finish pill
│ Next: Overhead Press                     │  last set only
└──────────────────────────────────────────┘
```

Two columns. The left one stacks the exercise headline over the dots-and-target
line; the right one holds the rest clock, sized so its box matches those two
rows and sitting directly under the elapsed clock, so both times read as one
column. That is one row shorter than the original stack, which matters: the
Lock Screen presentation caps around 160pt and the five-row version was close
to it.

- Ground is `backgroundGrey` #1C1C1C via `.activityBackgroundTint`. Without it
  the card falls back to ActivityKit's default material, which sits near pure
  black and reads as a different app. The Dynamic Island cannot be tinted; it
  is black by design so it blends into the sensor cutout.
- Header mark is the Tracket logo (`TracketMark` in the widget's asset
  catalogue, cropped to the glyph), rendered as a template tinted
  `primaryBlue` so it tracks the palette rather than the source PNG.
- Rest clock is 44pt rounded semibold with no label. At that size against the
  header's 12pt it is not the same kind of element as the elapsed time, so the
  word was the only glyph in the card carrying no data. Its width is capped
  with `minimumScaleFactor`, because a forgotten set turns "4:07" into
  "1:04:07" and `Text(timerInterval:)` reserves room for the widest value its
  range can produce.
- Set dots are 9pt in `accentOrange`, and they lead the target line rather
  than sitting opposite the exercise name. Above 5 sets they stop leaving room
  for the target, so they fall back to a compact "3/12" in the same orange.
- Note truncated to one line. Copy rules apply: no em dashes, no emoji.
- Content state must stay under ActivityKit's 4KB payload cap; the note is cut
  to 140 characters before sending.

## Dynamic Island

All four presentations are required by the API; the content is simple:

- **Compact** leading: app glyph. Trailing: the rest count-up, ticking.
- **Minimal**: the rest count-up if it fits, else the glyph.
- **Expanded**: the Lock Screen layout above.

## Plumbing (settled at high level)

- Declared in the existing `WorkoutWidgetExtension` target: an
  `ActivityAttributes` struct (static: workout name, start time) plus
  `ContentState` (exercise, set index and count, target, note, last-set
  timestamp), and an `ActivityConfiguration` in `WorkoutWidgetBundle.swift`
  replacing the placeholder widget.
- `NSSupportsLiveActivities` in `ios/Runner/Info.plist`.
- Update moments on the Dart side: the 4 state-change call sites previously
  identified in `active_workout_provider.dart` (workout start, set logged,
  exercise change, workout end).
- System limit: iOS ends Live Activities after 8 hours. Fine for workouts.
- If the rest clock is up while the app is suspended, the tick keeps
  rendering regardless; layout changes only happen on the next app event,
  which is fine since layout only changes when the user logs something.

## Open questions (settled 2026-07-24)

1. **Set dots, text, or both?** Dots only, leading the target line. The
   "Set 3 of 5" text was cut in the 2026-08-25 rework: it duplicated what the
   dots already say. Fallback to "3/12" text above 5 sets.
2. **"Next: <exercise>" always visible, or only on the last set?**
   Last set only.
3. **Dart-to-ActivityKit bridge:** hand-rolled `MethodChannel`, no new
   dependency.
