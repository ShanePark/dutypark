package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
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

        return Jwts.builder()
            .setSubject(member.id.toString())
            .claim("email", member.email)
            .claim("name", member.name)
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

        return LoginMember(claims.subject.toLong(), claims["email"] as String, claims["name"] as String)
    }

    fun isValidToken(token: String?): Boolean {
        try {
            Jwts.parserBuilder().setSigningKey(key).build().parseClaimsJws(token)
            return true
        } catch (e: Exception) {
            when (e) {
                is SecurityException -> log.info("Invalid JWT signature.")
                is MalformedJwtException -> log.info("Invalid JWT token.")
                is ExpiredJwtException -> log.info("Expired JWT token.")
                is UnsupportedJwtException -> log.info("Unsupported JWT token.")
                is IllegalArgumentException -> log.info("JWT token compact of handler are invalid.")
            }
        }
        return false
    }


}
