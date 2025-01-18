package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSearchResult
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.data.domain.Pageable

interface ScheduleSearchService {

    fun search(
        loginMember: LoginMember,
        targetMemberId: Long,
        page: Pageable,
        query: String
    ): PageResponse<ScheduleSearchResult>
}
