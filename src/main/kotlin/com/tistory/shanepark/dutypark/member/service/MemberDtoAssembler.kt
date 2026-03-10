package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional(readOnly = true)
class MemberDtoAssembler(
    private val memberSocialAccountService: MemberSocialAccountService,
) {

    fun toDto(member: Member): MemberDto {
        val memberId = member.id ?: return MemberDto.of(member)
        val providerMap = memberSocialAccountService.findProviderMapByMemberIds(setOf(memberId))[memberId].orEmpty()
        return MemberDto.of(
            member = member,
            kakaoId = providerMap[SsoType.KAKAO],
            naverId = providerMap[SsoType.NAVER],
        )
    }

    fun toDtos(members: Collection<Member>): List<MemberDto> {
        if (members.isEmpty()) {
            return emptyList()
        }

        val providerMapByMemberId = memberSocialAccountService.findProviderMapByMemberIds(members.mapNotNull { it.id }.toSet())

        return members.map { member ->
            val providerMap = member.id?.let { providerMapByMemberId[it] }.orEmpty()
            MemberDto.of(
                member = member,
                kakaoId = providerMap[SsoType.KAKAO],
                naverId = providerMap[SsoType.NAVER],
            )
        }
    }
}
