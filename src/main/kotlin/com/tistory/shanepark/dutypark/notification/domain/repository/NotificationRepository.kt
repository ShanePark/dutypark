package com.tistory.shanepark.dutypark.notification.domain.repository

import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import java.time.LocalDateTime
import java.util.*

interface NotificationRepository : JpaRepository<Notification, UUID> {

    fun findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(memberId: Long): List<Notification>

    fun findByMemberIdOrderByCreatedDateDesc(memberId: Long, pageable: Pageable): Page<Notification>

    fun countByMemberIdAndIsReadFalse(memberId: Long): Long

    fun countByMemberId(memberId: Long): Long

    fun findByMemberIdAndId(memberId: Long, notificationId: UUID): Notification?

    @Modifying
    @Query("DELETE FROM Notification n WHERE n.createdDate < :date")
    fun deleteByCreatedDateBefore(date: LocalDateTime): Int

    @Modifying
    @Query("DELETE FROM Notification n WHERE n.member.id = :memberId AND n.isRead = true")
    fun deleteByMemberIdAndIsReadTrue(memberId: Long): Int
}
