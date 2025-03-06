package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.config.DutyparkProperties
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import io.jsonwebtoken.*
import io.jsonwebtoken.io.Decoders
import io.jsonwebtoken.security.Keys
import io.jsonwebtoken.security.SecurityException
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import java.security.Key
import java.util.*

@Component
class JwtProvider(
    private val dutyparkProperties: DutyparkProperties,
    jwtConfig: JwtConfig,
) {
    private val key: Key = Keys.hmacShaKeyFor(Decoders.BASE64.decode(jwtConfig.secret))
    private val tokenValidityInMilliseconds: Long = 1000L * jwtConfig.tokenValidityInSeconds
    private val log: Logger = LoggerFactory.getLogger(JwtProvider::class.java)

    fun createToken(member: Member): String {

        val validity = Date(Date().time + tokenValidityInMilliseconds)

        val department = member.department
        return Jwts.builder()
            .setSubject(member.id.toString())
            .claim("email", member.email)
            .claim("name", member.name)
            .claim("departmentId", department?.id)
            .claim("departmentName", department?.name)
            .signWith(key, SignatureAlgorithm.HS256)
            .setExpiration(validity)
            .compact()
    }

    fun parseToken(token: String): LoginMember {
        val claims = Jwts
            .parserBuilder()
            .setSigningKey(key)
            .build()
            .parseClaimsJws(token)
            .body

        val email = claims["email"] as String?

        val loginMember = LoginMember(
            id = claims.subject.toLong(),
            email = email,
            name = claims["name"] as String,
            departmentId = claims["departmentId"]?.toString()?.toLong(),
            department = claims["departmentName"] as String?,
            isAdmin = dutyparkProperties.adminEmails.contains(email),
        )
        return loginMember
    }

    fun validateToken(token: String?): TokenStatus {
        try {
            Jwts.parserBuilder().setSigningKey(key).build().parseClaimsJws(token)
        } catch (e: Exception) {
            when (e) {
                is SecurityException -> {
                    log.info("Invalid JWT signature.")
                    return TokenStatus.INVALID
                }

                is MalformedJwtException -> {
                    log.info("Invalid JWT token.")
                    return TokenStatus.INVALID
                }

                is IllegalArgumentException -> {
                    log.info("JWT token compact of handler are invalid.")
                    return TokenStatus.INVALID
                }

                is ExpiredJwtException -> return TokenStatus.EXPIRED
                is UnsupportedJwtException -> return TokenStatus.UNSUPPORTED
            }
        }
        return TokenStatus.VALID
    }


}
