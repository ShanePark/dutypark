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
