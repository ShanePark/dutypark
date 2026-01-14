package com.tistory.shanepark.dutypark.attachment.dto

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.*

data class AttachmentDto(
    val id: UUID,
    val contextType: AttachmentContextType,
    val contextId: String?,
    val originalFilename: String,
    val contentType: String,
    val size: Long,
    val hasThumbnail: Boolean,
    val thumbnailUrl: String?,
    val orderIndex: Int,
    val createdAt: ZonedDateTime,
    val createdBy: Long
) {
    companion object {
        fun from(attachment: Attachment): AttachmentDto {
            return AttachmentDto(
                id = attachment.id,
                contextType = attachment.contextType,
                contextId = attachment.contextId,
                originalFilename = attachment.originalFilename,
                contentType = attachment.contentType,
                size = attachment.size,
                hasThumbnail = attachment.thumbnailFilename != null,
                thumbnailUrl = attachment.thumbnailFilename?.let { "/api/attachments/${attachment.id}/thumbnail" },
                orderIndex = attachment.orderIndex,
                createdAt = attachment.createdDate.atZone(ZoneId.systemDefault()),
                createdBy = attachment.createdBy
            )
        }
    }
}
