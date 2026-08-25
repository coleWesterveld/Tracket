// WorkoutLiveActivity.swift
//
// The workout Live Activity: the Lock Screen card and Dynamic Island shown
// while a workout is in progress. Layout per docs/live-activity-design.md.
//
// Both timers render natively via Text(timerInterval:), so they tick every
// second with zero app updates; the app only pushes a new content state on
// real events (set logged, pause, exercise change, workout end).

import ActivityKit
import SwiftUI
import WidgetKit

/// The app's primaryBlue (lib/theme/app_colours.dart), so the card reads as
/// part of the same product.
let tracketBlue = Color(red: 26 / 255, green: 120 / 255, blue: 235 / 255)

/// The app's accentOrange, used for the set dots.
let tracketOrange = Color(red: 242 / 255, green: 133 / 255, blue: 0 / 255)

/// The app's backgroundGrey. Without this the card falls back to ActivityKit's
/// default material, which sits near pure black and reads as a different app.
let tracketGround = Color(red: 28 / 255, green: 28 / 255, blue: 28 / 255)

/// Deep link behind the Finish pill. AppDelegate hands it to LiveActivityBridge,
/// which flags it for the Dart side to drain on the next resume.
private let finishURL = URL(string: "tracket://finish")!

/// Open-ended range for a count-up timer. iOS ends Live Activities at 8 hours
/// anyway, so the bound is never visible.
private func countUp(from start: Date) -> ClosedRange<Date> {
    start...start.addingTimeInterval(8 * 60 * 60)
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock Screen / banner presentation.
            VStack(alignment: .leading, spacing: 6) {
                WorkoutHeader(name: context.attributes.workoutName, startedAt: context.state.startedAt)
                WorkoutCardBody(state: context.state)
                WorkoutCardFooter(state: context.state, showFinish: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .activityBackgroundTint(tracketGround)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        TracketMark()
                        Text(context.attributes.workoutName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedClock(startedAt: context.state.startedAt)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        WorkoutCardBody(state: context.state)
                        // The island has no room to spare, and tapping it
                        // already opens the app, so the pill stays off it.
                        WorkoutCardFooter(state: context.state, showFinish: false)
                    }
                }
            } compactLeading: {
                TracketMark()
            } compactTrailing: {
                Text(timerInterval: countUp(from: context.state.lastSetAt), countsDown: false)
                    .font(.caption2)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 44)
            } minimal: {
                // The minimal slot is too small for a ticking clock to stay
                // legible, so it falls back to the mark.
                TracketMark()
            }
            .keylineTint(tracketBlue)
        }
    }
}

/// The Tracket logo, tinted so it tracks primaryBlue rather than whatever
/// colour the source PNG happens to be. Sized to the caption row it sits in.
private struct TracketMark: View {
    var body: some View {
        Image("TracketMark")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 13)
            .foregroundStyle(tracketBlue)
    }
}

/// Caption row: app mark + workout name on the left, total elapsed right.
private struct WorkoutHeader: View {
    let name: String
    let startedAt: Date

    var body: some View {
        HStack(spacing: 5) {
            TracketMark()
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .layoutPriority(1)
            ElapsedClock(startedAt: startedAt)
        }
    }
}

/// Total workout elapsed time, right-aligned, ticking natively.
private struct ElapsedClock: View {
    let startedAt: Date

    var body: some View {
        Text(timerInterval: countUp(from: startedAt), countsDown: false)
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// Two columns. Left: exercise, then set dots leading the target line. Right:
/// the rest clock, sized so its box matches the two rows beside it, sitting
/// directly under the elapsed clock so both times read as one column.
///
/// The rest clock carries no "REST" label: at 44pt against the header's 12pt
/// it is not the same kind of element as the elapsed time, and the label was
/// the only glyph in the card carrying no data.
private struct WorkoutCardBody: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(state.exercise)
                    .font(.headline)
                    .lineLimit(1)

                HStack(alignment: .center, spacing: 9) {
                    SetProgress(done: state.setsDone, count: state.setCount)
                    Text(state.target)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RestClock(since: state.lastSetAt)
        }
    }
}

/// The hero number: time since the last logged set.
///
/// Width is capped and the text scales down instead of pushing, because a
/// forgotten set turns "4:07" into "1:04:07" and Text(timerInterval:) reserves
/// room for the widest value its range can produce.
private struct RestClock: View {
    let since: Date

    var body: some View {
        Text(timerInterval: countUp(from: since), countsDown: false)
            .font(.system(size: 44, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 116, alignment: .trailing)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Exercise note, next exercise, and the Finish pill that deep-links into the
/// finish flow. Tapping the pill opens the app rather than ending the workout
/// where it stands: the summary screen is where a workout actually closes, and
/// a pocket tap should not be able to end a session with no way back.
private struct WorkoutCardFooter: View {
    let state: WorkoutActivityAttributes.ContentState
    let showFinish: Bool

    private var hasText: Bool {
        !state.note.isEmpty || !(state.nextExercise ?? "").isEmpty
    }

    var body: some View {
        if hasText || showFinish {
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    if !state.note.isEmpty {
                        Text(state.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let next = state.nextExercise, !next.isEmpty {
                        Text("Next: \(next)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showFinish {
                    Link(destination: finishURL) {
                        Text("Finish")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(tracketBlue, in: Capsule())
                    }
                    .fixedSize()
                }
            }
        }
    }
}

/// One dot per set, filled as sets are logged. The dots share a line with the
/// target, so past 5 they stop leaving room for it and fall back to a compact
/// "3/12" in the same orange.
private struct SetProgress: View {
    let done: Int
    let count: Int

    private static let maxDots = 5

    var body: some View {
        if count <= 0 {
            EmptyView()
        } else if count <= Self.maxDots {
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { index in
                    Circle()
                        .fill(index < done ? AnyShapeStyle(tracketOrange) : AnyShapeStyle(.quaternary))
                        .frame(width: 9, height: 9)
                }
            }
            .fixedSize()
        } else {
            Text("\(done)/\(count)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tracketOrange)
                .fixedSize()
        }
    }
}
