// WorkoutWidget.swift
//
// iOS Home Screen widget that shows the active Tracket workout state.
// Data is written by Flutter via home_widget into the shared App Group
// UserDefaults container (group.com.tracket.workoutwidget).
//
// Sizes supported:
//   .systemSmall  — current exercise + rest/elapsed timer
//   .systemMedium — current exercise, set info, timer, next exercise

import WidgetKit
import SwiftUI

// MARK: - App Group

private let appGroupId = "group.com.tracket.workoutwidget"

// MARK: - Data model

struct WorkoutEntry: TimelineEntry {
    let date: Date
    let isActive: Bool
    let currentExercise: String
    let setInfo: String
    let nextExercise: String
    let elapsedSeconds: Int
    let restSeconds: Int
    let isResting: Bool
}

// MARK: - Provider

struct WorkoutProvider: TimelineProvider {

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    func placeholder(in context: Context) -> WorkoutEntry {
        WorkoutEntry(
            date: Date(),
            isActive: true,
            currentExercise: "Bench Press",
            setInfo: "Set 2 of 4 — 8–10 reps @ RPE 8",
            nextExercise: "Overhead Press",
            elapsedSeconds: 1245,
            restSeconds: 47,
            isResting: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutEntry>) -> Void) {
        // Refresh every 30 seconds while a workout is active so timers stay
        // reasonably accurate without draining the battery.
        let e = entry()
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 30, to: Date())!
        let timeline = Timeline(entries: [e], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func entry() -> WorkoutEntry {
        let d = defaults
        return WorkoutEntry(
            date: Date(),
            isActive: d?.bool(forKey: "is_active") ?? false,
            currentExercise: d?.string(forKey: "current_exercise") ?? "",
            setInfo: d?.string(forKey: "set_info") ?? "",
            nextExercise: d?.string(forKey: "next_exercise") ?? "",
            elapsedSeconds: d?.integer(forKey: "elapsed_seconds") ?? 0,
            restSeconds: d?.integer(forKey: "rest_seconds") ?? -1,
            isResting: d?.bool(forKey: "is_resting") ?? false
        )
    }
}

// MARK: - Helpers

private func formatSeconds(_ total: Int) -> String {
    guard total >= 0 else { return "--:--" }
    let m = total / 60
    let s = total % 60
    return String(format: "%d:%02d", m, s)
}

// MARK: - Small widget view

struct SmallWorkoutView: View {
    let entry: WorkoutEntry

    var body: some View {
        if entry.isActive {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("TRACKET")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                Text(entry.currentExercise.isEmpty ? "No workout" : entry.currentExercise)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer()

                if entry.isResting && entry.restSeconds >= 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rest")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatSeconds(entry.restSeconds))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Elapsed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatSeconds(entry.elapsedSeconds))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(UIColor.systemBackground))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("No active\nworkout")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))
        }
    }
}

// MARK: - Medium widget view

struct MediumWorkoutView: View {
    let entry: WorkoutEntry

    var body: some View {
        if entry.isActive {
            HStack(spacing: 0) {
                // Left column: exercise info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("TRACKET")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }

                    Text(entry.currentExercise.isEmpty ? "Workout" : entry.currentExercise)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    if !entry.setInfo.isEmpty {
                        Text(entry.setInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if !entry.nextExercise.isEmpty {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Next")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(entry.nextExercise)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .padding(.vertical, 4)

                // Right column: timers
                VStack(spacing: 10) {
                    VStack(spacing: 2) {
                        Text("ELAPSED")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatSeconds(entry.elapsedSeconds))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }

                    if entry.isResting && entry.restSeconds >= 0 {
                        VStack(spacing: 2) {
                            Text("REST")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatSeconds(entry.restSeconds))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .frame(width: 90)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))
        } else {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tracket")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("No active workout")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))
        }
    }
}

// MARK: - Widget entry view dispatcher

struct WorkoutWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: WorkoutEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWorkoutView(entry: entry)
        case .systemMedium:
            MediumWorkoutView(entry: entry)
        default:
            SmallWorkoutView(entry: entry)
        }
    }
}

// MARK: - Widget definition

struct WorkoutWidget: Widget {
    let kind: String = "WorkoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkoutProvider()) { entry in
            WorkoutWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Workout in Progress")
        .description("See your current exercise, rest timer, and what's coming up next.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview("Small — Active", as: .systemSmall) {
    WorkoutWidget()
} timeline: {
    WorkoutEntry(
        date: .now,
        isActive: true,
        currentExercise: "Barbell Bench Press",
        setInfo: "Set 2 of 4 — 8–10 reps @ RPE 8",
        nextExercise: "Overhead Press",
        elapsedSeconds: 1245,
        restSeconds: 47,
        isResting: true
    )
    WorkoutEntry(
        date: .now,
        isActive: false,
        currentExercise: "",
        setInfo: "",
        nextExercise: "",
        elapsedSeconds: 0,
        restSeconds: -1,
        isResting: false
    )
}

#Preview("Medium — Active", as: .systemMedium) {
    WorkoutWidget()
} timeline: {
    WorkoutEntry(
        date: .now,
        isActive: true,
        currentExercise: "Barbell Bench Press",
        setInfo: "Set 2 of 4 — 8–10 reps @ RPE 8",
        nextExercise: "Overhead Press",
        elapsedSeconds: 1245,
        restSeconds: 47,
        isResting: true
    )
}
