import Foundation
import Testing
@testable import Dutypark

struct DutyAbbreviationTests {
    @Test
    func automaticLabelsUseACompleteCharacterAndCustomLabelsAreTrimmed() {
        #expect(DutyAbbreviation.resolve("야간근무") == "야")
        #expect(DutyAbbreviation.resolve("야간근무", override: "  ") == "야")
        #expect(DutyAbbreviation.resolve("야간근무", override: " N ") == "N")
        #expect(DutyAbbreviation.resolve("🌙야간") == "🌙")
        #expect(DutyAbbreviation.resolve("👩‍⚕️근무") == "👩‍⚕️")
        #expect(DutyAbbreviation.resolve("e\u{301}vening") == "e\u{301}")
        #expect(DutyAbbreviation.resolve("") == "")
        #expect(DutyAbbreviation.normalize("  ") == nil)
        #expect(DutyAbbreviation.isValid("1234567890"))
        #expect(!DutyAbbreviation.isValid("12345678901"))
        #expect(!DutyAbbreviation.isValid(String(repeating: "🌙", count: 6)))
    }

    @Test
    func typePayloadsDecodeBothLegacyAndNewContractsWithoutReplacingFullNames() throws {
        let decoder = JSONDecoder()
        let legacy = ##"{"id":7,"teamId":1,"name":"야간근무","position":0,"color":"#112233","hidden":false}"##
        let custom = ##"{"id":7,"teamId":1,"name":"야간근무","position":0,"color":"#112233","hidden":false,"abbreviation":"N","shortName":"N"}"##
        let oldType = try decoder.decode(DutyTypeDTO.self, from: Data(legacy.utf8))
        var type = try decoder.decode(DutyTypeDTO.self, from: Data(custom.utf8))
        #expect(oldType.abbreviation == nil)
        #expect(oldType.displayName(isMyCalendar: true) == "야")
        #expect(type.abbreviation == "N")
        #expect(type.displayName(isMyCalendar: true) == "N")
        #expect(type.displayName(isMyCalendar: false) == "야간근무")
        type.abbreviation = nil
        #expect(type.shortName == "야")
        let restored = try decoder.decode(DutyTypeDTO.self, from: JSONEncoder().encode(type))
        #expect(restored == type)
    }

    @Test
    func dailyAndCachedPayloadsKeepFullNamesForFriendsAndCompactLabelsForTheOwner() throws {
        let legacy = ##"{"year":2026,"month":9,"day":8,"dutyType":"야간근무","dutyColor":"#112233","isOff":false,"dutyTypeId":7,"source":"PATTERN"}"##
        let custom = ##"{"year":2026,"month":9,"day":8,"dutyType":"야간근무","dutyColor":"#112233","isOff":false,"dutyTypeId":7,"source":"PATTERN","dutyAbbreviation":"N"}"##
        let oldDuty = try JSONDecoder().decode(DutyDTO.self, from: Data(legacy.utf8))
        let duty = try JSONDecoder().decode(DutyDTO.self, from: Data(custom.utf8))
        #expect(oldDuty.shortName == "야")
        #expect(duty.displayName(isMyCalendar: true) == "N")
        #expect(duty.displayName(isMyCalendar: false) == "야간근무")
        let cached = try JSONDecoder().decode(DutyDTO.self, from: JSONEncoder().encode(duty))
        #expect(cached.dutyAbbreviation == "N")
        #expect(cached.dutyType == "야간근무")
    }

    @Test
    func requestsDistinguishAnOmittedOverrideFromAnExplicitReset() throws {
        let omitted = DutyTypeUpdateDTO(id: 7, name: "야간근무", color: "#112233")
        let reset = DutyTypeUpdateDTO(id: 7, name: "야간근무", color: "#112233", abbreviation: "")
        let custom = DutyTypeCreateDTO(teamId: 1, name: "야간근무", color: "#112233", abbreviation: "N")
        let encoder = JSONEncoder()
        let omittedJSON = try #require(JSONSerialization.jsonObject(with: encoder.encode(omitted)) as? [String: Any])
        let resetJSON = try #require(JSONSerialization.jsonObject(with: encoder.encode(reset)) as? [String: Any])
        let customJSON = try #require(JSONSerialization.jsonObject(with: encoder.encode(custom)) as? [String: Any])
        #expect(omittedJSON["abbreviation"] == nil)
        #expect(resetJSON["abbreviation"] as? String == "")
        #expect(customJSON["abbreviation"] as? String == "N")
        #expect(customJSON["name"] as? String == "야간근무")
    }
}
