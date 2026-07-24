// WorkoutWidgetBundle.swift
//
// Entry point for the WorkoutWidgetExtension target. The home-screen widget
// that used to live here is parked on branch `feat/homescreen-widget`.
// PlaceholderWidget keeps the target compiling until the workout Live
// Activity (ActivityKit) is added to this bundle in its place.

import WidgetKit
import SwiftUI

@main
struct WorkoutWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlaceholderWidget()
    }
}

// Inert stand-in so the bundle has at least one widget. Renders nothing and
// never refreshes. Delete when the Live Activity configuration lands.
struct PlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PlaceholderWidget", provider: PlaceholderProvider()) { _ in
            EmptyView()
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Tracket")
        .description("Coming soon.")
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: Date())], policy: .never))
    }
}
