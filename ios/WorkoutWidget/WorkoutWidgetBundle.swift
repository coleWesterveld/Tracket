// WorkoutWidgetBundle.swift
//
// Entry point for the WorkoutWidgetExtension target.
//
//   ProgramWidget       home screen widget, program level, with a view picker
//   WorkoutLiveActivity Lock Screen and Dynamic Island card, during a workout
//
// The split is deliberate: the home screen widget never mentions the session in
// progress, and the Live Activity never mentions the week ahead.

import SwiftUI
import WidgetKit

@main
struct WorkoutWidgetBundle: WidgetBundle {
    var body: some Widget {
        ProgramWidget()
        WorkoutLiveActivity()
    }
}
