package com.tistory.shanepark.dutypark.schedule.controller

import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleUpdateDto
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.service.ScheduleService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.http.ResponseEntity
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.*
import java.time.YearMonth
import java.util.*

@RestController
@RequestMapping("/api/schedules")
class ScheduleController(
    private val scheduleService: ScheduleService,
    private val scheduleRepository: ScheduleRepository,
    private val memberRepository: MemberRepository,
) {

    @GetMapping
    fun getSchedules(
        @Login loginMember: LoginMember,
        @RequestParam memberId: Long,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): Array<List<ScheduleDto>> {
        val member = memberRepository.findById(memberId).orElseThrow()
        return scheduleService.findSchedulesByYearAndMonth(loginMember = loginMember, member, YearMonth.of(year, month))
    }

    @PostMapping
    @SlackNotification
    fun createSchedule(
        @RequestBody @Validated scheduleUpdateDto: ScheduleUpdateDto,
        @Login loginMember: LoginMember
    ): ResponseEntity<Any> {
        scheduleService.createSchedule(loginMember, scheduleUpdateDto)

        return ResponseEntity.ok().build()
    }

    @PutMapping("/{id}")
    @SlackNotification
    fun updateSchedule(
        @RequestBody @Validated
        scheduleUpdateDto: ScheduleUpdateDto,
        @Login loginMember: LoginMember,
        @PathVariable id: UUID
    ): ResponseEntity<Any> {
        scheduleService.updateSchedule(loginMember, id, scheduleUpdateDto)
        return ResponseEntity.ok().build()
    }

    @PatchMapping("/{id1}/position")
    @SlackNotification
    fun swapSchedulePosition(
        @PathVariable id1: UUID,
        @RequestParam id2: UUID,
        @Login loginMember: LoginMember,
    ): ResponseEntity<Any> {
        val schedule1 = scheduleRepository.findById(id1).orElseThrow()
        val schedule2 = scheduleRepository.findById(id2).orElseThrow()

        scheduleService.swapSchedulePosition(loginMember, schedule1, schedule2)
        return ResponseEntity.ok().build()
    }

    @DeleteMapping("/{id}")
    fun deleteSchedule(
        @PathVariable id: UUID,
        @Login loginMember: LoginMember,
    ) {
        scheduleService.deleteSchedule(loginMember, id)
    }

    @PostMapping("/{scheduleId}/tags/{friendId}")
    fun tagFriend(
        @PathVariable scheduleId: UUID,
        @PathVariable friendId: Long,
        @Login loginMember: LoginMember
    ) {
        scheduleService.tagFriend(loginMember, scheduleId, friendId)
    }

    @DeleteMapping("/{scheduleId}/tags/{friendId}")
    fun untagFriend(
        @PathVariable scheduleId: UUID,
        @PathVariable friendId: Long,
        @Login loginMember: LoginMember
    ) {
        scheduleService.untagFriend(loginMember, scheduleId, friendId)
    }

    @DeleteMapping("/{scheduleId}/tags")
    fun untagSelf(
        @PathVariable scheduleId: UUID,
        @Login loginMember: LoginMember
    ) {
        scheduleService.untagSelf(loginMember, scheduleId)
    }

}
