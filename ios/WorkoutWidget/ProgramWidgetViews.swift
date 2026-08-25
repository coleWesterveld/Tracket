// ProgramWidgetViews.swift
//
// The three views the Tracket home screen widget can show, at both supported
// sizes. Layouts are drawn against the app's own surfaces: the small widget gets
// one fact and one line of context, the medium gets a list.
//
// Content margins are switched off on the widget configuration so the padding
// here is the real padding. The week strip needs the width.

import SwiftUI
import WidgetKit

/// Close to the card padding the app uses, and trimmed by a point from it so the
/// small widget's seven day circles get every bit of width they can: they are
/// width-constrained, not height-constrained.
private let widgetPadding: CGFloat = 12

// MARK: - Entry point

struct ProgramWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ProgramEntry

    private var isMedium: Bool { family == .systemMedium }

    var body: some View {
        content
            .padding(widgetPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .widgetURL(entry.mode.deepLink)
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = entry.snapshot {
            switch entry.mode {
            case .nextUp:
                NextUpView(snapshot: snapshot, now: entry.date, isMedium: isMedium)
            case .thisWeek:
                ThisWeekView(snapshot: snapshot, now: entry.date, isMedium: isMedium)
            case .goals:
                GoalsView(snapshot: snapshot, isMedium: isMedium)
            }
        } else {
            WidgetMessage(
                title: "Open Tracket",
                detail: "Your program shows up here once the app has run once."
            )
        }
    }
}

// MARK: - Next up

private struct NextUpView: View {
    let snapshot: TracketSnapshot
    let now: Date
    let isMedium: Bool

    var body: some View {
        if let next = snapshot.nextWorkout(from: now), let day = next.day {
            if isMedium {
                medium(next.date, day)
            } else {
                small(next.date, day)
            }
        } else {
            WidgetMessage(
                title: "Nothing scheduled",
                detail: "Add a day to your program and it lands here."
            )
        }
    }

    private func small(_ date: Date, _ day: ProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                DayDot(color: day.color)
                WidgetCaption("Day \(day.number)")
                Spacer(minLength: 4)
                TracketWidgetMark()
            }

            Spacer(minLength: 4)

            Text(day.title)
                .font(.system(size: 26, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text(whenLine(date, day))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 1)

            Spacer(minLength: 4)

            Text(volumeLine(day))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func medium(_ date: Date, _ day: ProgramDay) -> some View {
        HStack(alignment: .top, spacing: widgetPadding) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    DayDot(color: day.color)
                    WidgetCaption("Day \(day.number)")
                }

                Spacer(minLength: 4)

                Text(day.title)
                    .font(.system(size: 26, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text(relativeDayName(date, from: now))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 1)

                if let time = day.formattedTime(on: date) {
                    Text(time)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text("\(day.setCount) sets planned")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)

            Divider()

            ExerciseList(day: day)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Tomorrow, 6:30 PM", or just the day when it has no set time.
    private func whenLine(_ date: Date, _ day: ProgramDay) -> String {
        let name = relativeDayName(date, from: now)
        guard let time = day.formattedTime(on: date) else { return name }
        return "\(name), \(time)"
    }

    private func volumeLine(_ day: ProgramDay) -> String {
        let exercises = day.exerciseCount == 1 ? "1 exercise" : "\(day.exerciseCount) exercises"
        return "\(exercises) • \(day.setCount) sets"
    }
}

/// The exercises of one day, with the rep target the app itself would show.
private struct ExerciseList: View {
    /// Five rows is what fits at a legible size. The real total comes from
    /// `exerciseCount`, so the overflow line counts exercises the snapshot does
    /// not even carry.
    private static let visibleRows = 5

    let day: ProgramDay

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(day.exercises.prefix(Self.visibleRows).enumerated()), id: \.offset) { index, exercise in
                if index > 0 {
                    Divider().opacity(0.5)
                }
                HStack(spacing: 6) {
                    Text(exercise.title)
                        .font(.system(size: 11.5))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(exercise.detail)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 2.5)
            }

            if day.exerciseCount > Self.visibleRows {
                Text("+\(day.exerciseCount - Self.visibleRows) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - This week

private struct ThisWeekView: View {
    let snapshot: TracketSnapshot
    let now: Date
    let isMedium: Bool

    private var thisWeek: [ScheduledDay] { snapshot.week(containing: now) }

    var body: some View {
        if thisWeek.isEmpty {
            WidgetMessage(
                title: "Nothing scheduled",
                detail: "Add a day to your program and it lands here."
            )
        } else if isMedium {
            medium
        } else {
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                WidgetCaption("This week")
                Spacer(minLength: 4)
                if let done = doneLine {
                    Text(done)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 6)

            WeekdayHeader(dates: thisWeek.map(\.date), compact: true)
            WeekRow(days: thisWeek, now: now, compact: true)

            Spacer(minLength: 6)

            // Two lines, because a day called "Upper Body Strength" does not fit
            // on one at this width and the small widget has the height to spare.
            Text(nextLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                WidgetCaption(snapshot.programTitle)
                Spacer(minLength: 4)
                if let done = doneLine {
                    Text(done)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 6)

            WeekdayHeader(dates: thisWeek.map(\.date), compact: false)
            WeekRow(days: thisWeek, now: now, compact: false)
            WeekRow(days: snapshot.week(containing: now, offsetBy: 1), now: now, compact: false)
                .padding(.top, 5)

            Spacer(minLength: 6)

            Text(nextLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "1 of 3", counting only the sessions this week's rotation actually asked
    /// for. Nil on a week the program schedules nothing, where a 0 of 0 would be
    /// noise.
    private var doneLine: String? {
        let planned = thisWeek.filter { $0.day != nil }
        guard !planned.isEmpty else { return nil }
        let done = planned.filter(\.isLogged).count
        return "\(done) of \(planned.count)"
    }

    private var nextLine: String {
        guard let next = snapshot.nextWorkout(from: now), let day = next.day else {
            return "No workouts scheduled"
        }
        return "Next: \(day.title), \(relativeDayName(next.date, from: now, midSentence: true))"
    }
}

private struct WeekdayHeader: View {
    let dates: [Date]
    let compact: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(dates, id: \.self) { date in
                Text(weekdayInitial(date))
                    .font(.system(size: compact ? 9 : 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, compact ? 3 : 4)
    }
}

private struct WeekRow: View {
    let days: [ScheduledDay]
    let now: Date
    let compact: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { scheduled in
                let offset = daysBetween(now, scheduled.date)
                DayCircle(
                    scheduled: scheduled,
                    isToday: offset == 0,
                    isPast: offset < 0,
                    size: compact ? 20 : 26
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// One day of the week strip.
///
/// Filled means the session is logged, an outline means it is still planned, a
/// faded outline means it was planned and has gone by, and the ring is today.
/// Filled against outlined is doing real work: on an iOS 18 tinted home screen
/// every day colour collapses to the same hue, and the fill is all that is left
/// to read.
private struct DayCircle: View {
    /// How far a planned day recedes once it has gone by unlogged, so a missed
    /// Monday cannot be mistaken for an upcoming one.
    private static let missedOpacity: Double = 0.3

    let scheduled: ScheduledDay
    let isToday: Bool
    let isPast: Bool
    let size: CGFloat

    /// A logged day with nothing scheduled is a free workout. It gets the neutral
    /// fill rather than borrowing a colour from a day it was not.
    private var statusColor: Color { scheduled.day?.color ?? .secondary }

    private var isMissed: Bool { isPast && !scheduled.isLogged && scheduled.day != nil }

    private var numberColor: Color {
        if scheduled.isLogged { return .white }
        if isToday { return .primary }
        if scheduled.day != nil { return isMissed ? .secondary : .primary }
        return .secondary
    }

    var body: some View {
        ZStack {
            Group {
                if scheduled.isLogged {
                    Circle().fill(statusColor)
                } else if scheduled.day != nil {
                    Circle().strokeBorder(
                        statusColor.opacity(isMissed ? Self.missedOpacity : 1),
                        lineWidth: 1.5
                    )
                }
            }
            // Inset when today, so the status ring and today's ring cannot land
            // on the same edge and read as one thick smudge.
            .padding(isToday ? 2 : 0)

            if isToday {
                Circle().strokeBorder(Color.primary, lineWidth: 1.5)
            }

            Text("\(Calendar.current.component(.day, from: scheduled.date))")
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(numberColor)
                .minimumScaleFactor(0.8)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Goals

private struct GoalsView: View {
    /// Three bars is what fits before they stop being readable at a glance.
    private static let visibleRows = 3

    let snapshot: TracketSnapshot
    let isMedium: Bool

    var body: some View {
        if snapshot.goals.isEmpty {
            WidgetMessage(
                title: "No goals yet",
                detail: "Set a target in Analytics and its progress shows up here."
            )
        } else if isMedium {
            medium
        } else {
            small(snapshot.goals[0])
        }
    }

    /// The goal closest to done, which is the one worth being reminded of.
    private func small(_ goal: GoalProgress) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                WidgetCaption("Goal")
                Spacer(minLength: 4)
                Text(percentText(goal))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            Text(goal.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text("\(Int(goal.current.rounded())) of \(formatWeight(goal.target, unit: snapshot.weightUnit))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 2)

            GoalBar(fraction: goal.fraction)
                .padding(.top, 7)

            Spacer(minLength: 6)

            Text(remainingText(goal))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                WidgetCaption("Goals")
                Spacer(minLength: 4)
                Text("Estimated 1RM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(snapshot.goals.prefix(Self.visibleRows))) { goal in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(goal.title)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(Int(goal.current.rounded())) / \(formatWeight(goal.target, unit: snapshot.weightUnit))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        GoalBar(fraction: goal.fraction)
                    }
                }
            }

            Spacer(minLength: 6)

            if snapshot.goals.count > Self.visibleRows {
                Text("+\(snapshot.goals.count - Self.visibleRows) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percentText(_ goal: GoalProgress) -> String {
        "\(Int((goal.fraction * 100).rounded()))%"
    }

    private func remainingText(_ goal: GoalProgress) -> String {
        goal.fraction >= 1
            ? "Target reached"
            : "\(formatWeight(goal.remaining, unit: snapshot.weightUnit)) to go"
    }
}

private struct GoalBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(tracketWidgetAccent)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Shared pieces

/// Uppercase label at the top of every view.
private struct WidgetCaption: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.5)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

private struct DayDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

/// The Tracket logo, tinted so it tracks the app's blue rather than whatever
/// colour the source PNG happens to be.
private struct TracketWidgetMark: View {
    var body: some View {
        Image("TracketMark")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 11)
            .foregroundStyle(tracketWidgetAccent)
    }
}

/// Every state where there is nothing to draw: no snapshot yet, no scheduled
/// days, no goals. Always says what to do about it.
private struct WidgetMessage: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Spacer(minLength: 0)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
