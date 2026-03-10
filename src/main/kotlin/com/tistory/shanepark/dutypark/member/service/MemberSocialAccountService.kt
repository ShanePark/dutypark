package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import com.tistory.shanepark.dutypark.security.oauth.SocialAccountAlreadyLinkedException
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class MemberSocialAccountService(
    private val memberSocialAccountRepository: MemberSocialAccountRepository,
) {

    @Transactional(readOnly = true)
    fun findMemberByProviderAndSocialId(provider: SsoType, socialId: String): Member? {
        return memberSocialAccountRepository.findByProviderAndSocialId(provider, socialId)?.member
    }

    fun link(member: Member, provider: SsoType, socialId: String) {
        memberSocialAccountRepository.findByProviderAndSocialId(provider, socialId)?.let { existing ->
            if (existing.member.id == member.id) {
                return
            }
            throw SocialAccountAlreadyLinkedException(provider)
        }

        memberSocialAccountRepository.findByMemberAndProvider(member, provider)?.let { existing ->
            if (existing.socialId == socialId) {
                return
            }
            throw SocialAccountAlreadyLinkedException(provider)
        }

        try {
            memberSocialAccountRepository.saveAndFlush(
                MemberSocialAccount(member = member, provider = provider, socialId = socialId)
            )
        } catch (_: DataIntegrityViolationException) {
            throw SocialAccountAlreadyLinkedException(provider)
        }
    }

    @Transactional(readOnly = true)
    fun findProviderMapByMemberIds(memberIds: Collection<Long>): Map<Long, Map<SsoType, String>> {
        if (memberIds.isEmpty()) {
            return emptyMap()
        }

        return memberSocialAccountRepository.findAllByMemberIdIn(memberIds)
            .groupBy { it.member.id ?: throw IllegalStateException("Member id is null") }
            .mapValues { (_, accounts) ->
                accounts.associate { it.provider to it.socialId }
            }
    }
}
