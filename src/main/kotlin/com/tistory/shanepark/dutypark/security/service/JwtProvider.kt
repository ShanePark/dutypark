package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import io.jsonwebtoken.*
import io.jsonwebtoken.io.Decoders
import io.jsonwebtoken.security.Keys
import io.jsonwebtoken.security.SecurityException
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import java.security.Key
import java.util.*

@Component
class JwtProvider(
    @param:Value("\${jwt.secret}")
    val secretKey: String,
    @Value("\${jwt.token-validity-in-seconds}") tokenValidityInSeconds: Long
) {

    private val key: Key
    private val tokenValidityInMilliseconds: Long
    private val log: org.slf4j.Logger = org.slf4j.LoggerFactory.getLogger(JwtProvider::class.java)

    init {
        tokenValidityInMilliseconds = 1000 * tokenValidityInSeconds
        key = Keys.hmacShaKeyFor(Decoders.BASE64.decode(secretKey))
    }

    fun createToken(member: Member): String {

        val validity = Date(Date().time + tokenValidityInMilliseconds)

        val department = member.department
        return Jwts.builder()
            .setSubject(member.id.toString())
            .claim("email", member.email)
            .claim("name", member.name)
            .claim("departmentId", department.id)
            .claim("departmentName", department.name)
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

        return LoginMember(
            id = claims.subject.toLong(),
            email = claims["email"] as String,
            name = claims["name"] as String,
            departmentId = claims["departmentId"].toString().toLong(),
            departmentName = claims["departmentName"] as String
        )
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
