package com.tistory.shanepark.dutypark.attachment.domain.event

import java.nio.file.Path
import java.util.UUID

data class AttachmentUploadedEvent(
    val attachmentId: UUID,
    val filePath: Path
)
