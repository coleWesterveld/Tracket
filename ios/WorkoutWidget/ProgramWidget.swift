// ProgramWidget.swift
//
// The configurable Tracket home screen widget: one widget with a view picker,
// rather than three widgets crowding the gallery. Long press, Edit Widget, pick.
//
// Nothing here is about the workout in progress. That is the Live Activity's job
// (WorkoutLiveActivity.swift), and a home screen widget that only says something
// during a session is blank almost all of the time.

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Configuration

enum ProgramWidgetMode: String, AppEnum {
    case nextUp
    case thisWeek
    case goals

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "View" }

    static var caseDisplayRepresentations: [ProgramWidgetMode: DisplayRepresentation] {
        [
            .nextUp: DisplayRepresentation(
                title: "Next up",
                subtitle: "The next workout and what is in it"
            ),
            .thisWeek: DisplayRepresentation(
                title: "This week",
                subtitle: "Where you are in the rotation"
            ),
            .goals: DisplayRepresentation(
                title: "Goals",
                subtitle: "Progress towards your targets"
            ),
        ]
    }

    /// Where a tap lands. The tab slugs are read by
    /// ios/Runner/HomeWidgetBridge.swift and turned into a NavigationBar index by
    /// lib/home_widget/home_screen_widget.dart.
    var deepLink: URL? {
        switch self {
        case .nextUp: return URL(string: "tracket://open?tab=workout")
        case .thisWeek: return URL(string: "tracket://open?tab=schedule")
        case .goals: return URL(string: "tracket://open?tab=analytics")
        }
    }
}

struct ProgramWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Tracket" }

    static var description: IntentDescription {
        IntentDescription("Choose what this widget shows.")
    }

    @Parameter(title: "View", default: .nextUp)
    var mode: ProgramWidgetMode
}

// MARK: - Timeline

struct ProgramEntry: TimelineEntry {
    let date: Date
    let mode: ProgramWidgetMode
    /// nil when the app has never written a snapshot this widget can read.
    let snapshot: TracketSnapshot?
}

struct ProgramTimelineProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> ProgramEntry {
        let now = Date()
        return ProgramEntry(date: now, mode: .nextUp, snapshot: .sample(on: now))
    }

    /// The gallery preview. Real data for anyone who has used the app, sample data
    /// for anyone who has not, so the widget never shows up in the picker empty.
    func snapshot(for configuration: ProgramWidgetIntent, in context: Context) async -> ProgramEntry {
        let now = Date()
        return ProgramEntry(
            date: now,
            mode: configuration.mode,
            snapshot: TracketSnapshot.load() ?? .sample(on: now)
        )
    }

    /// One entry per local midnight for the week ahead.
    ///
    /// Nothing on this widget ticks faster than a day: the rotation advances at
    /// midnight and the sets that fill a circle in arrive while the app is open,
    /// which triggers its own reload from HomeWidgetBridge. A week of entries
    /// means a phone that never opens Tracket still shows the right day.
    func timeline(for configuration: ProgramWidgetIntent, in context: Context) async -> Timeline<ProgramEntry> {
        let snapshot = TracketSnapshot.load()
        let calendar = Calendar.current
        let now = Date()

        var entries = [ProgramEntry(date: now, mode: configuration.mode, snapshot: snapshot)]

        let midnight = calendar.startOfDay(for: now)
        for offset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: midnight) else { continue }
            entries.append(ProgramEntry(date: day, mode: configuration.mode, snapshot: snapshot))
        }

        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - Widget

struct ProgramWidget: Widget {
    private let kind = "TracketProgramWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ProgramWidgetIntent.self,
            provider: ProgramTimelineProvider()
        ) { entry in
            ProgramWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color("WidgetBackground")
                }
        }
        .configurationDisplayName("Tracket")
        .description("Your next workout, your week, or your goals.")
        .supportedFamilies([.systemSmall, .systemMedium])
        // The default content margins are generous enough that seven day circles
        // stop being legible on a small widget. ProgramWidgetViews pads itself.
        .contentMarginsDisabled()
    }
}
