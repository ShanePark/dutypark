package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSearchResult
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.data.domain.PageImpl
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

/**
 * When search engine is implemented, this service will be replaced with ScheduleSearchServiceESImpl
 */
@Service
class ScheduleSearchServiceDBImpl(
    private val scheduleRepository: ScheduleRepository,
    private val memberRepository: MemberRepository,
    private val friendService: FriendService,
) : ScheduleSearchService {

    @Transactional(readOnly = true)
    override fun search(
        loginMember: LoginMember?,
        targetMemberId: Long,
        page: Pageable,
        query: String
    ): PageResponse<ScheduleSearchResult> {
        val target = memberRepository.findById(targetMemberId).orElseThrow()
        val availableVisibilities = friendService.availableScheduleVisibilities(loginMember, target)

        val pageOfIds = scheduleRepository.findSearchIdsByMemberAndContentContainingAndVisibilityIn(
            member = target,
            content = query,
            visibility = availableVisibilities,
            pageable = page
        )
        if (pageOfIds.isEmpty) {
            return PageResponse(PageImpl(emptyList(), pageOfIds.pageable, pageOfIds.totalElements))
        }

        val schedulesById = scheduleRepository.findAllWithMemberAndTagsByIdIn(pageOfIds.content)
            .associateBy { it.id }
        val orderedSchedules = pageOfIds.content.map(schedulesById::getValue)
        val result = orderedSchedules.map { ScheduleSearchResult.of(it) }

        return PageResponse(PageImpl(result, pageOfIds.pageable, pageOfIds.totalElements))
    }

}
