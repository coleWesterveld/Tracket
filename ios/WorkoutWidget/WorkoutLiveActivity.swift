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

/// Open-ended range for a count-up timer. iOS ends Live Activities at 8 hours
/// anyway, so the bound is never visible.
private func countUp(from start: Date) -> ClosedRange<Date> {
    start...start.addingTimeInterval(8 * 60 * 60)
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock Screen / banner presentation.
            VStack(alignment: .leading, spacing: 8) {
                WorkoutHeader(name: context.attributes.workoutName, startedAt: context.state.startedAt)
                WorkoutCardBody(state: context.state)
            }
            .padding(16)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "dumbbell.fill")
                            .font(.caption2)
                            .foregroundStyle(tracketBlue)
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
                    WorkoutCardBody(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(tracketBlue)
            } compactTrailing: {
                Text(timerInterval: countUp(from: context.state.lastSetAt), countsDown: false)
                    .font(.caption2)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 44)
            } minimal: {
                // The minimal slot is too small for a ticking clock to stay
                // legible, so it falls back to the glyph.
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(tracketBlue)
            }
            .keylineTint(tracketBlue)
        }
    }
}

/// Caption row: app glyph + workout name on the left, total elapsed right.
private struct WorkoutHeader: View {
    let name: String
    let startedAt: Date

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "dumbbell.fill")
                .font(.caption2)
                .foregroundStyle(tracketBlue)
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

/// Everything below the header: exercise, set progress, rest clock, note,
/// next exercise. Shared by the Lock Screen card and the expanded island.
private struct WorkoutCardBody: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(state.exercise)
                    .font(.headline)
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                SetDots(done: state.setsDone, count: state.setCount)
            }

            Text("Set \(state.setPosition) of \(state.setCount): \(state.target)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Rest")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tracketBlue)
                Text(timerInterval: countUp(from: state.lastSetAt), countsDown: false)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.leading)
            }
            .padding(.top, 2)

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
    }
}

/// One dot per set, filled as sets are logged. Past 6 sets, dots stop being
/// readable at a glance, so it falls back to plain "3/12" text.
private struct SetDots: View {
    let done: Int
    let count: Int

    private static let maxDots = 6

    var body: some View {
        if count <= 0 {
            EmptyView()
        } else if count <= Self.maxDots {
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { index in
                    Circle()
                        .fill(index < done ? AnyShapeStyle(tracketBlue) : AnyShapeStyle(.quaternary))
                        .frame(width: 7, height: 7)
                }
            }
        } else {
            Text("\(done)/\(count)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
