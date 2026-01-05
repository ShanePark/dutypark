package com.tistory.shanepark.dutypark.member.domain.dto

import java.util.UUID

data class UpdateProfilePhotoRequest(
    val sessionId: UUID,
    val attachmentId: UUID
)
