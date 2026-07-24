# Workout Live Activity: design

Status: **agreed in brainstorm, not yet implemented.** Do not start building
until the open questions at the bottom are settled and the user says go.

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
- **No buttons in v1.** Tapping the card deep-links into the app (default
  behavior). App Intent buttons are a possible v2.

## Content and layout (Lock Screen / expanded island)

```
┌──────────────────────────────────────────┐
│ ⌗ Push Day A                       32:14 │  workout name + total elapsed, caption
│                                          │
│ Bench Press                    ● ● ○ ○ ○ │  exercise headline + set dots
│ Set 3 of 5: 8-10 reps @ 185 lbs          │  set + target line
│                                          │
│ REST      4:07                           │  count-up since last set, big, ticking
│ Slight incline, pause at chest           │  exercise note, 1 line, secondary
│ Next: Overhead Press                     │  small; see open questions
└──────────────────────────────────────────┘
```

- Workout name: caption size, header row. Total elapsed top-right, ticking.
- Current exercise: the headline.
- Set dots: filled per completed set. Fallback to plain text like `3/12` if
  the set count is too high to draw dots (threshold TBD in implementation,
  around 6 to 8).
- Set and target on one line. Note truncated to one line. Copy rules apply:
  no em dashes, no emoji, SF Symbols only.
- Content state must stay under ActivityKit's 4KB payload cap; truncate the
  note before sending.

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

## Open questions

1. **Set dots, text, or both?** Dots top-right plus "Set 3 of 5" text line,
   or dots only, or text only.
2. **"Next: <exercise>" always visible, or only on the last set** of the
   current exercise? (Last-set-only was the original pitch: contextual, less
   clutter.)
3. **Dart-to-ActivityKit bridge:** hand-rolled `MethodChannel` (about 100
   lines, no new dependency, mild preference) vs the `live_activities` pub
   package.
