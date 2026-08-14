package com.tistory.shanepark.dutypark.security.oauth.apple

import io.jsonwebtoken.Jwts
import org.springframework.stereotype.Component
import tools.jackson.databind.ObjectMapper
import java.math.BigInteger
import java.nio.charset.StandardCharsets
import java.security.KeyFactory
import java.security.MessageDigest
import java.security.PublicKey
import java.security.spec.RSAPublicKeySpec
import java.time.Clock
import java.time.Duration
import java.util.Base64

@Component
class AppleIdentityTokenVerifier(
    private val providerClient: AppleProviderClient,
    private val clientSecretFactory: AppleClientSecretFactory,
    private val objectMapper: ObjectMapper,
    private val clock: Clock,
) {
    @Volatile private var cache: KeyCache? = null
    private var unknownKidRefreshBlockedUntil = Long.MIN_VALUE

    fun verify(token: String, rawNonce: String?, requireNonce: Boolean = true): VerifiedAppleIdentity {
        return verify(token, rawNonce, clientSecretFactory.clientId(), requireNonce)
    }

    fun verify(
        token: String,
        rawNonce: String?,
        audience: String,
        requireNonce: Boolean = true,
    ): VerifiedAppleIdentity {
        val parts = token.split('.')
        if (parts.size != 3) invalid()
        val header = try {
            objectMapper.readTree(String(Base64.getUrlDecoder().decode(parts[0]), StandardCharsets.UTF_8))
        } catch (_: Exception) {
            invalid()
        }
        val kid = header.get("kid")?.asText().orEmpty()
        if (header.get("alg")?.asText() != "RS256" || kid.isBlank()) invalid()
        val key = findKey(kid) ?: invalid()
        if (key.kty != "RSA" || key.alg?.let { it != "RS256" } == true || key.use?.let { it != "sig" } == true) invalid()

        val verificationKey = publicKey(key)
        val claims = try {
            Jwts.parser()
                .verifyWith(verificationKey)
                .clock { java.util.Date.from(clock.instant()) }
                .clockSkewSeconds(CLOCK_SKEW.seconds)
                .build()
                .parseSignedClaims(token)
                .payload
        } catch (_: Exception) {
            invalid()
        }
        val now = clock.instant().epochSecond
        if (audience.isBlank() || claims.issuer != APPLE_ISSUER || claims.audience?.contains(audience) != true) invalid()
        val subject = claims.subject?.takeIf { it.isNotBlank() && it.length <= 255 } ?: invalid()
        val expiration = claims.expiration?.toInstant()?.epochSecond ?: invalid()
        val issuedAt = claims.issuedAt?.toInstant()?.epochSecond ?: invalid()
        if (expiration < now - CLOCK_SKEW.seconds || issuedAt > now + CLOCK_SKEW.seconds) invalid()
        if (issuedAt < now - MAX_TOKEN_AGE.seconds) invalid()
        if (requireNonce) {
            val nonce = claims["nonce"] as? String ?: invalid()
            val expected = sha256Hex(rawNonce ?: invalid())
            if (!MessageDigest.isEqual(
                    nonce.toByteArray(StandardCharsets.US_ASCII),
                    expected.toByteArray(StandardCharsets.US_ASCII),
                )
            ) invalid()
        }
        return VerifiedAppleIdentity(subject, expiration)
    }

    @Synchronized
    private fun findKey(kid: String): AppleJwk? {
        val now = clock.instant().epochSecond
        val validCache = cache?.takeIf { now < it.expiresAt }
        validCache?.keys?.firstOrNull { it.kid == kid }?.let { return it }
        if (validCache != null && now < unknownKidRefreshBlockedUntil) return null

        val fetched = providerClient.jwks().keys
        cache = KeyCache(fetched, now + JWKS_TTL.seconds)
        return fetched.firstOrNull { it.kid == kid }
            ?: run {
                unknownKidRefreshBlockedUntil = now + UNKNOWN_KID_REFRESH_COOLDOWN.seconds
                null
            }
    }

    private fun publicKey(jwk: AppleJwk): PublicKey {
        return try {
            val modulus = BigInteger(1, Base64.getUrlDecoder().decode(jwk.n))
            val exponent = BigInteger(1, Base64.getUrlDecoder().decode(jwk.e))
            KeyFactory.getInstance("RSA").generatePublic(RSAPublicKeySpec(modulus, exponent))
        } catch (e: Exception) {
            throw AppleOAuthException("auth.apple.provider.unavailable", 503, e)
        }
    }

    private fun sha256Hex(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(StandardCharsets.UTF_8))
        .joinToString("") { "%02x".format(it) }

    private fun invalid(): Nothing = throw AppleOAuthException("auth.apple.credential.invalid")

    private data class KeyCache(val keys: List<AppleJwk>, val expiresAt: Long)

    companion object {
        private const val APPLE_ISSUER = "https://appleid.apple.com"
        private val CLOCK_SKEW = Duration.ofMinutes(2)
        private val MAX_TOKEN_AGE = Duration.ofMinutes(10)
        private val JWKS_TTL = Duration.ofHours(6)
        private val UNKNOWN_KID_REFRESH_COOLDOWN = Duration.ofMinutes(1)
    }
}
