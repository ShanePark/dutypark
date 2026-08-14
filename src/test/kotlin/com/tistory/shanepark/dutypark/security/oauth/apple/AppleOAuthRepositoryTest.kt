package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest
import org.springframework.dao.DataIntegrityViolationException
import java.time.LocalDateTime

@DataJpaTest
class AppleOAuthRepositoryTest {
    @Autowired lateinit var replayRepository: AppleIdentityTokenReplayRepository
    @Autowired lateinit var credentialRepository: AppleOAuthCredentialRepository
    @Autowired lateinit var memberRepository: MemberRepository
    @Autowired lateinit var socialRepository: MemberSocialAccountRepository

    @Test
    fun `identity token hash is consumed only once`() {
        val now = LocalDateTime.now()
        replayRepository.saveAndFlush(AppleIdentityTokenReplay("a".repeat(64), now.plusMinutes(5), now))

        assertThrows<DataIntegrityViolationException> {
            replayRepository.saveAndFlush(AppleIdentityTokenReplay("a".repeat(64), now.plusMinutes(5), now))
        }
    }

    @Test
    fun `orphan cleanup query excludes credential linked to a member`() {
        val now = LocalDateTime.now()
        val linked = credentialRepository.saveAndFlush(credential("linked", now.minusDays(2)))
        val orphan = credentialRepository.saveAndFlush(credential("orphan", now.minusDays(2)))
        val member = memberRepository.saveAndFlush(Member("member", password = "pass"))
        socialRepository.saveAndFlush(MemberSocialAccount(member, SsoType.APPLE, linked.socialId))

        val found = credentialRepository.findOrphansUpdatedBefore(now.minusDays(1))

        assertThat(found.map { it.id }).containsExactly(orphan.id)
    }

    @Test
    fun `orphan cleanup waits until every client grant for a subject is stale`() {
        val now = LocalDateTime.now()
        credentialRepository.saveAndFlush(
            AppleOAuthCredential(
                socialId = "pending-signup",
                clientId = "native-client",
                encryptedRefreshToken = "old-native",
                createdAt = now.minusDays(2),
                updatedAt = now.minusDays(2),
            )
        )
        credentialRepository.saveAndFlush(
            AppleOAuthCredential(
                socialId = "pending-signup",
                clientId = "web-client",
                encryptedRefreshToken = "fresh-web",
                createdAt = now,
                updatedAt = now,
            )
        )

        val found = credentialRepository.findOrphansUpdatedBefore(now.minusDays(1))

        assertThat(found).isEmpty()
    }

    @Test
    fun `credentials preserve native and web grants for the same subject`() {
        val now = LocalDateTime.now()
        credentialRepository.saveAndFlush(
            AppleOAuthCredential(
                socialId = "shared-subject",
                clientId = "io.github.shanepark.dutypark",
                encryptedRefreshToken = "encrypted-native-subject",
                createdAt = now,
                updatedAt = now,
            )
        )
        credentialRepository.saveAndFlush(
            AppleOAuthCredential(
                socialId = "shared-subject",
                clientId = "io.github.shanepark.dutypark.web",
                encryptedRefreshToken = "encrypted-web-subject",
                createdAt = now,
                updatedAt = now,
            )
        )
        val found = credentialRepository.findAllByProviderAndSocialId(SsoType.APPLE, "shared-subject")

        assertThat(found.map { it.clientId }).containsExactlyInAnyOrder(
            "io.github.shanepark.dutypark",
            "io.github.shanepark.dutypark.web",
        )
    }

    private fun credential(subject: String, time: LocalDateTime) = AppleOAuthCredential(
        socialId = subject,
        encryptedRefreshToken = "encrypted-$subject",
        createdAt = time,
        updatedAt = time,
    )
}
