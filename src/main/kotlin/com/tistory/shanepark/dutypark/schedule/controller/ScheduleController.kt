package com.tistory.shanepark.dutypark.schedule.controller

import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSearchResult
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleUpdateDto
import com.tistory.shanepark.dutypark.schedule.service.ScheduleSearchService
import com.tistory.shanepark.dutypark.schedule.service.ScheduleService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.data.domain.Pageable
import org.springframework.data.web.PageableDefault
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.*
import java.time.YearMonth
import java.util.*

@RestController
@RequestMapping("/api/schedules")
class ScheduleController(
    private val scheduleService: ScheduleService,
    private val scheduleSearchService: ScheduleSearchService,
) {

    @GetMapping
    fun getSchedules(
        @Login(required = false) loginMember: LoginMember?,
        @RequestParam memberId: Long,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): Array<List<ScheduleDto>> {
        return scheduleService.findSchedulesByYearAndMonth(
            loginMember = loginMember,
            memberId,
            YearMonth.of(year, month)
        )
    }

    @GetMapping("/{id}/search")
    fun searchSchedule(
        @Login(required = false) loginMember: LoginMember?,
        @PathVariable(value = "id") targetMemberId: Long,
        @PageableDefault(size = 10) pageable: Pageable,
        @RequestParam q: String
    ): PageResponse<ScheduleSearchResult> {
        return scheduleSearchService.search(loginMember, targetMemberId, pageable, q)
    }

    @PostMapping
    fun createSchedule(
        @RequestBody @Validated scheduleUpdateDto: ScheduleUpdateDto,
        @Login loginMember: LoginMember
    ) {
        scheduleService.createSchedule(loginMember, scheduleUpdateDto)
    }

    @PutMapping("/{id}")
    fun updateSchedule(
        @RequestBody @Validated
        scheduleUpdateDto: ScheduleUpdateDto,
        @Login loginMember: LoginMember,
        @PathVariable id: UUID
    ) {
        scheduleService.updateSchedule(loginMember, id, scheduleUpdateDto)
    }

    @PatchMapping("/{id1}/position")
    fun swapSchedulePosition(
        @PathVariable id1: UUID,
        @RequestParam id2: UUID,
        @Login loginMember: LoginMember,
    ) {
        scheduleService.swapSchedulePosition(loginMember, id1, id2)
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
