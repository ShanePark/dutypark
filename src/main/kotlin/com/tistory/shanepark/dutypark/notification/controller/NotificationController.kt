package com.tistory.shanepark.dutypark.notification.controller

import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.notification.dto.NotificationCountDto
import com.tistory.shanepark.dutypark.notification.dto.NotificationDto
import com.tistory.shanepark.dutypark.notification.service.NotificationService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.data.domain.Pageable
import org.springframework.data.domain.Sort
import org.springframework.data.web.PageableDefault
import org.springframework.data.web.SortDefault
import org.springframework.web.bind.annotation.*
import java.util.*

@RestController
@RequestMapping("/api/notifications")
class NotificationController(
    private val notificationService: NotificationService
) {

    @GetMapping
    fun getNotifications(
        @Login loginMember: LoginMember,
        @PageableDefault(page = 0, size = 20)
        @SortDefault(sort = ["createdDate"], direction = Sort.Direction.DESC)
        pageable: Pageable
    ): PageResponse<NotificationDto> {
        return PageResponse(notificationService.getNotifications(loginMember.id, pageable))
    }

    @GetMapping("/unread")
    fun getUnreadNotifications(
        @Login loginMember: LoginMember
    ): List<NotificationDto> {
        return notificationService.getUnreadNotifications(loginMember.id)
    }

    @GetMapping("/count")
    fun getNotificationCount(
        @Login loginMember: LoginMember
    ): NotificationCountDto {
        return notificationService.getUnreadCount(loginMember.id)
    }

    @PatchMapping("/{id}/read")
    fun markAsRead(
        @Login loginMember: LoginMember,
        @PathVariable id: UUID
    ): NotificationDto {
        return notificationService.markAsRead(loginMember.id, id)
    }

    @PatchMapping("/read-all")
    fun markAllAsRead(
        @Login loginMember: LoginMember
    ): Map<String, Int> {
        val count = notificationService.markAllAsRead(loginMember.id)
        return mapOf("count" to count)
    }

    @DeleteMapping("/{id}")
    fun deleteNotification(
        @Login loginMember: LoginMember,
        @PathVariable id: UUID
    ) {
        notificationService.deleteNotification(loginMember.id, id)
    }

    @DeleteMapping("/read")
    fun deleteAllRead(
        @Login loginMember: LoginMember
    ): Map<String, Int> {
        val count = notificationService.deleteAllRead(loginMember.id)
        return mapOf("count" to count)
    }
}
