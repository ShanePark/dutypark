package com.tistory.shanepark.dutypark.attachment.domain.entity

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.domain.enums.ThumbnailStatus
import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import jakarta.persistence.*
import org.hibernate.annotations.JdbcTypeCode
import org.hibernate.type.SqlTypes
import java.util.UUID

@Entity
@Table(
    name = "attachment",
    indexes = [
        Index(name = "idx_attachment_context", columnList = "context_type, context_id"),
        Index(name = "idx_attachment_session", columnList = "upload_session_id")
    ]
)
class Attachment(
    @Enumerated(EnumType.STRING)
    @Column(name = "context_type", nullable = false, length = 50)
    val contextType: AttachmentContextType,

    @Column(name = "context_id", length = 255)
    var contextId: String? = null,

    @Column(name = "upload_session_id", columnDefinition = "char(36)")
    @JdbcTypeCode(SqlTypes.VARCHAR)
    var uploadSessionId: UUID? = null,

    @Column(name = "original_filename", nullable = false, length = 255)
    val originalFilename: String,

    @Column(name = "stored_filename", nullable = false, length = 255)
    val storedFilename: String,

    @Column(name = "content_type", nullable = false, length = 100)
    val contentType: String,

    @Column(name = "size", nullable = false)
    val size: Long,

    @Column(name = "storage_path", nullable = false, length = 500)
    var storagePath: String,

    @Column(name = "thumbnail_filename", length = 255)
    var thumbnailFilename: String? = null,

    @Column(name = "thumbnail_content_type", length = 100)
    var thumbnailContentType: String? = null,

    @Column(name = "thumbnail_size")
    var thumbnailSize: Long? = null,

    @Enumerated(EnumType.STRING)
    @Column(name = "thumbnail_status", nullable = false, length = 20)
    var thumbnailStatus: ThumbnailStatus = ThumbnailStatus.NONE,

    @Column(name = "order_index", nullable = false)
    var orderIndex: Int = 0,

    @Column(name = "created_by", nullable = false)
    val createdBy: Long
) : EntityBase()
