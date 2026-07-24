// LiveActivityBridge.swift
//
// App-side half of the workout Live Activity. Owns the ActivityKit calls and
// is driven entirely by the "tracket/workout_live_activity" MethodChannel;
// the Dart half is lib/live_activity/workout_live_activity.dart.
//
// Methods:
//   start  - request the activity (or adopt one that survived a relaunch)
//   update - push a new content state to every live activity of this type
//   end    - end them all immediately
//
// All methods succeed silently on OS versions without ActivityKit or when the
// user has disabled Live Activities: the workout works fine without the card.

import ActivityKit
import Flutter
import Foundation

final class LiveActivityBridge: NSObject {
    static let channelName = "tracket/workout_live_activity"

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            result(nil)
            return
        }

        let args = call.arguments as? [String: Any]

        switch call.method {
        case "start":
            guard let state = Self.contentState(from: args),
                  let workoutName = args?["workoutName"] as? String else {
                result(FlutterError(code: "bad_args", message: "start needs a full payload", details: nil))
                return
            }
            Task { @MainActor in
                Self.start(workoutName: workoutName, state: state)
                result(nil)
            }

        case "update":
            guard let state = Self.contentState(from: args) else {
                result(FlutterError(code: "bad_args", message: "update needs a full payload", details: nil))
                return
            }
            Task { @MainActor in
                for activity in Activity<WorkoutActivityAttributes>.activities {
                    await activity.update(ActivityContent(state: state, staleDate: nil))
                }
                result(nil)
            }

        case "end":
            Task { @MainActor in
                await Self.endAll()
                result(nil)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 16.2, *)
    @MainActor
    private static func start(workoutName: String, state: WorkoutActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            // An activity can outlive the app process (relaunch mid-workout).
            // Adopt it if it belongs to the same workout; otherwise clear the
            // deck so we never stack cards.
            let existing = Activity<WorkoutActivityAttributes>.activities
            if let match = existing.first(where: { $0.attributes.workoutName == workoutName }) {
                await match.update(ActivityContent(state: state, staleDate: nil))
                for stray in existing where stray.id != match.id {
                    await stray.end(nil, dismissalPolicy: .immediate)
                }
                return
            }
            await endAll()
            do {
                _ = try Activity.request(
                    attributes: WorkoutActivityAttributes(workoutName: workoutName),
                    content: ActivityContent(state: state, staleDate: nil)
                )
            } catch {
                // Not fatal; the user just doesn't get the Lock Screen card.
            }
        }
    }

    @available(iOS 16.2, *)
    private static func endAll() async {
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Builds a content state from the channel payload. Timestamps arrive as
    /// milliseconds since epoch (Dart's DateTime.millisecondsSinceEpoch).
    @available(iOS 16.1, *)
    private static func contentState(from args: [String: Any]?) -> WorkoutActivityAttributes.ContentState? {
        guard let args,
              let exercise = args["exercise"] as? String,
              let setPosition = (args["setPosition"] as? NSNumber)?.intValue,
              let setCount = (args["setCount"] as? NSNumber)?.intValue,
              let setsDone = (args["setsDone"] as? NSNumber)?.intValue,
              let target = args["target"] as? String,
              let note = args["note"] as? String,
              let startedAtMs = (args["startedAt"] as? NSNumber)?.doubleValue,
              let lastSetAtMs = (args["lastSetAt"] as? NSNumber)?.doubleValue else {
            return nil
        }

        return WorkoutActivityAttributes.ContentState(
            exercise: exercise,
            setPosition: setPosition,
            setCount: setCount,
            setsDone: setsDone,
            target: target,
            note: note,
            nextExercise: args["nextExercise"] as? String,
            startedAt: Date(timeIntervalSince1970: startedAtMs / 1000),
            lastSetAt: Date(timeIntervalSince1970: lastSetAtMs / 1000)
        )
    }
}
