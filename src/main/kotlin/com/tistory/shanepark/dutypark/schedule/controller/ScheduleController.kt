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
        @RequestParam memberId: Long,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): Array<List<ScheduleDto>> {
        val member = memberRepository.findById(memberId).orElseThrow()
        return scheduleService.findSchedulesByYearAndMonth(member, YearMonth.of(year, month))
    }

    @PostMapping
    @SlackNotification
    fun createSchedule(
        @RequestBody @Validated scheduleUpdateDto: ScheduleUpdateDto,
        @Login loginMember: LoginMember
    ): ResponseEntity<Any> {
        scheduleService.checkAuthentication(loginMember, scheduleUpdateDto.memberId)
        scheduleService.createSchedule(scheduleUpdateDto)

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
        scheduleService.checkAuthentication(loginMember, scheduleUpdateDto.memberId)
        scheduleService.updateSchedule(id, scheduleUpdateDto)
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
        scheduleService.checkAuthentication(loginMember, schedule1.member.id!!)
        scheduleService.checkAuthentication(loginMember, schedule2.member.id!!)

        scheduleService.swapSchedulePosition(schedule1, schedule2)
        return ResponseEntity.ok().build()
    }

    @DeleteMapping("/{id}")
    fun deleteSchedule(@PathVariable id: UUID) {
        scheduleService.deleteSchedule(id)
    }

}
