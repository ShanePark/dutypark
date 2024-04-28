package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.data.domain.Page
import org.springframework.data.domain.PageImpl
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import java.time.LocalDateTime
import java.time.YearMonth

/**
 * When search engine is implemented, this service will be replaced with ScheduleSearchServiceESImpl
 */
@Service
class ScheduleSearchServiceDBImpl(
    private val scheduleRepository: ScheduleRepository,
    private val memberRepository: MemberRepository
) : ScheduleSearchService {

    override fun search(
        loginMember: LoginMember,
        targetMemberId: Long,
        page: Pageable,
        keyword: String
    ): Page<ScheduleDto> {
        // 1. get proper auth level for targetMemberId

        // 2. search schedules on database and sort by date desc

        // 3. return Page<ScheduleDto>

        val member = memberRepository.findById(loginMember.id).orElseThrow()
        val now = LocalDateTime.now()
        val s1 = scheduleRepository.save(Schedule(member, "test1", now, now, 0, Visibility.FRIENDS))
        val s2 = scheduleRepository.save(Schedule(member, "test2", now, now, 0, Visibility.FRIENDS))
        val s3 = scheduleRepository.save(Schedule(member, "test3", now, now, 0, Visibility.FRIENDS))

        val calendarView = CalendarView(YearMonth.now())
        val s1_ = ScheduleDto.of(calendarView, s1, false)[0]
        val s2_ = ScheduleDto.of(calendarView, s2, false)[0]
        val s3_ = ScheduleDto.of(calendarView, s3, false)[0]
        return PageImpl(listOf(s3_, s2_, s1_), page, 3)
    }

}
