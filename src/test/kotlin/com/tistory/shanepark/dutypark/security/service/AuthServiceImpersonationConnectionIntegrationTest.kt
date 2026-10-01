package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberManager
import com.tistory.shanepark.dutypark.member.domain.enums.ManagerRole
import com.tistory.shanepark.dutypark.member.repository.MemberManagerRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.zaxxer.hikari.HikariDataSource
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.Mockito.clearInvocations
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.annotation.DirtiesContext
import org.springframework.test.context.TestPropertySource
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean
import org.springframework.transaction.support.TransactionTemplate
import javax.sql.DataSource

@SpringBootTest
@TestPropertySource(
    properties = [
        "spring.datasource.url=jdbc:h2:mem:auth-impersonation-connection",
        "spring.datasource.hikari.maximum-pool-size=1",
        "spring.datasource.hikari.connection-timeout=1000",
    ]
)
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class AuthServiceImpersonationConnectionIntegrationTest {

    @Autowired
    lateinit var authService: AuthService

    @Autowired
    lateinit var memberRepository: MemberRepository

    @Autowired
    lateinit var memberManagerRepository: MemberManagerRepository

    @Autowired
    lateinit var refreshTokenService: RefreshTokenService

    @Autowired
    lateinit var refreshTokenRepository: RefreshTokenRepository

    @Autowired
    lateinit var jwtProvider: JwtProvider

    @Autowired
    lateinit var transactionTemplate: TransactionTemplate

    @MockitoSpyBean
    lateinit var dataSource: DataSource

    @Test
    fun `impersonation authentication preserves actor ids with a single connection`() {
        val account = createImpersonationAccount()
        val hikariDataSource = dataSource.unwrap(HikariDataSource::class.java)
        clearInvocations(hikariDataSource)

        try {
            val authenticated = authService.authenticateToken(account.token)

            assertThat(authenticated?.id).isEqualTo(account.managedId)
            assertThat(authenticated?.isImpersonating).isTrue()
            assertThat(authenticated?.originalMemberId).isEqualTo(account.managerId)
            verify(hikariDataSource, times(1)).getConnection()
        } finally {
            deleteImpersonationAccount(account)
        }
    }

    private fun createImpersonationAccount(): ImpersonationAccount = transactionTemplate.execute {
        val suffix = System.nanoTime().toString().takeLast(6)
        val manager = memberRepository.saveAndFlush(
            Member(name = "mgr$suffix", email = "manager-$suffix@duty.park")
        )
        val managed = memberRepository.saveAndFlush(
            Member(name = "tgt$suffix", email = "managed-$suffix@duty.park")
        )
        memberManagerRepository.saveAndFlush(MemberManager(manager, managed, ManagerRole.MANAGER))
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = requireNotNull(manager.id),
            remoteAddr = "127.0.0.1",
            userAgent = "AuthServiceImpersonationConnectionIntegrationTest",
        )

        ImpersonationAccount(
            managerId = requireNotNull(manager.id),
            managedId = requireNotNull(managed.id),
            refreshTokenId = requireNotNull(refreshToken.id),
            token = jwtProvider.createImpersonationToken(
                target = managed,
                originalMemberId = requireNotNull(manager.id),
                sessionId = requireNotNull(refreshToken.id),
            ),
        )
    }

    private fun deleteImpersonationAccount(account: ImpersonationAccount) {
        transactionTemplate.execute {
            val manager = memberRepository.findById(account.managerId).orElse(null) ?: return@execute
            val managed = memberRepository.findById(account.managedId).orElse(null) ?: return@execute
            memberManagerRepository.deleteAll(memberManagerRepository.findAllByManagerAndManaged(manager, managed))
            refreshTokenRepository.deleteById(account.refreshTokenId)
            memberRepository.delete(managed)
            memberRepository.delete(manager)
        }
    }

    private data class ImpersonationAccount(
        val managerId: Long,
        val managedId: Long,
        val refreshTokenId: Long,
        val token: String,
    )
}
