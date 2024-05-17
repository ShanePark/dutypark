package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSearchResult
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable

interface ScheduleSearchService {

    fun search(loginMember: LoginMember, targetMemberId: Long, page: Pageable, keyword: String): Page<ScheduleSearchResult>
}
