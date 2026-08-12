import Foundation
import XCTest
@testable import Dutypark

final class APIErrorLocalizationTests: XCTestCase {
    func testAPIErrorConformsToLocalizedError() {
        let error = APIError.server(status: 400, code: "friend.request.self")

        XCTAssertFalse(error.localizedDescription.isEmpty)
        XCTAssertNotEqual(error.localizedDescription, "friend.request.self")
    }

    func testKnownServerCodeUsesLocalizedCatalogMessage() throws {
        let bundle = try localizedBundle("ko")

        XCTAssertEqual(
            APIErrorLocalization.message(code: "friend.request.self", bundle: bundle),
            "자기 자신에게는 친구 요청을 보낼 수 없습니다."
        )
    }

    func testDetailsAreInsertedIntoLocalizedMessage() throws {
        let bundle = try localizedBundle("en")

        XCTAssertEqual(
            APIErrorLocalization.message(
                code: "dutyBatch.yearMonthNotMatch",
                details: ["year": .integer(2026), "month": .integer(8)],
                bundle: bundle
            ),
            "The uploaded file month does not match the selected schedule month (2026-8)."
        )
    }

    func testValidationUsesSpecificFieldErrorWhenAvailable() throws {
        let bundle = try localizedBundle("ja")

        XCTAssertEqual(
            APIErrorLocalization.message(
                code: "common.validation.failed",
                fieldErrors: [APIFieldError(field: "username", code: "sso.username.length")],
                bundle: bundle
            ),
            "ユーザー名は1文字以上10文字以下で入力してください。"
        )
    }

    func testUnknownCodeUsesGenericFallback() throws {
        let bundle = try localizedBundle("es")

        XCTAssertEqual(
            APIErrorLocalization.message(code: "unknown.code", bundle: bundle),
            "Se ha producido un error. Inténtalo de nuevo."
        )
    }

    func testCatalogHasFiveLocaleParity() throws {
        let catalog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Resources/Errors.xcstrings")
        let data = try Data(contentsOf: catalog)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        XCTAssertFalse(strings.isEmpty)

        for (key, rawEntry) in strings {
            let entry = try XCTUnwrap(rawEntry as? [String: Any], key)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], key)
            XCTAssertEqual(
                Set(localizations.keys),
                Set(["en", "es", "ja", "ko", "zh-Hans"]),
                key
            )
        }
    }

    private func localizedBundle(_ locale: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: locale, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }
}
