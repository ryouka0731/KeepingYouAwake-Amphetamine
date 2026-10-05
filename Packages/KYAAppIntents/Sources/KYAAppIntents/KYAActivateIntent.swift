import Foundation
#if canImport(AppIntents)
import AppIntents

/// Activates KeepingYouAwake. With no `minutes` parameter the timer is
/// activated indefinitely (the app's default for the URL scheme without
/// any time arguments).
@available(macOS 13.0, *)
public struct KYAActivateIntent: AppIntent {
    public static var title: LocalizedStringResource = "Activate KeepingYouAwake"
    public static var description = IntentDescription(
        "Prevents your Mac from sleeping. Pass a number of minutes to limit the activation, or omit it to keep the Mac awake indefinitely."
    )
    public static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Minutes",
        description: "Optional. How long to keep the Mac awake, in minutes. Leave empty for an indefinite session.",
        default: nil,
        inclusiveRange: (1, 1440)
    )
    public var minutes: Int?

    public init() {}

    public init(minutes: Int?) {
        self.minutes = minutes
    }

    public func perform() async throws -> some IntentResult {
        var query: [URLQueryItem] = []
        if let minutes, minutes > 0 {
            query.append(URLQueryItem(name: "minutes", value: String(minutes)))
        } else {
            // Explicitly request indefinite. Without a duration parameter
            // KYAEventHandler falls through to the app's
            // `defaultTimeInterval` (the user's preferred default
            // duration), which contradicts this intent's description
            // promising an indefinite session. `seconds=0` is
            // `KYASleepWakeTimeIntervalIndefinite` in the URL handler.
            query.append(URLQueryItem(name: "seconds", value: "0"))
        }
        try await KYAURLScheme.dispatch(.activate, query: query)
        return .result()
    }
}
#endif
