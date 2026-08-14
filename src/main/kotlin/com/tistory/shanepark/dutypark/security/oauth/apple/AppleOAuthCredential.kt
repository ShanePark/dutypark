package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(
    name = "apple_oauth_credential",
    uniqueConstraints = [UniqueConstraint(
        name = "uk_apple_oauth_credential_provider_social_client",
        columnNames = ["provider", "social_id", "client_id"],
    )],
)
class AppleOAuthCredential(
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val provider: SsoType = SsoType.APPLE,
    @Column(name = "social_id", nullable = false)
    val socialId: String,
    @Column(name = "client_id")
    var clientId: String? = null,
    @Column(name = "encrypted_refresh_token", nullable = false, columnDefinition = "TEXT")
    var encryptedRefreshToken: String,
    @Column(name = "created_at", nullable = false)
    val createdAt: LocalDateTime,
    @Column(name = "updated_at", nullable = false)
    var updatedAt: LocalDateTime,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set
}

interface AppleOAuthCredentialRepository : org.springframework.data.jpa.repository.JpaRepository<AppleOAuthCredential, Long> {
    fun findByProviderAndSocialIdAndClientId(provider: SsoType, socialId: String, clientId: String): AppleOAuthCredential?
    fun findByProviderAndSocialIdAndClientIdIsNull(provider: SsoType, socialId: String): AppleOAuthCredential?
    fun findAllByProviderAndSocialId(provider: SsoType, socialId: String): List<AppleOAuthCredential>

    @org.springframework.data.jpa.repository.Query(
        """
        select credential from AppleOAuthCredential credential
        where credential.updatedAt < :cutoff
          and not exists (
            select sibling.id from AppleOAuthCredential sibling
            where sibling.provider = credential.provider
              and sibling.socialId = credential.socialId
              and sibling.updatedAt >= :cutoff
          )
          and not exists (
            select account.id from MemberSocialAccount account
            where account.provider = credential.provider and account.socialId = credential.socialId
          )
        """
    )
    fun findOrphansUpdatedBefore(cutoff: LocalDateTime): List<AppleOAuthCredential>
}
