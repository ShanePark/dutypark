package com.tistory.shanepark.dutypark.attachment.dto

import java.util.UUID

data class FinalizeSessionRequest(
    val contextId: String,
    val orderedAttachmentIds: List<UUID>
)
