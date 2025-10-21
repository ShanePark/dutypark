package com.tistory.shanepark.dutypark.attachment.domain

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import jakarta.persistence.*
import java.time.Instant

@Entity
@Table(name = "attachment_upload_session")
class AttachmentUploadSession(
    @Enumerated(EnumType.STRING)
    @Column(name = "context_type", nullable = false, length = 50)
    val contextType: AttachmentContextType,

    @Column(name = "target_context_id", length = 255)
    val targetContextId: String? = null,

    @Column(name = "owner_id", nullable = false)
    val ownerId: Long,

    @Column(name = "expires_at", nullable = false)
    val expiresAt: Instant
) : EntityBase()
