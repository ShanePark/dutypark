package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.exception.SocialAccountUnlinkException
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.oauth.SocialAccountAlreadyLinkedException
import com.tistory.shanepark.dutypark.security.oauth.apple.AppleCredentialService
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class MemberSocialAccountService(
    private val memberRepository: MemberRepository,
    private val memberSocialAccountRepository: MemberSocialAccountRepository,
    private val appleCredentialService: AppleCredentialService,
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

    /**
     * Removes only Dutypark's local provider-to-member mapping. This deliberately does not call
     * Kakao or Naver APIs to revoke the user's provider account or provider-side authorization.
     */
    fun unlink(loginMember: LoginMember, provider: SsoType) {
        if (loginMember.isImpersonating) {
            throw SocialAccountUnlinkException("member.social.unlink.impersonationForbidden", 403)
        }

        // Serializes all unlink decisions for a member so concurrent requests cannot remove the last two methods.
        val member = memberRepository.findMemberWithTeamForUpdate(loginMember.id).orElseThrow()
        val linkedAccount = memberSocialAccountRepository.findByMemberAndProvider(member, provider) ?: return
        val remainingSocialCount = memberSocialAccountRepository.findAllByMemberIdIn(listOf(loginMember.id))
            .count { it.provider != provider }

        if (remainingSocialCount == 0) {
            throw SocialAccountUnlinkException("member.social.unlink.lastAuthenticationMethod", 409)
        }

        if (provider == SsoType.APPLE) {
            appleCredentialService.revokeAndDelete(linkedAccount.socialId)
        }
        memberSocialAccountRepository.delete(linkedAccount)
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
