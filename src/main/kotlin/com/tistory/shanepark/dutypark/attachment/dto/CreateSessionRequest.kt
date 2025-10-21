package com.tistory.shanepark.dutypark.attachment.dto

import com.tistory.shanepark.dutypark.attachment.domain.AttachmentContextType

data class CreateSessionRequest(
    val contextType: AttachmentContextType,
    val targetContextId: String? = null
)
