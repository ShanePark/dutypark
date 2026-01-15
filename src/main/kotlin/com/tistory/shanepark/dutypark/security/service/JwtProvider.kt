package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.config.DutyparkProperties
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import io.jsonwebtoken.ExpiredJwtException
import io.jsonwebtoken.Jwts
import io.jsonwebtoken.MalformedJwtException
import io.jsonwebtoken.UnsupportedJwtException
import io.jsonwebtoken.io.Decoders
import io.jsonwebtoken.security.Keys
import io.jsonwebtoken.security.SecurityException
import org.springframework.stereotype.Component
import java.util.*
import javax.crypto.SecretKey

@Component
class JwtProvider(
    private val dutyparkProperties: DutyparkProperties,
    jwtConfig: JwtConfig,
) {
    private val key: SecretKey = Keys.hmacShaKeyFor(Decoders.BASE64.decode(jwtConfig.secret))
    private val tokenValidityInMilliseconds: Long = 1000L * jwtConfig.tokenValidityInSeconds
    private val log = logger()

    fun createToken(member: Member): String {

        val validity = Date(Date().time + tokenValidityInMilliseconds)

        val team = member.team
        return Jwts.builder()
            .subject(member.id.toString())
            .claim("email", member.email)
            .claim("name", member.name)
            .claim("teamId", team?.id)
            .claim("teamName", team?.name)
            .signWith(key)
            .expiration(validity)
            .compact()
    }

    fun createImpersonationToken(target: Member, originalMemberId: Long): String {
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
            .signWith(key)
            .expiration(validity)
            .compact()
    }

    fun parseToken(token: String): LoginMember {
        val claims = Jwts
            .parser()
            .verifyWith(key)
            .build()
            .parseSignedClaims(token)
            .payload

        val email = claims["email"] as String?
        val teamId = (claims["teamId"] as? Number)?.toLong()
        val isImpersonated = claims["impersonated"] as? Boolean ?: false
        val originalSub = claims["originalSub"] as? String

        val loginMember = LoginMember(
            id = claims.subject.toLong(),
            email = email,
            name = claims["name"] as String,
            teamId = teamId,
            team = claims["teamName"] as String?,
            isAdmin = dutyparkProperties.adminEmails.contains(email),
            isImpersonating = isImpersonated,
            originalMemberId = originalSub?.toLongOrNull()
        )
        return loginMember
    }

    fun validateToken(token: String?): TokenStatus {
        try {
            Jwts.parser().verifyWith(key).build().parseSignedClaims(token)
        } catch (e: Exception) {
            when (e) {
                is SecurityException -> {
                    return TokenStatus.INVALID
                }

                is MalformedJwtException -> {
                    return TokenStatus.INVALID
                }

                is IllegalArgumentException -> {
                    return TokenStatus.INVALID
                }

                is ExpiredJwtException -> return TokenStatus.EXPIRED
                is UnsupportedJwtException -> return TokenStatus.UNSUPPORTED
            }
        }
        return TokenStatus.VALID
    }


}
