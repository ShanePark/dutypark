import Foundation
import Testing
@testable import Dutypark

@MainActor
@Suite
struct AttachmentFileLoaderRegressionTests {
    @Test
    func correctlyPositionedHEICBrandUsesMagicByteFallbackForUnknownType() {
        var data = Data([0x00, 0x00, 0x00, 0x18])
        data.append(Data("ftypheic".utf8))
        data.append(Data("not an image".utf8))

        #expect(throws: AttachmentUploadError.imageConversionFailed) {
            try AttachmentFileLoader.preparedFile(
                data: data,
                filename: "upload.dutypark-unknown",
                type: nil
            )
        }
    }

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
