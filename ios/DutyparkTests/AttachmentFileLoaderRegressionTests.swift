import Foundation
import Testing
@testable import Dutypark

@MainActor
@Suite
struct AttachmentFileLoaderRegressionTests {
    @Test
    func embeddedHEICBrandInAnUnrelatedFileDoesNotTriggerImageConversion() throws {
        let data = Data("report contains the text ftypheic but is not an image".utf8)

        let file = try AttachmentFileLoader.preparedFile(
            data: data,
            filename: "report.dutypark-unknown",
            type: nil
        )

        #expect(file.filename == "report.dutypark-unknown")
        #expect(file.contentType == "application/octet-stream")
        #expect(file.data == data)
    }
}
