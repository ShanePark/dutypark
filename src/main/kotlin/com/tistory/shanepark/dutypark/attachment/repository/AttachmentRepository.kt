package com.tistory.shanepark.dutypark.attachment.repository

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.util.UUID

interface AttachmentRepository : JpaRepository<Attachment, UUID> {

    @Query(
        "SELECT DISTINCT a.contextId FROM Attachment a " +
                "WHERE a.contextType = :contextType AND a.contextId IN :contextIds"
    )
    fun findContextIdsWithAttachments(
        contextType: AttachmentContextType,
        contextIds: Collection<String>,
    ): List<String>

    fun findAllByContextTypeAndContextIdIn(
        contextType: AttachmentContextType,
        contextIds: Collection<String>
    ): List<Attachment>

    fun findAllByContextTypeAndContextIdOrderByOrderIndexAsc(
        contextType: AttachmentContextType,
        contextId: String
    ): List<Attachment>

    fun findAllByContextTypeAndContextId(
        contextType: AttachmentContextType,
        contextId: String
    ): List<Attachment>

    fun findAllByUploadSessionId(uploadSessionId: UUID): List<Attachment>

    fun existsByContextTypeAndContextId(
        contextType: AttachmentContextType,
        contextId: String
    ): Boolean

}
