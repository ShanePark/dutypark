import Foundation
import Testing

private final class LocalizationCatalogBundleMarker: NSObject {}

struct LocalizationCatalogTests {
    private static let locales = ["en", "ko"]
    private static let expectedCatalogNames: Set<String> = [
        "Attachments.xcstrings",
        "Errors.xcstrings",
        "Localizable.xcstrings",
        "Notifications.xcstrings",
        "OAuth.xcstrings",
        "Settings.xcstrings",
        "Social.xcstrings",
        "Team.xcstrings"
    ]

    @Test
    func catalogsAreCompleteAndMatchCompiledResources() throws {
        let catalogs = try loadCatalogs()
        let tables = catalogs.map(\.table)
        #expect(Set(tables).count == tables.count, "Every catalog must compile to a unique table")
        #expect(catalogs.allSatisfy { !$0.strings.isEmpty }, "Every catalog must contain keys")

        var tableKeys = Set<String>()
        var translatableTableKeys = Set<String>()
        var excludedTableKeys = Set<String>()

        for catalog in catalogs {
            for (key, entry) in catalog.strings {
                let tableKey = "\(catalog.table).\(key)"
                #expect(tableKeys.insert(tableKey).inserted, "Duplicate localization key \(tableKey)")

                guard entry.shouldTranslate != false else {
                    excludedTableKeys.insert(tableKey)
                    continue
                }

                translatableTableKeys.insert(tableKey)
                for locale in Self.locales {
                    let stringUnit = try #require(
                        entry.localizations[locale]?.stringUnit,
                        "Missing \(locale) translation for \(tableKey)"
                    )
                    #expect(
                        stringUnit.state == "translated",
                        "Untranslated \(locale) value for \(tableKey)"
                    )
                    #expect(
                        !stringUnit.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        "Empty \(locale) value for \(tableKey)"
                    )
                    #expect(
                        stringUnit.value != key,
                        "Localization falls back to its key for \(tableKey) [\(locale)]"
                    )
                }

                let english = try #require(entry.localizations["en"]?.stringUnit.value)
                let korean = try #require(entry.localizations["ko"]?.stringUnit.value)
                #expect(
                    try printfSignature(in: english) == printfSignature(in: korean),
                    "Printf placeholders differ for \(tableKey)"
                )
            }
        }

        #expect(!tableKeys.isEmpty)
        #expect(translatableTableKeys.isDisjoint(with: excludedTableKeys))
        #expect(
            tableKeys == translatableTableKeys.union(excludedTableKeys),
            "Every shouldTranslate=false entry must be counted separately"
        )

        let resourceBundle = try appResourceBundle()
        for locale in Self.locales {
            let localizedBundle = try #require(
                resourceBundle.url(forResource: locale, withExtension: "lproj").flatMap(Bundle.init(url:)),
                "Missing compiled \(locale).lproj in \(resourceBundle.bundleURL.path)"
            )

            for catalog in catalogs {
                for (key, entry) in catalog.strings where entry.shouldTranslate != false {
                    let sourceValue = try #require(
                        entry.localizations[locale]?.stringUnit.value,
                        "Missing source \(locale) value for \(catalog.table).\(key)"
                    )
                    let compiledValue = localizedBundle.localizedString(
                        forKey: key,
                        value: key,
                        table: catalog.table
                    )
                    #expect(
                        compiledValue == sourceValue,
                        "Compiled \(locale) value differs for \(catalog.table).\(key)"
                    )
                }
            }
        }

        #expect(
            try printfSignature(in: "%2$lld / %1$@ / 100%% / %3$.2f") == [
                PrintfArgument(position: 1, type: "@"),
                PrintfArgument(position: 2, type: "lld"),
                PrintfArgument(position: 3, type: "f")
            ]
        )
        #expect(
            try printfSignature(in: "%@ %d %ld %lld %f") == [
                PrintfArgument(position: 1, type: "@"),
                PrintfArgument(position: 2, type: "d"),
                PrintfArgument(position: 3, type: "ld"),
                PrintfArgument(position: 4, type: "lld"),
                PrintfArgument(position: 5, type: "f")
            ]
        )
    }

    private func loadCatalogs() throws -> [Catalog] {
        let resourcesDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Resources", directoryHint: .isDirectory)
        let catalogURLs = try FileManager.default.contentsOfDirectory(
            at: resourcesDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "xcstrings" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        #expect(Set(catalogURLs.map(\.lastPathComponent)) == Self.expectedCatalogNames)

        return try catalogURLs.map { url in
            let root = try #require(
                JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
                "Invalid catalog root: \(url.lastPathComponent)"
            )
            let rawStrings = try #require(
                root["strings"] as? [String: Any],
                "Missing strings object: \(url.lastPathComponent)"
            )
            var strings: [String: CatalogEntry] = [:]

            for (key, rawEntry) in rawStrings {
                let entry = try #require(
                    rawEntry as? [String: Any],
                    "Invalid entry: \(url.lastPathComponent):\(key)"
                )
                let rawLocalizations = entry["localizations"] as? [String: Any] ?? [:]
                var localizations: [String: Localization] = [:]

                for (locale, rawLocalization) in rawLocalizations {
                    guard
                        let localization = rawLocalization as? [String: Any],
                        let rawStringUnit = localization["stringUnit"] as? [String: Any],
                        let state = rawStringUnit["state"] as? String,
                        let value = rawStringUnit["value"] as? String
                    else {
                        continue
                    }
                    localizations[locale] = Localization(
                        stringUnit: StringUnit(state: state, value: value)
                    )
                }

                strings[key] = CatalogEntry(
                    shouldTranslate: entry["shouldTranslate"] as? Bool,
                    localizations: localizations
                )
            }

            return Catalog(
                table: url.deletingPathExtension().lastPathComponent,
                strings: strings
            )
        }
    }

    private func appResourceBundle() throws -> Bundle {
        let testBundle = Bundle(for: LocalizationCatalogBundleMarker.self)
        if testBundle.url(forResource: "en", withExtension: "lproj") != nil {
            return testBundle
        }
        #expect(Bundle.main.url(forResource: "en", withExtension: "lproj") != nil)
        return Bundle.main
    }

    private func printfSignature(in format: String) throws -> [PrintfArgument] {
        let pattern = #"%(?:(\d+)\$)?[-+ #0']*(?:\d+)?(?:\.\d+)?(hh|h|ll|l|q|L|z|t|j)?([@diuoxXfFeEgGaAcCsSpn%])"#
        let expression = try NSRegularExpression(pattern: pattern)
        let range = NSRange(format.startIndex..<format.endIndex, in: format)
        var nextImplicitPosition = 1
        var arguments: [PrintfArgument] = []

        for match in expression.matches(in: format, range: range) {
            let conversion = try substring(for: match.range(at: 3), in: format)
            guard conversion != "%" else { continue }

            let positionRange = match.range(at: 1)
            let position: Int
            if positionRange.location != NSNotFound {
                position = try #require(Int(try substring(for: positionRange, in: format)))
            } else {
                position = nextImplicitPosition
                nextImplicitPosition += 1
            }

            let lengthRange = match.range(at: 2)
            let length = lengthRange.location == NSNotFound
                ? ""
                : try substring(for: lengthRange, in: format)
            arguments.append(PrintfArgument(position: position, type: length + conversion))
        }

        return arguments.sorted {
            ($0.position, $0.type) < ($1.position, $1.type)
        }
    }

    private func substring(for range: NSRange, in string: String) throws -> String {
        let swiftRange = try #require(Range(range, in: string))
        return String(string[swiftRange])
    }
}

private struct Catalog {
    let table: String
    let strings: [String: CatalogEntry]
}

private struct CatalogEntry {
    let shouldTranslate: Bool?
    let localizations: [String: Localization]
}

private struct Localization {
    let stringUnit: StringUnit
}

private struct StringUnit {
    let state: String
    let value: String
}

private struct PrintfArgument: Equatable {
    let position: Int
    let type: String
}
