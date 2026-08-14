package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.config.DutyparkProperties
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import io.jsonwebtoken.Claims
import io.jsonwebtoken.ExpiredJwtException
import io.jsonwebtoken.Jwts
import io.jsonwebtoken.UnsupportedJwtException
import io.jsonwebtoken.io.Decoders
import io.jsonwebtoken.security.Keys
import org.springframework.stereotype.Component
import java.util.*
import javax.crypto.SecretKey

@Component
class JwtProvider(
    private val dutyparkProperties: DutyparkProperties,
    jwtConfig: JwtConfig,
) {
    private val key: SecretKey = createSigningKey(jwtConfig.secret)
    private val tokenValidityInMilliseconds: Long = 1000L * jwtConfig.tokenValidityInSeconds

    fun createToken(member: Member, sessionId: Long): String {

        val validity = Date(Date().time + tokenValidityInMilliseconds)

        val team = member.team
        return Jwts.builder()
            .subject(member.id.toString())
            .claim("email", member.email)
            .claim("name", member.name)
            .claim("teamId", team?.id)
            .claim("teamName", team?.name)
            .claim(SESSION_ID_CLAIM, sessionId)
            .signWith(key)
            .expiration(validity)
            .compact()
    }

    fun createImpersonationToken(target: Member, originalMemberId: Long, sessionId: Long): String {
        val validity = Date(Date().time + tokenValidityInMilliseconds)

        val team = target.team
        return Jwts.builder()
            .subject(target.id.toString())
            .claim("email", target.email)
            .claim("name", target.name)
            .claim("teamId", team?.id)
            .claim("teamName", team?.name)
            .claim("originalSub", originalMemberId.toString())
            .claim("impersonated", true)
            .claim(SESSION_ID_CLAIM, sessionId)
            .signWith(key)
            .expiration(validity)
            .compact()
    }

    fun parseToken(token: String): LoginMember {
        return try {
            val claims = parseClaims(token)
            claimsToLoginMember(claims)
        } catch (_: Exception) {
            throw AuthException()
        }
    }

    private fun parseClaims(token: String?): Claims = Jwts
        .parser()
        .verifyWith(key)
        .build()
        .parseSignedClaims(token)
        .payload

    private fun claimsToLoginMember(claims: Claims): LoginMember {
        val email = claims["email"] as String?
        val teamId = (claims["teamId"] as? Number)?.toLong()
        val isImpersonated = claims["impersonated"] as? Boolean ?: false
        val originalSub = claims["originalSub"] as? String
        val sessionId = (claims[SESSION_ID_CLAIM] as? Number)?.toLong()

        return LoginMember(
            id = claims.subject.toLong(),
            email = email,
            name = claims["name"] as String,
            teamId = teamId,
            team = claims["teamName"] as String?,
            isAdmin = dutyparkProperties.adminEmails.contains(email),
            isImpersonating = isImpersonated,
            originalMemberId = originalSub?.toLongOrNull(),
            sessionId = sessionId,
        )
    }

    fun validateToken(token: String?): TokenStatus {
        try {
            claimsToLoginMember(parseClaims(token))
        } catch (e: Exception) {
            return when (e) {
                is ExpiredJwtException -> TokenStatus.EXPIRED
                is UnsupportedJwtException -> TokenStatus.UNSUPPORTED
                else -> TokenStatus.INVALID
            }
        }
        return TokenStatus.VALID
    }

    companion object {
        private const val SESSION_ID_CLAIM = "sessionId"
        private const val MIN_SECRET_BYTES = 32

        private fun createSigningKey(secret: String): SecretKey {
            require(secret.isNotBlank()) { "JWT secret must not be blank" }
            val decoded = try {
                Decoders.BASE64.decode(secret)
            } catch (e: RuntimeException) {
                throw IllegalArgumentException("JWT secret must be valid Base64", e)
            }
            require(decoded.size >= MIN_SECRET_BYTES) {
                "JWT secret must decode to at least $MIN_SECRET_BYTES bytes"
            }
            return Keys.hmacShaKeyFor(decoded)
        }
    }
}
