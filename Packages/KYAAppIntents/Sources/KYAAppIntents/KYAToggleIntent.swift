#if canImport(AppIntents)
import AppIntents

/// Toggles KeepingYouAwake between active and inactive. Equivalent to
/// `keepingyouawake://toggle`.
@available(macOS 13.0, *)
public struct KYAToggleIntent: AppIntent {
    public static var title: LocalizedStringResource = "Toggle KeepingYouAwake"
    public static var description = IntentDescription(
        "Activates KeepingYouAwake if it is off, or deactivates it if it is currently on."
    )
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        try await KYAURLScheme.dispatch(.toggle)
        return .result()
    }
}
#endif
