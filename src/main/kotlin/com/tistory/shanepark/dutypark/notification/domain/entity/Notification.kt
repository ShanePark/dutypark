package com.tistory.shanepark.dutypark.notification.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import jakarta.persistence.*

@Entity
@Table(
    name = "notifications",
    indexes = [
        Index(name = "idx_notifications_member_unread", columnList = "member_id, is_read, created_date DESC"),
        Index(name = "idx_notifications_member_created", columnList = "member_id, created_date DESC")
    ]
)
class Notification(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @Enumerated(EnumType.STRING)
    @Column(name = "type", nullable = false, length = 50)
    val type: NotificationType,

    @Column(name = "title", nullable = false, length = 255)
    val title: String,

    @Column(name = "content", columnDefinition = "TEXT")
    val content: String? = null,

    @Enumerated(EnumType.STRING)
    @Column(name = "reference_type", length = 50)
    val referenceType: NotificationReferenceType? = null,

    @Column(name = "reference_id", length = 50)
    val referenceId: String? = null,

    @Column(name = "actor_id")
    val actorId: Long? = null,

    @Column(name = "is_read", nullable = false)
    var isRead: Boolean = false
) : EntityBase()
