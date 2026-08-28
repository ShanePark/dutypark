import Foundation

nonisolated struct TeamScheduleDraft: Equatable, Sendable {
    var id: UUID?
    var content: String
    var description: String
    var startDate: Date
    var endDate: Date

    var isValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && content.count <= 50
            && endDate >= startDate
    }
}

nonisolated struct TeamBatchResultDTO: Codable, Equatable, Sendable {
    let result: Bool
    let errorCode: String?
    let errorDetails: [String: JSONValue]?
    let startDate: DateOnly?
    let endDate: DateOnly?
    let dutyBatchResult: [TeamMemberBatchResultDTO]

    private enum CodingKeys: String, CodingKey {
        case result, errorCode, errorDetails, startDate, endDate, dutyBatchResult
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        result = try container.decode(Bool.self, forKey: .result)
        errorCode = try container.decodeIfPresent(String.self, forKey: .errorCode)
        errorDetails = try container.decodeIfPresent([String: JSONValue].self, forKey: .errorDetails)
        startDate = try container.decodeIfPresent(DateOnly.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(DateOnly.self, forKey: .endDate)
        dutyBatchResult = try container.decodeIfPresent(
            [TeamMemberBatchResultDTO].self,
            forKey: .dutyBatchResult
        ) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(result, forKey: .result)
        try container.encodeIfPresent(errorCode, forKey: .errorCode)
        try container.encodeIfPresent(errorDetails, forKey: .errorDetails)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(dutyBatchResult, forKey: .dutyBatchResult)
    }
}

nonisolated struct TeamMemberBatchResultDTO: Codable, Equatable, Sendable {
    let memberName: String
    let result: DutyBatchMemberResultDTO

    init(from decoder: Decoder) throws {
        if var container = try? decoder.unkeyedContainer() {
            memberName = try container.decode(String.self)
            result = try container.decode(DutyBatchMemberResultDTO.self)
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            memberName = try container.decode(String.self, forKey: .first)
            result = try container.decode(DutyBatchMemberResultDTO.self, forKey: .second)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(memberName)
        try container.encode(result)
    }

    private enum CodingKeys: String, CodingKey {
        case first, second
    }
}

nonisolated struct DutyBatchMemberResultDTO: Codable, Equatable, Sendable {
    let result: Bool
    let errorCode: String?
    let errorDetails: [String: JSONValue]?
    let startDate: DateOnly?
    let endDate: DateOnly?
    let workingDays: Int
    let offDays: Int
}

nonisolated enum TeamBatchUploadError: Error, Equatable, Sendable {
    case requestBodyTooLarge
}

nonisolated enum TeamFeatureLogic {
    /// Multipart uploads are currently assembled in memory by the API client, so keep the
    /// source file bounded to avoid an unbounded file-data plus request-body allocation.
    static let maximumDutyBatchRequestBodySize = 10 * 1024 * 1024
    private static let dutyBatchBoundaryLength = "Dutypark-".utf8.count + 36
    /// Conservative default for callers that do not have the final filename and form fields.
    static let maximumDutyBatchFileSize = maximumDutyBatchRequestBodySize - 2_048

    static func isMyShiftGroup(_ group: DutyByShiftDTO, memberID: MemberID?) -> Bool {
        guard let memberID else { return false }
        return group.members.contains { $0.id == memberID }
    }

    static func visibleDutyTypeNeighbor(
        in dutyTypes: [DutyTypeDTO],
        from index: Int,
        direction: Int
    ) -> Int? {
        guard dutyTypes.indices.contains(index), direction == -1 || direction == 1 else {
            return nil
        }
        var candidate = index + direction
        while dutyTypes.indices.contains(candidate) {
            let dutyType = dutyTypes[candidate]
            if dutyType.id != nil && !dutyType.hidden {
                return candidate
            }
            candidate += direction
        }
        return nil
    }

    static func isValidDutyBatchFileName(_ fileName: String) -> Bool {
        (fileName as NSString).pathExtension.lowercased() == "xlsx"
    }

    static func isValidDutyBatchFileSize(_ fileSize: Int) -> Bool {
        fileSize >= 0 && fileSize <= maximumDutyBatchFileSize
    }

    static func maximumDutyBatchFileSize(
        for fileName: String,
        year: Int,
        month: Int
    ) -> Int {
        let boundary = String(repeating: "B", count: dutyBatchBoundaryLength)
        let overhead = TeamMultipartForm(boundary: boundary).makeBody(
            fileName: fileName,
            fileData: Data(),
            year: year,
            month: month
        ).count
        return max(0, maximumDutyBatchRequestBodySize - overhead - 1)
    }

    static func isValidDutyBatchFileSize(
        _ fileSize: Int,
        fileName: String,
        year: Int,
        month: Int
    ) -> Bool {
        fileSize >= 0
            && fileSize <= maximumDutyBatchFileSize(for: fileName, year: year, month: month)
    }

    /// Returns a filename safe to interpolate into a quoted multipart header parameter.
    /// Control characters are removed before escaping the two quoted-string delimiters.
    static func sanitizedDutyBatchFileName(_ fileName: String) -> String {
        let filtered = fileName.unicodeScalars.reduce(into: String()) { result, scalar in
            guard !CharacterSet.controlCharacters.contains(scalar),
                  scalar.value != 0x2028,
                  scalar.value != 0x2029
            else { return }
            result.unicodeScalars.append(scalar)
        }
        let escaped = filtered
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return escaped.isEmpty ? "duty-batch.xlsx" : escaped
    }

    static func isValidDutyBatchYear(_ year: Int, currentYear: Int) -> Bool {
        year >= currentYear && year <= currentYear + 1
    }
}

nonisolated struct TeamMultipartForm: Sendable {
    let boundary: String

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    func makeBody(
        fileName: String,
        fileData: Data,
        year: Int,
        month: Int
    ) -> Data {
        let safeFileName = TeamFeatureLogic.sanitizedDutyBatchFileName(fileName)
        var data = Data()
        // The API client currently accepts an in-memory body. Reserve the payload capacity
        // up front to avoid repeated growth and transient buffers while appending the file.
        data.reserveCapacity(
            fileData.count
                + safeFileName.utf8.count
                + boundary.utf8.count * 3
                + 256
        )
        appendField(name: "year", value: String(year), to: &data)
        appendField(name: "month", value: String(month), to: &data)
        data.append("--\(boundary)\r\n".utf8Data)
        data.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(safeFileName)\"\r\n".utf8Data
        )
        data.append("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n".utf8Data)
        data.append(fileData)
        data.append("\r\n--\(boundary)--\r\n".utf8Data)
        return data
    }

    private func appendField(name: String, value: String, to data: inout Data) {
        data.append("--\(boundary)\r\n".utf8Data)
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8Data)
        data.append("\(value)\r\n".utf8Data)
    }
}

nonisolated private extension String {
    var utf8Data: Data { Data(utf8) }
}
