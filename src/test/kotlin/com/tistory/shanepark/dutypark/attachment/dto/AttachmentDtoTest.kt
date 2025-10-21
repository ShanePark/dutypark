package com.tistory.shanepark.dutypark.attachment.dto

import com.tistory.shanepark.dutypark.attachment.domain.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.AttachmentContextType
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.util.UUID

class AttachmentDtoTest {

    @Test
    fun `should map Attachment to AttachmentDto correctly`() {
        val attachment = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = "schedule-123",
            originalFilename = "test-image.png",
            storedFilename = "${UUID.randomUUID()}.png",
            contentType = "image/png",
            size = 12345L,
            storagePath = "storage/SCHEDULE/schedule-123/",
            orderIndex = 0,
            createdBy = 1L
        )

        val dto = AttachmentDto.from(attachment)

        assertThat(dto.id).isEqualTo(attachment.id)
        assertThat(dto.contextType).isEqualTo(AttachmentContextType.SCHEDULE)
        assertThat(dto.contextId).isEqualTo("schedule-123")
        assertThat(dto.originalFilename).isEqualTo("test-image.png")
        assertThat(dto.contentType).isEqualTo("image/png")
        assertThat(dto.size).isEqualTo(12345L)
        assertThat(dto.hasThumbnail).isFalse
        assertThat(dto.thumbnailUrl).isNull()
        assertThat(dto.orderIndex).isEqualTo(0)
        assertThat(dto.createdBy).isEqualTo(1L)
    }

    @Test
    fun `should map Attachment with thumbnail to AttachmentDto correctly`() {
        val attachment = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = "schedule-123",
            originalFilename = "test-image.png",
            storedFilename = "${UUID.randomUUID()}.png",
            contentType = "image/png",
            size = 12345L,
            storagePath = "storage/SCHEDULE/schedule-123/",
            orderIndex = 0,
            createdBy = 1L
        )
        attachment.thumbnailFilename = "thumb-${UUID.randomUUID()}.png"
        attachment.thumbnailContentType = "image/png"
        attachment.thumbnailSize = 5000L

        val dto = AttachmentDto.from(attachment)

        assertThat(dto.hasThumbnail).isTrue
        assertThat(dto.thumbnailUrl).isEqualTo("/api/attachments/${attachment.id}/thumbnail")
    }

    @Test
    fun `should handle null contextId`() {
        val attachment = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = null,
            originalFilename = "test.pdf",
            storedFilename = "${UUID.randomUUID()}.pdf",
            contentType = "application/pdf",
            size = 54321L,
            storagePath = "storage/_tmp/session-123/",
            orderIndex = 0,
            createdBy = 2L
        )

        val dto = AttachmentDto.from(attachment)

        assertThat(dto.contextId).isNull()
    }
}
