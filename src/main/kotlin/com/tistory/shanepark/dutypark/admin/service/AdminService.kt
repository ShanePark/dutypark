package com.tistory.shanepark.dutypark.admin.service

import com.tistory.shanepark.dutypark.admin.domain.dto.AdminMemberDto
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.member.service.ProfilePhotoService
import org.springframework.data.domain.Page
import org.springframework.data.domain.PageImpl
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional(readOnly = true)
class AdminService(
    private val memberRepository: MemberRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val profilePhotoService: ProfilePhotoService,
) {

    fun findAllMembersWithTokens(keyword: String?, pageable: Pageable): Page<AdminMemberDto> {
        val memberPage = if (keyword.isNullOrBlank()) {
            memberRepository.findAllOrderByLastTokenAccess(pageable)
        } else {
            memberRepository.findByNameContainingOrderByLastTokenAccess(keyword, pageable)
        }

        val memberIds = memberPage.content.mapNotNull { it.id }
        val tokensByMemberId = refreshTokenRepository.findAllByMemberIdIn(memberIds)
            .groupBy { it.member.id!! }

        val profilePhotoUrls = profilePhotoService.getProfilePhotoUrls(memberIds)

        val adminMembers = memberPage.content.map { member ->
            AdminMemberDto.of(
                member = member,
                tokens = tokensByMemberId[member.id] ?: emptyList(),
                profilePhotoUrl = profilePhotoUrls[member.id]
            )
        }

        return PageImpl(adminMembers, pageable, memberPage.totalElements)
    }

}
