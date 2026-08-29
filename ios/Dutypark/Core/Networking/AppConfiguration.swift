import Foundation

nonisolated enum AppConfiguration {
    private static let apiBaseURLKey = "DutyparkAPIBaseURL"

    static let apiBaseURL: URL = {
        if let value = Bundle.main.object(forInfoDictionaryKey: apiBaseURLKey) as? String,
           let url = validatedAPIBaseURL(value) {
            return url
        }

        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return URL(string: "https://dutypark.test/api/")!
        }
        #endif

        preconditionFailure("DutyparkAPIBaseURL must be a valid absolute URL ending in /api/")
    }()

    /// A capture run must never silently point at the production API. The simulator
    /// Debug configuration is expected to use localhost, while device and Release
    /// configurations continue to use their normal server configuration.
    static func isLocalCaptureEndpoint(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "http",
              let host = url.host?.lowercased(),
              ["localhost", "127.0.0.1", "::1"].contains(host)
        else { return false }

        let path = url.path.hasSuffix("/") ? url.path : url.path + "/"
        return path == "/api/"
    }

    static func enforceLocalCaptureIfRequested(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        guard arguments.contains("-capture-demo-local-only") else { return }
        precondition(
            isLocalCaptureEndpoint(apiBaseURL),
            "Demo screenshot capture requires a localhost API endpoint; refusing to use a remote server."
        )
    }

    static func validatedAPIBaseURL(_ value: String) -> URL? {
        let normalizedValue = value.hasSuffix("/") ? value : value + "/"
        guard let url = URL(string: normalizedValue),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme),
              url.host != nil,
              normalizedValue.hasSuffix("/api/")
        else {
            return nil
        }
        return url
    }

}
