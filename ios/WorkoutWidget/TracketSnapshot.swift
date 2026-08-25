// TracketSnapshot.swift
//
// Everything the home screen widget knows. The widget extension cannot run Dart
// or open the app's SQLite database, so this JSON blob in the shared App Group
// is the whole contract; the app writes it through
// ios/Runner/HomeWidgetBridge.swift, built by lib/home_widget/widget_snapshot.dart.
//
// The split rotation is worked out HERE rather than being baked into the blob,
// using the same mapping as lib/other_utilities/events.dart. That is what lets
// the widget roll over to the next day at midnight, with the right workout, when
// the app has not been opened for a week.

import Foundation
import SwiftUI
import UIKit

// MARK: - Shared App Group

/// Also declared on the app side in ios/Runner/HomeWidgetBridge.swift; keep the
/// two in step.
private let appGroupId = "group.com.tracket.workoutwidget"
private let snapshotKey = "program_snapshot"

/// Matches `widgetSnapshotSchema` in lib/home_widget/widget_snapshot.dart. A blob
/// from a newer app than this widget is ignored rather than half-read, since an
/// old widget binary can outlive an app update.
private let supportedSchema = 1

// MARK: - Payload

struct TracketSnapshot: Decodable {
    let schema: Int
    let programTitle: String
    /// yyyy-MM-dd. The day the rotation counts from.
    let origin: String
    let splitLength: Int
    /// "lb" or "kg". Weights arrive already converted.
    let weightUnit: String
    let days: [ProgramDay]
    /// yyyy-MM-dd for every day with at least one logged set, most recent 8 weeks.
    let loggedDays: [String]
    /// Closest to done first.
    let goals: [GoalProgress]
}

struct ProgramDay: Decodable {
    /// Position in the split as the app counts it, 1-based: the "Day 3" on the
    /// schedule page. Not the same as `order` when the split has rest gaps.
    let number: Int
    /// Position in the rotation cycle, 0-based. What the schedule maths uses.
    let order: Int
    let title: String
    let colorArgb: Int64
    /// "H:mm", 24 hour, or nil when the day has no set time.
    let time: String?
    let exerciseCount: Int
    let setCount: Int
    let exercises: [PlannedExercise]
}

struct PlannedExercise: Decodable, Identifiable {
    let title: String
    /// Preformatted by the app so the widget can never disagree with the program
    /// page: "4 x 4-6", or a plain set count when the exercise has several
    /// different rep targets.
    let detail: String

    var id: String { title + detail }
}

struct GoalProgress: Decodable, Identifiable {
    let title: String
    /// RPE-adjusted estimated 1RM, in `weightUnit`.
    let current: Double
    let target: Double

    var id: String { title }

    /// Uncapped, so beating a goal can read as beating it.
    var fraction: Double { target > 0 ? current / target : 0 }
    var remaining: Double { max(0, target - current) }
}

// MARK: - Loading

extension TracketSnapshot {
    /// The last snapshot the app wrote, or nil when it has never written one or
    /// wrote one this widget cannot read.
    static func load() -> TracketSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let json = defaults.string(forKey: snapshotKey),
              let data = json.data(using: .utf8),
              let snapshot = try? JSONDecoder().decode(TracketSnapshot.self, from: data),
              snapshot.schema == supportedSchema
        else { return nil }
        return snapshot
    }
}

// MARK: - Dates

/// yyyy-MM-dd against the device's own calendar. Built fresh each time rather
/// than cached, so a widget process that outlives a timezone change cannot keep
/// parsing days into the old one.
private var dayFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.calendar = Calendar.current
    formatter.timeZone = Calendar.current.timeZone
    return formatter
}

/// Whole calendar days from `from` to `to`, matching
/// lib/other_utilities/days_between.dart.
func daysBetween(_ from: Date, _ to: Date) -> Int {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: from)
    let end = calendar.startOfDay(for: to)
    return calendar.dateComponents([.day], from: start, to: end).day ?? 0
}

// MARK: - Schedule

/// One calendar day of the schedule as the widget draws it.
struct ScheduledDay: Identifiable {
    let date: Date
    /// nil on a rest day.
    let day: ProgramDay?
    let isLogged: Bool

    var id: Date { date }

    /// A logged day with nothing scheduled: a free workout, or a session done
    /// off-plan. Worth showing, but not in a day colour it never had.
    var isUnplanned: Bool { isLogged && day == nil }
}

extension TracketSnapshot {
    var originDate: Date? { dayFormatter.date(from: origin) }

    private var loggedDaySet: Set<String> { Set(loggedDays) }

    /// The scheduled day for a date, or nil for a rest day.
    ///
    /// This is the mapping in lib/other_utilities/events.dart:
    /// `daysBetween(origin, day) % splitLength == dayOrder`. Dart's `%` on ints
    /// is never negative, so the modulo below is floored the same way to keep
    /// dates before the origin agreeing with the app.
    func day(on date: Date) -> ProgramDay? {
        guard splitLength > 0, let origin = originDate else { return nil }
        let offset = daysBetween(origin, date)
        let position = ((offset % splitLength) + splitLength) % splitLength
        return days.first { $0.order == position }
    }

    func scheduled(on date: Date) -> ScheduledDay {
        let key = dayFormatter.string(from: date)
        return ScheduledDay(
            date: date,
            day: day(on: date),
            isLogged: loggedDaySet.contains(key)
        )
    }

    /// The week `date` falls in, honouring the device's first weekday.
    func week(containing date: Date, offsetBy weeks: Int = 0) -> [ScheduledDay] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date),
              let start = calendar.date(byAdding: .weekOfYear, value: weeks, to: interval.start)
        else { return [] }

        // Cached once per week rather than per day: the set is rebuilt on every
        // `loggedDaySet` access, and seven of those is seven allocations.
        let logged = loggedDaySet
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return ScheduledDay(
                date: day,
                day: self.day(on: day),
                isLogged: logged.contains(dayFormatter.string(from: day))
            )
        }
    }

    /// The next session to do, starting with today.
    ///
    /// Today counts unless it is already logged, so the widget keeps pointing at
    /// tonight's workout all day and only rolls forward once the sets are in.
    /// Nil when the program has no scheduled days at all.
    func nextWorkout(from date: Date) -> ScheduledDay? {
        guard splitLength > 0, !days.isEmpty else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let logged = loggedDaySet

        // One full cycle is enough: if no day in it is scheduled, none ever is.
        for offset in 0...max(1, splitLength) {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: today),
                  let day = day(on: candidate)
            else { continue }

            let key = dayFormatter.string(from: candidate)
            if offset == 0 && logged.contains(key) { continue }
            return ScheduledDay(date: candidate, day: day, isLogged: logged.contains(key))
        }
        return nil
    }
}

// MARK: - Formatting

extension ProgramDay {
    /// The colour the user picked for this day in the app. Alpha is dropped: the
    /// day colours are opaque, and a translucent circle on a widget reads as a
    /// bug rather than a choice.
    var color: Color {
        let packed = UInt32(truncatingIfNeeded: colorArgb)
        return Color(
            red: Double((packed >> 16) & 0xFF) / 255,
            green: Double((packed >> 8) & 0xFF) / 255,
            blue: Double(packed & 0xFF) / 255
        )
    }

    /// The day's workout time in the reader's locale, "6:30 PM" or "18:30".
    func formattedTime(on reference: Date) -> String? {
        guard let time else { return nil }
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              let stamped = Calendar.current.date(
                  bySettingHour: hour, minute: minute, second: 0, of: reference
              )
        else { return nil }

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: stamped)
    }
}

/// "Today", "Tomorrow", "Friday", then "7 Sep" once a weekday name stops being
/// enough to tell one from another.
///
/// [midSentence] lowercases "Today" and "Tomorrow" for use after a comma. It
/// deliberately leaves the weekday and the date alone: a weekday is a proper noun
/// in English and lowercasing one reads as a typo.
func relativeDayName(_ target: Date, from today: Date, midSentence: Bool = false) -> String {
    switch daysBetween(today, target) {
    case 0:
        return midSentence ? "today" : "Today"
    case 1:
        return midSentence ? "tomorrow" : "Tomorrow"
    case 2...6:
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: target)
    default:
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: target)
    }
}

/// One-letter weekday initials for the week strip header.
func weekdayInitial(_ date: Date) -> String {
    let symbols = DateFormatter().veryShortWeekdaySymbols ?? []
    let index = Calendar.current.component(.weekday, from: date) - 1
    guard symbols.indices.contains(index) else { return "" }
    return symbols[index]
}

/// Gym-floor precision: nobody needs a decimal place on a widget.
func formatWeight(_ value: Double, unit: String) -> String {
    "\(Int(value.rounded())) \(unit)"
}

// MARK: - Colours

/// The app's primary blue, adapted for a light home screen against a dark one.
/// primaryBlue reads well on white but goes muddy on the dark card colour, so the
/// dark side is the same hue lifted.
let tracketWidgetAccent = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
        ? UIColor(red: 0x4A / 255, green: 0x9B / 255, blue: 0xF5 / 255, alpha: 1)
        : UIColor(red: 0x1A / 255, green: 0x78 / 255, blue: 0xEB / 255, alpha: 1)
})

// MARK: - Gallery sample

extension TracketSnapshot {
    /// What the widget shows in the gallery before the app has ever written a
    /// snapshot. Real exercise names from the seeded Push Pull Legs program, with
    /// the rotation anchored on the current week so the strip looks plausible.
    static func sample(on reference: Date) -> TracketSnapshot {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: reference)?.start
            ?? calendar.startOfDay(for: reference)
        // Monday of the displayed week, so Push lands on a Monday.
        let monday = calendar.date(byAdding: .day, value: 1, to: weekStart) ?? weekStart

        return TracketSnapshot(
            schema: supportedSchema,
            programTitle: "Push Pull Legs",
            origin: dayFormatter.string(from: monday),
            splitLength: 7,
            weightUnit: "lb",
            days: [
                ProgramDay(
                    number: 1, order: 0, title: "Push",
                    colorArgb: 0xFF3F51B5, time: "18:30",
                    exerciseCount: 5, setCount: 16,
                    exercises: [
                        PlannedExercise(title: "Barbell Bench Press", detail: "4 x 4-6"),
                        PlannedExercise(title: "Incline Dumbbell Press", detail: "3 x 8-10"),
                        PlannedExercise(title: "Dumbbell Shoulder Press", detail: "3 x 8-10"),
                        PlannedExercise(title: "Triceps Pushdown", detail: "3 x 10-12"),
                        PlannedExercise(title: "Cable Chest Fly", detail: "3 x 12-15"),
                    ]
                ),
                ProgramDay(
                    number: 2, order: 2, title: "Pull",
                    colorArgb: 0xFFF44336, time: "18:30",
                    exerciseCount: 5, setCount: 16,
                    exercises: [
                        PlannedExercise(title: "Barbell Bent Over Row", detail: "4 x 4-6"),
                        PlannedExercise(title: "Pullups", detail: "3 x 6-10"),
                        PlannedExercise(title: "Seated Cable Row", detail: "3 x 8-10"),
                        PlannedExercise(title: "Face Pull", detail: "3 x 12-15"),
                        PlannedExercise(title: "Barbell Biceps Curl", detail: "3 x 8-10"),
                    ]
                ),
                ProgramDay(
                    number: 3, order: 4, title: "Legs",
                    colorArgb: 0xFF4CAF50, time: "18:30",
                    exerciseCount: 5, setCount: 17,
                    exercises: [
                        PlannedExercise(title: "Barbell Squat", detail: "4 x 4-6"),
                        PlannedExercise(title: "Romanian Deadlift", detail: "3 x 8-10"),
                        PlannedExercise(title: "Leg Press", detail: "3 x 8-10"),
                        PlannedExercise(title: "Seated Leg Curl", detail: "3 x 10-12"),
                        PlannedExercise(title: "Standing Calf Raise", detail: "4 x 12-15"),
                    ]
                ),
            ],
            loggedDays: [dayFormatter.string(from: monday)],
            goals: [
                GoalProgress(title: "Barbell Bench Press", current: 191, target: 225),
                GoalProgress(title: "Barbell Squat", current: 222, target: 315),
                GoalProgress(title: "Barbell Bent Over Row", current: 150, target: 185),
            ]
        )
    }
}
