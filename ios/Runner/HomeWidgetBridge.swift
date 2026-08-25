// HomeWidgetBridge.swift
//
// App-side half of the home screen widget. Owns the shared App Group defaults
// and the WidgetKit reload calls, and is driven entirely by the
// "tracket/home_widget" MethodChannel; the Dart half is
// lib/home_widget/home_screen_widget.dart.
//
// Methods:
//   writeSnapshot  - store the JSON the widget reads, then ask WidgetKit to redraw
//   takePendingTab - the tab a widget tap asked for, once
//
// The widget extension cannot reach the app's database, so this defaults blob is
// the entire contract between them. Both targets carry the App Group entitlement
// (ios/Runner/Runner.entitlements, ios/WorkoutWidgetExtension.entitlements).

import Flutter
import Foundation
import WidgetKit

final class HomeWidgetBridge: NSObject {
    static let channelName = "tracket/home_widget"

    /// Shared with the widget extension. Also declared on the widget side in
    /// ios/WorkoutWidget/TracketSnapshot.swift; keep the two in step.
    static let appGroupId = "group.com.tracket.workoutwidget"
    static let snapshotKey = "program_snapshot"

    /// Set when a widget deep-links back in, cleared the first time Dart asks
    /// for it. A flag rather than a push to Dart, because the URL can arrive
    /// during a cold launch, before the engine exists. Dart drains it on every
    /// resume, which covers that and a warm foreground alike.
    private var pendingTab: String?

    /// The tabs the widget is allowed to ask for. A URL is data from outside the
    /// app, so anything not on this list is dropped rather than forwarded.
    private static let knownTabs: Set<String> = ["workout", "schedule", "analytics"]

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    /// Handles a `tracket://open?tab=schedule` URL. Returns false for anything it
    /// does not own, so AppDelegate can pass it on.
    @discardableResult
    func handle(url: URL) -> Bool {
        guard url.scheme?.lowercased() == "tracket", url.host?.lowercased() == "open" else {
            return false
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let tab = components?.queryItems?.first(where: { $0.name == "tab" })?.value?.lowercased()

        if let tab, Self.knownTabs.contains(tab) {
            pendingTab = tab
        }

        // The URL is ours either way: an unrecognised tab should still open the
        // app, just without moving off whatever page it was on.
        return true
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "writeSnapshot":
            guard let args = call.arguments as? [String: Any],
                  let json = args["json"] as? String else {
                result(FlutterError(code: "bad_args", message: "writeSnapshot needs a json string", details: nil))
                return
            }
            write(snapshot: json)
            result(nil)

        case "takePendingTab":
            let tab = pendingTab
            pendingTab = nil
            result(tab)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func write(snapshot json: String) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId) else {
            NSLog("HomeWidgetBridge: App Group \(Self.appGroupId) is unavailable")
            return
        }

        // Skip the redraw when nothing actually changed. Most refreshes happen on
        // resume and background, where the program usually has not moved, and a
        // reload the user cannot see still spends their timeline budget.
        if defaults.string(forKey: Self.snapshotKey) == json { return }

        defaults.set(json, forKey: Self.snapshotKey)

        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
