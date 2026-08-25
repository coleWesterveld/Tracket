# iOS home screen widgets

One configurable widget, two sizes, three views. Long press the widget, Edit
Widget, and pick what it shows.

Nothing here is about the workout in progress: that is the Live Activity's job
(`docs/live-activity-design.md`). A home screen widget that only says something
during a session is blank almost all of the time, which is what sank the first
attempt (see `docs/ios-widget-handoff.md`).

## The three views

| View | Small | Medium | Tap opens |
|---|---|---|---|
| **Next up** | Day number, title, when, exercise and set count | Adds the exercise list with rep targets | Workout tab |
| **This week** | Sun to Sat strip, today ringed, sessions done | Adds next week, and the program title | Schedule tab |
| **Goals** | The goal closest to done, with its bar | Up to three goals | Analytics tab |

"Next up" is the default: it is never empty, needs no history, and is the only
one that changes what you do in the next hour.

### Reading the week strip

Four states, and colour is never the only signal, because an iOS 18 tinted home
screen collapses every day colour to one hue:

- **Filled** in the day's colour: logged.
- **Outlined** in the day's colour: planned, still to come.
- **Faded outline**: planned, and the day has gone by. A missed session.
- **Filled grey**: something was logged on a day the program did not schedule,
  which is what a free workout looks like from here.
- **Ring**: today. Drawn outside the status ring, which is inset to keep the two
  from reading as one thick smudge.

## How the data gets there

The widget extension cannot run Dart, reach the app's SQLite file, or query
anything. So the app writes one JSON blob into the shared App Group and the
widget reads only that.

```
lib/home_widget/widget_snapshot.dart     builds the payload
lib/home_widget/home_screen_widget.dart  MethodChannel "tracket/home_widget"
ios/Runner/HomeWidgetBridge.swift        writes it, reloads timelines
        │
        │  UserDefaults(suiteName: "group.com.tracket.workoutwidget")
        │  key "program_snapshot"
        ▼
ios/WorkoutWidget/TracketSnapshot.swift  decodes it, runs the schedule maths
ios/WorkoutWidget/ProgramWidget.swift    intent, timeline, widget declaration
ios/WorkoutWidget/ProgramWidgetViews.swift  the three views, both sizes
```

No new Dart package and no new pod: the bridge is about ninety lines of Swift in
the pattern `LiveActivityBridge` already set. The `WorkoutWidget` folder is a
`PBXFileSystemSynchronizedRootGroup`, so its Swift files joined the extension
target on their own; `HomeWidgetBridge.swift` needed four hand-written entries in
`project.pbxproj` because the Runner group is a plain one.

### The split maths lives in Swift, deliberately

The payload carries the day list, `origin` and `splitLength` as they are. The
widget runs the same mapping `lib/other_utilities/events.dart` runs:

```
daysBetween(origin, day) % splitLength == dayOrder
```

That is what lets the widget roll over to the right workout at midnight when the
app has not been opened for a week. Precomputing "tomorrow is Pull" in the
payload would make the widget show whatever tomorrow meant the last time the app
happened to be open, which is the bug that gets widgets deleted.

Dart's `%` on integers is never negative. The Swift side floors its modulo the
same way so dates before the origin agree with the app.

### What IS precomputed

Anything the widget cannot derive, or would derive differently:

- **Rep targets** are formatted with the app's own `formatRepRange`, so a widget
  row can never disagree with the program page. An exercise with several
  different rep targets falls back to a plain set count rather than picking one.
- **Goal progress** is the RPE-adjusted estimated 1RM the analytics page already
  computes, sorted closest to done first so the small widget takes the first one.
- **Weights** are converted to the user's unit here, so no conversion logic is
  duplicated in Swift.
- **Logged days** come from `getDaysWithHistory`, deduplicated: that query groups
  by the raw timestamp, so a day with three sessions comes back three times.
- **Day numbers** are the day's place in the split, which is the "Day 3" the
  schedule page shows. That is not `dayOrder`, and the two differ the moment the
  split has rest days in it.

### When it refreshes

`HomeScreenWidget.refreshNow` on the moments a stale widget would be obvious,
and `scheduleRefresh` (debounced 1.2s) for everything else:

| Trigger | Where |
|---|---|
| App launch | `MainScaffoldState.initState`, after Profile has initialised |
| Foreground, background | `didChangeAppLifecycleState` |
| Workout finished | `finishActiveWorkout` |
| Program or schedule edit | a `Profile` listener, hence the debounce |
| Goal added, edited, deleted | `analytics_page.dart`, since goals are not in Profile |

The bridge skips the write and the reload when the payload has not changed, so
the frequent no-op refreshes cost nothing against the timeline budget.

Timeline entries are one per local midnight for a week ahead, `policy: .atEnd`.
Nothing on these views ticks faster than a day.

### Tapping a widget

Each view deep-links to its tab through `tracket://open?tab=<slug>`.
`HomeWidgetBridge` records the tab rather than pushing it to Dart, because the
URL can land during a cold launch before the engine exists; the Dart side drains
the flag on its next resume and sets `UiStateProvider.currentPageIndex`. Same
shape as the Live Activity's Finish pill, and the URL scheme it registered is
reused as is.

Unknown tabs are dropped but still open the app. A URL is data from outside the
app, so the tab is checked against an allowlist.

## Empty states

Every one names what to do about it, and none of them is a blank card:

- No snapshot yet: "Open Tracket".
- No scheduled days: "Nothing scheduled". "This week" still draws the strip, so
  it degrades to a plain calendar rather than a message.
- No goals: "No goals yet".

## Schema versioning

`widgetSnapshotSchema` in the Dart and `supportedSchema` in
`TracketSnapshot.swift` must match. A blob whose version the widget does not
recognise is ignored rather than half-read, because an old widget binary can
outlive an app update. Bump both when the payload shape changes incompatibly.

## Android

There is none. No Glance or AppWidget code exists in the Android project, so this
is an iOS feature until someone writes a second implementation against the same
snapshot. Nothing in the Dart is iOS-specific beyond the channel, which no-ops
off iOS.

## Known limits

- **iOS 17 and up.** The extension target is already at 17.6, and
  `AppIntentConfiguration` needs 17. The app itself stays at 13.
- **Small and medium only.** Larger sizes want a different information density,
  which is a separate design job for very little extra reach.
- **`splitLength` changes may lag.** It is a plain field on `Profile` with no
  notification, so an edit to it is picked up on the next lifecycle refresh
  rather than immediately.
