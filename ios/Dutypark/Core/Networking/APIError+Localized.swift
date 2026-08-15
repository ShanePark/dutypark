import Foundation

nonisolated enum APIErrorLocalization {
    static func message(
        code: String?,
        details: [String: JSONValue]? = nil,
        fieldErrors: [APIFieldError] = [],
        bundle: Bundle? = nil
    ) -> String {
        let bundle = bundle ?? AppLocalization.bundle()
        let candidates: [String]
        if code == "common.validation.failed" {
            candidates = fieldErrors.map(\.code) + [code].compactMap { $0 }
        } else {
            candidates = [code].compactMap { $0 } + fieldErrors.map(\.code)
        }

        for candidate in candidates {
            let translated = bundle.localizedString(
                forKey: candidate,
                value: candidate,
                table: "Errors"
            )
            if translated != candidate {
                return interpolate(translated, details: details)
            }
        }

        return bundle.localizedString(
            forKey: "errors.generic",
            value: "Something went wrong. Please try again.",
            table: "Errors"
        )
    }

    private static func interpolate(
        _ message: String,
        details: [String: JSONValue]?
    ) -> String {
        details?.reduce(into: message) { result, entry in
            guard let value = entry.value.messageValue else { return }
            result = result.replacingOccurrences(of: "{\(entry.key)}", with: value)
        } ?? message
    }
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .server(_, let code):
            APIErrorLocalization.message(code: code)
        case .serverWithDetails(_, let code, _):
            APIErrorLocalization.message(code: code)
        case .transport:
            APIErrorLocalization.message(code: "errors.transport")
        case .invalidURL, .invalidResponse, .decoding:
            APIErrorLocalization.message(code: nil)
        }
    }
}

private extension JSONValue {
    nonisolated var messageValue: String? {
        switch self {
        case .string(let value): value
        case .integer(let value): String(value)
        case .number(let value): String(value)
        case .boolean(let value): String(value)
        case .object, .array, .null: nil
        }
    }
}
