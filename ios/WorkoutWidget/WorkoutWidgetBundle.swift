// WorkoutWidgetBundle.swift
//
// Entry point for the WorkoutWidgetExtension target. Currently ships the
// workout Live Activity only; the home-screen widget that used to live here
// is parked on branch `feat/homescreen-widget`.

import SwiftUI
import WidgetKit

@main
struct WorkoutWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}
