package com.tistory.shanepark.dutypark.notification.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.notification.dto.ScheduleNotificationChangesDto
import com.tistory.shanepark.dutypark.notification.service.ScheduleNotificationChangesService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/notifications")
class ScheduleNotificationChangesController(private val changesService: ScheduleNotificationChangesService) {
    @GetMapping("/{id}/schedule-changes")
    fun getScheduleChanges(@Login viewer: LoginMember, @PathVariable id: UUID): ScheduleNotificationChangesDto =
        changesService.getChanges(viewer, id)
}
