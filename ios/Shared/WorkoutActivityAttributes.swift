// WorkoutActivityAttributes.swift
//
// Shared between the Runner app (which starts/updates/ends the Live Activity
// via LiveActivityBridge) and WorkoutWidgetExtension (which renders it).
// Compiled into BOTH targets; see the Shared/ references in project.pbxproj.

import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Current exercise title, e.g. "Bench Press".
        var exercise: String
        /// 1-based position of the set the user is on, across the whole exercise.
        var setPosition: Int
        /// Total sets planned for the exercise.
        var setCount: Int
        /// Sets already logged for the exercise; fills the dots.
        var setsDone: Int
        /// Target line, e.g. "8-10 reps @ RPE 8". Built on the Dart side.
        var target: String
        /// The exercise's permanent note; empty string when there is none.
        var note: String
        /// Upcoming exercise title; only sent while the user is on the last set.
        var nextExercise: String?
        /// Workout start. Lives in the content state, not the attributes,
        /// because pausing shifts it forward to freeze the elapsed clock.
        var startedAt: Date
        /// When the last set was logged (workout start before the first log);
        /// anchor for the rest count-up.
        var lastSetAt: Date
    }

    /// Day title, e.g. "Push Day A". Fixed for the life of the workout.
    var workoutName: String
}
