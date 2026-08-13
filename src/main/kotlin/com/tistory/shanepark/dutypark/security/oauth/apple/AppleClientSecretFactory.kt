package com.tistory.shanepark.dutypark.security.oauth.apple

import io.jsonwebtoken.Jwts
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import java.security.KeyFactory
import java.security.PrivateKey
import java.security.spec.PKCS8EncodedKeySpec
import java.time.Clock
import java.time.Duration
import java.util.Base64
import java.util.Date

@Component
class AppleClientSecretFactory(
    private val clock: Clock,
    @param:Value("\${oauth.apple.client-id:}") private val clientId: String,
    @param:Value("\${oauth.apple.team-id:}") private val teamId: String,
    @param:Value("\${oauth.apple.key-id:}") private val keyId: String,
    @param:Value("\${oauth.apple.private-key:}") private val privateKeyPem: String,
) {
    fun clientId(): String = clientId.takeIf(String::isNotBlank)
        ?: throw AppleOAuthException("auth.apple.configurationUnavailable", 503)

    fun create(): String {
        if (teamId.isBlank() || keyId.isBlank() || privateKeyPem.isBlank()) {
            throw AppleOAuthException("auth.apple.configurationUnavailable", 503)
        }
        val now = clock.instant()
        return try {
            Jwts.builder()
                .header().keyId(keyId).and()
                .issuer(teamId)
                .subject(clientId())
                .audience().add("https://appleid.apple.com").and()
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(CLIENT_SECRET_TTL)))
                .signWith(parsePrivateKey(), Jwts.SIG.ES256)
                .compact()
        } catch (e: AppleOAuthException) {
            throw e
        } catch (e: Exception) {
            throw AppleOAuthException("auth.apple.configurationUnavailable", 503, e)
        }
    }

    private fun parsePrivateKey(): PrivateKey {
        val encoded = privateKeyPem.replace("\\n", "\n")
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .filterNot(Char::isWhitespace)
        return KeyFactory.getInstance("EC").generatePrivate(
            PKCS8EncodedKeySpec(Base64.getDecoder().decode(encoded))
        )
    }

    companion object {
        private val CLIENT_SECRET_TTL: Duration = Duration.ofMinutes(10)
    }
}
