package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSearchResult
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service

/**
 * When search engine is implemented, this service will be replaced with ScheduleSearchServiceESImpl
 */
@Service
class ScheduleSearchServiceDBImpl(
    private val scheduleRepository: ScheduleRepository,
    private val memberRepository: MemberRepository,
    private val friendService: FriendService,
) : ScheduleSearchService {

    override fun search(
        loginMember: LoginMember,
        targetMemberId: Long,
        page: Pageable,
        query: String
    ): Page<ScheduleSearchResult> {
        val target = memberRepository.findById(targetMemberId).orElseThrow()
        val availableVisibilities = friendService.availableVisibilities(loginMember, target)

        return scheduleRepository.findByMemberAndContentContainingAndVisibilityIn(
            member = target,
            content = query,
            visibility = availableVisibilities,
            pageable = page
        ).map { ScheduleSearchResult.of(it) }
    }

}
