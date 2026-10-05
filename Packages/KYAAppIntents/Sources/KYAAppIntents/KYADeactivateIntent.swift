#if canImport(AppIntents)
import AppIntents

/// Deactivates KeepingYouAwake, ending any in-progress activation
/// session. Equivalent to `keepingyouawake://deactivate`.
@available(macOS 13.0, *)
public struct KYADeactivateIntent: AppIntent {
    public static var title: LocalizedStringResource = "Deactivate KeepingYouAwake"
    public static var description = IntentDescription(
        "Lets your Mac go to sleep on its normal schedule again."
    )
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        try await KYAURLScheme.dispatch(.deactivate)
        return .result()
    }
}
#endif
