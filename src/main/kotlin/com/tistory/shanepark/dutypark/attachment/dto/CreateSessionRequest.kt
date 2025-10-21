package com.tistory.shanepark.dutypark.attachment.dto

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType

data class CreateSessionRequest(
    val contextType: AttachmentContextType,
    val targetContextId: String? = null
)
