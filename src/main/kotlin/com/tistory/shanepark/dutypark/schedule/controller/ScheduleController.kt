package com.tistory.shanepark.dutypark.schedule.controller

import com.tistory.shanepark.dutypark.common.domain.dto.constraint.CreateDtoConstraint
import com.tistory.shanepark.dutypark.common.domain.dto.constraint.UpdateDtoConstraint
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleUpdateDto
import com.tistory.shanepark.dutypark.schedule.service.ScheduleService
import org.springframework.http.ResponseEntity
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.*
import java.time.YearMonth
import java.util.*

@RestController
@RequestMapping("/api/schedules")
class ScheduleController(
    private val scheduleService: ScheduleService,
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
    fun createSchedule(@RequestBody @Validated(CreateDtoConstraint::class) scheduleUpdateDto: ScheduleUpdateDto): ResponseEntity<Any> {
        scheduleService.createSchedule(scheduleUpdateDto)
        return ResponseEntity.ok().build()
    }

    @PutMapping
    fun updateSchedule(
        @RequestBody @Validated(UpdateDtoConstraint::class)
        scheduleUpdateDto: ScheduleUpdateDto
    ): ResponseEntity<Any> {
        scheduleUpdateDto.id?.let { id ->
            scheduleService.updateSchedule(id, scheduleUpdateDto)
            return ResponseEntity.ok().build()
        }
        return ResponseEntity.badRequest().build()
    }

    @DeleteMapping("/{id}")
    fun deleteSchedule(@PathVariable id: UUID) {
        scheduleService.deleteSchedule(id)
    }

}
