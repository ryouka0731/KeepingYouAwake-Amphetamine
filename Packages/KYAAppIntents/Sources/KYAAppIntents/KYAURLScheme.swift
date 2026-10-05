import AppKit
import Foundation

/// Builds and dispatches `keepingyouawake://...` URLs that the running app
/// already understands via `KYAEventHandler`. Using the URL scheme keeps the
/// intents free of any direct dependency on the app's internals: the same
/// path is exercised by AppleScript, the URL scheme handler tests, and
/// (now) Shortcuts.app.
@available(macOS 13.0, *)
enum KYAURLScheme {
    private static let scheme = "keepingyouawake"

    enum Action: String {
        case activate
        case deactivate
        case toggle
    }

    enum DispatchError: Error {
        case invalidURL
        case workspaceOpenFailed(URL)
    }

    static func dispatch(_ action: Action, query: [URLQueryItem] = []) async throws {
        // KYAEventHandler keys actions off `URL.lastPathComponent`, so the
        // action name has to live in the path (`keepingyouawake:///activate`)
        // rather than the host (`keepingyouawake://activate`). The leading
        // empty authority is required for the URL to parse cleanly.
        var components = URLComponents()
        components.scheme = scheme
        components.host = ""
        components.path = "/" + action.rawValue
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else {
            throw DispatchError.invalidURL
        }
        // Intents run inside the app, so deliver the URL to this very app.
        // A plain `NSWorkspace.open(url)` lets Launch Services pick the
        // `keepingyouawake://` handler, which upstream KeepingYouAwake
        // registers too (same bundle identifier, so `-b` can't tell them
        // apart either).
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        do {
            _ = try await NSWorkspace.shared.open([url],
                                                  withApplicationAt: Bundle.main.bundleURL,
                                                  configuration: configuration)
        } catch {
            throw DispatchError.workspaceOpenFailed(url)
        }
    }
}
