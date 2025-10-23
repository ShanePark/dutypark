package com.tistory.shanepark.dutypark.attachment.dto

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import java.util.UUID

data class ReorderAttachmentsRequest(
    val contextType: AttachmentContextType,
    val contextId: String,
    val orderedAttachmentIds: List<UUID>
)
