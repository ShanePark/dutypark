package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.TestUtils
import io.jsonwebtoken.Jwts
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import java.nio.charset.StandardCharsets
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.MessageDigest
import java.security.interfaces.RSAPublicKey
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import java.util.Base64
import java.util.Date

class AppleIdentityTokenVerifierTest {
    private val now = Instant.parse("2026-08-13T00:00:00Z")
    private val clock = Clock.fixed(now, ZoneOffset.UTC)
    private val keys = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
    private val provider: AppleProviderClient = mock()
    private val clientSecretFactory = AppleClientSecretFactory(clock, CLIENT_ID, "", "", "")

    @Test
    fun `verifies Apple RS256 identity token and hashed nonce`() {
        whenever(provider.jwks()).thenReturn(AppleJwks(listOf(jwk(keys))))
        val verifier = verifier()

        val result = verifier.verify(token(keys, nonce = sha256Hex("raw-nonce-value-that-is-long-enough")), "raw-nonce-value-that-is-long-enough")

        assertThat(result.subject).isEqualTo("apple-subject")
    }

    @Test
    fun `rejects invalid nonce audience issuer expiration future issued-at and signature`() {
        val otherKeys = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
        val cases = listOf(
            token(keys, nonce = "wrong"),
            token(keys, audience = "wrong", nonce = sha256Hex(RAW_NONCE)),
            token(keys, issuer = "https://evil.example", nonce = sha256Hex(RAW_NONCE)),
            token(keys, expiresAt = now.minusSeconds(121), nonce = sha256Hex(RAW_NONCE)),
            token(keys, issuedAt = now.plusSeconds(121), nonce = sha256Hex(RAW_NONCE)),
            token(keys, issuedAt = now.minusSeconds(601), nonce = sha256Hex(RAW_NONCE)),
            token(otherKeys, nonce = sha256Hex(RAW_NONCE)),
        )

        cases.forEach { candidate ->
            whenever(provider.jwks()).thenReturn(AppleJwks(listOf(jwk(keys))))
            val exception = assertThrows<AppleOAuthException> { verifier().verify(candidate, RAW_NONCE) }
            assertThat(exception.message).isEqualTo("auth.apple.credential.invalid")
        }
    }

    @Test
    fun `rejects unsupported algorithm before accepting a matching key id`() {
        whenever(provider.jwks()).thenReturn(AppleJwks(listOf(jwk(keys))))
        val token = Jwts.builder()
            .header().keyId("apple-kid").and()
            .issuer("https://appleid.apple.com")
            .audience().add(CLIENT_ID).and()
            .subject("apple-subject")
            .issuedAt(Date.from(now))
            .expiration(Date.from(now.plusSeconds(300)))
            .claim("nonce", sha256Hex(RAW_NONCE))
            .signWith(ByteArray(32) { 7 }.let { javax.crypto.spec.SecretKeySpec(it, "HmacSHA256") }, Jwts.SIG.HS256)
            .compact()

        assertThrows<AppleOAuthException> { verifier().verify(token, RAW_NONCE) }
    }

    @Test
    fun `refreshes cached JWKS once when a new key id appears`() {
        val rotated = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
        whenever(provider.jwks()).thenReturn(
            AppleJwks(listOf(jwk(keys, "old-kid"))),
            AppleJwks(listOf(jwk(rotated, "new-kid"))),
        )
        val verifier = verifier()

        verifier.verify(token(keys, kid = "old-kid", nonce = sha256Hex(RAW_NONCE)), RAW_NONCE)
        verifier.verify(token(keys, kid = "old-kid", nonce = sha256Hex(RAW_NONCE)), RAW_NONCE)
        verifier.verify(token(rotated, kid = "new-kid", nonce = sha256Hex(RAW_NONCE)), RAW_NONCE)

        verify(provider, times(2)).jwks()
    }

    private fun verifier() = AppleIdentityTokenVerifier(provider, clientSecretFactory, TestUtils.jsr310JsonMapper(), clock)

    private fun token(
        keyPair: KeyPair,
        issuer: String = "https://appleid.apple.com",
        audience: String = CLIENT_ID,
        issuedAt: Instant = now,
        expiresAt: Instant = now.plusSeconds(300),
        kid: String = "apple-kid",
        nonce: String,
    ): String = Jwts.builder()
        .header().keyId(kid).and()
        .issuer(issuer)
        .audience().add(audience).and()
        .subject("apple-subject")
        .issuedAt(Date.from(issuedAt))
        .expiration(Date.from(expiresAt))
        .claim("nonce", nonce)
        .signWith(keyPair.private, Jwts.SIG.RS256)
        .compact()

    private fun jwk(keyPair: KeyPair, kid: String = "apple-kid"): AppleJwk {
        val public = keyPair.public as RSAPublicKey
        return AppleJwk(
            kty = "RSA",
            kid = kid,
            use = "sig",
            alg = "RS256",
            n = base64Unsigned(public.modulus.toByteArray()),
            e = base64Unsigned(public.publicExponent.toByteArray()),
        )
    }

    private fun base64Unsigned(value: ByteArray): String = Base64.getUrlEncoder().withoutPadding()
        .encodeToString(value.dropWhile { it == 0.toByte() }.toByteArray())

    private fun sha256Hex(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(StandardCharsets.UTF_8))
        .joinToString("") { "%02x".format(it) }

    companion object {
        private const val CLIENT_ID = "io.github.shanepark.dutypark"
        private const val RAW_NONCE = "raw-nonce-value-that-is-long-enough"
    }
}
