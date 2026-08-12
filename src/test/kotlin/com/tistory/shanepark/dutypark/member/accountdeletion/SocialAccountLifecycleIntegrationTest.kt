package com.tistory.shanepark.dutypark.member.accountdeletion

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionRequest
import com.tistory.shanepark.dutypark.member.accountdeletion.service.AccountDeletionService
import com.tistory.shanepark.dutypark.member.accountdeletion.worker.AccountDeletionWorker
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.member.service.MemberSocialAccountService
import com.tistory.shanepark.dutypark.security.reauth.ReauthPurpose
import com.tistory.shanepark.dutypark.security.reauth.ReauthService
import jakarta.persistence.EntityManager
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.util.UUID

class SocialAccountLifecycleIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    private lateinit var memberSocialAccountService: MemberSocialAccountService

    @Autowired
    private lateinit var memberSocialAccountRepository: MemberSocialAccountRepository

    @Autowired
    private lateinit var memberSsoRegisterRepository: MemberSsoRegisterRepository

    @Autowired
    private lateinit var reauthService: ReauthService

    @Autowired
    private lateinit var accountDeletionService: AccountDeletionService

    @Autowired
    private lateinit var accountDeletionWorker: AccountDeletionWorker

    @Autowired
    private lateinit var entityManager: EntityManager

    @Test
    fun `unlinked social identity can create and delete a new social-only account`() {
        val provider = SsoType.KAKAO
        val socialId = "kakao-lifecycle-${UUID.randomUUID()}"
        val existingMember = TestData.member
        val existingMemberId = existingMember.id!!
        memberSocialAccountRepository.saveAndFlush(MemberSocialAccount(existingMember, provider, socialId))
        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(existingMember, SsoType.NAVER, "naver-retained-${UUID.randomUUID()}")
        )

        memberSocialAccountService.unlink(loginMember(existingMember), provider)

        assertThat(memberSocialAccountRepository.findByProviderAndSocialId(provider, socialId)).isNull()

        val register = memberSsoRegisterRepository.saveAndFlush(MemberSsoRegister(provider, socialId))
        val socialOnlyMember = memberService.createSsoMember("social-new", register.uuid)
        val socialOnlyMemberId = socialOnlyMember.id!!

        assertThat(socialOnlyMember.team).isNull()
        assertThat(memberSocialAccountRepository.findByProviderAndSocialId(provider, socialId)?.member?.id)
            .isEqualTo(socialOnlyMemberId)

        val reauthProof = reauthService.issue(socialOnlyMemberId, ReauthPurpose.DELETE_ACCOUNT)
        accountDeletionService.requestDeletion(
            loginMember(socialOnlyMember),
            AccountDeletionRequest(
                confirmation = "DELETE",
                reauthProof = reauthProof.reauthProof,
            ),
        )

        accountDeletionWorker.processPendingJobs()
        entityManager.clear()

        assertThat(memberRepository.findById(socialOnlyMemberId)).isEmpty
        assertThat(memberSocialAccountRepository.findByProviderAndSocialId(provider, socialId)).isNull()
        assertThat(memberRepository.findById(existingMemberId)).isPresent
        assertThat(memberSocialAccountRepository.findByMemberAndProvider(existingMember, SsoType.NAVER)).isNotNull
    }
}
