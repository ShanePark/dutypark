package com.tistory.shanepark.dutypark.push.apns.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.push.apns.domain.repository.ApnsInstallationRepository
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.post

class ApnsInstallationControllerTest : RestDocsTest() {
    @Autowired
    lateinit var apnsInstallationRepository: ApnsInstallationRepository

    @Autowired
    lateinit var refreshTokenService: RefreshTokenService

    @Autowired
    lateinit var refreshTokenRepository: RefreshTokenRepository

    @Test
    fun `register stores installation for matching refresh session`() {
        val refreshToken = refreshTokenService.createRefreshToken(TestData.member.id!!, null, null)
        mockMvc.post("/api/auth/push/apns/register") {
            cookie(
                Cookie(CookieService.ACCESS_TOKEN_COOKIE, getJwt(TestData.member)),
                Cookie(CookieService.REFRESH_TOKEN_COOKIE, refreshToken.token),
            )
            contentType = MediaType.APPLICATION_JSON
            content = """{"deviceToken":"device-token","sandbox":true}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.success") { value(true) }
        }

        val installation = apnsInstallationRepository.findByDeviceToken("device-token")
        assertThat(installation?.refreshToken?.id).isEqualTo(refreshToken.id)
        assertThat(installation?.refreshToken?.member?.id).isEqualTo(TestData.member.id)
        assertThat(installation?.sandbox).isTrue()
    }

    @Test
    fun `unregister removes only current refresh session installation`() {
        val memberRefreshToken = refreshTokenService.createRefreshToken(TestData.member.id!!, null, null)
        val otherRefreshToken = refreshTokenService.createRefreshToken(TestData.member2.id!!, null, null)
        mockMvc.post("/api/auth/push/apns/register") {
            cookie(
                Cookie(CookieService.ACCESS_TOKEN_COOKIE, getJwt(TestData.member)),
                Cookie(CookieService.REFRESH_TOKEN_COOKIE, memberRefreshToken.token),
            )
            contentType = MediaType.APPLICATION_JSON
            content = """{"deviceToken":"device-token"}"""
        }.andExpect { status { isOk() } }

        mockMvc.post("/api/auth/push/apns/unregister") {
            cookie(
                Cookie(CookieService.ACCESS_TOKEN_COOKIE, getJwt(TestData.member2)),
                Cookie(CookieService.REFRESH_TOKEN_COOKIE, otherRefreshToken.token),
            )
            contentType = MediaType.APPLICATION_JSON
            content = """{"deviceToken":"device-token"}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.success") { value(false) }
        }
        assertThat(apnsInstallationRepository.findByDeviceToken("device-token")).isNotNull

        mockMvc.post("/api/auth/push/apns/unregister") {
            cookie(
                Cookie(CookieService.ACCESS_TOKEN_COOKIE, getJwt(TestData.member)),
                Cookie(CookieService.REFRESH_TOKEN_COOKIE, memberRefreshToken.token),
            )
            contentType = MediaType.APPLICATION_JSON
            content = """{"deviceToken":"device-token"}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.success") { value(true) }
        }
        assertThat(apnsInstallationRepository.findByDeviceToken("device-token")).isNull()
    }

    @Test
    fun `register requires authentication`() {
        mockMvc.post("/api/auth/push/apns/register") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"deviceToken":"device-token"}"""
        }.andExpect {
            status { isUnauthorized() }
            jsonPath("$.code") { value("auth.required") }
        }
    }

    @Test
    fun `register rejects blank token`() {
        val refreshToken = refreshTokenService.createRefreshToken(TestData.member.id!!, null, null)
        mockMvc.post("/api/auth/push/apns/register") {
            cookie(
                Cookie(CookieService.ACCESS_TOKEN_COOKIE, getJwt(TestData.member)),
                Cookie(CookieService.REFRESH_TOKEN_COOKIE, refreshToken.token),
            )
            contentType = MediaType.APPLICATION_JSON
            content = """{"deviceToken":" "}"""
        }.andExpect {
            status { isBadRequest() }
            jsonPath("$.code") { value("common.validation.failed") }
        }
    }

    @Test
    fun `register requires matching refresh session`() {
        mockMvc.post("/api/auth/push/apns/register") {
            cookie(Cookie(CookieService.ACCESS_TOKEN_COOKIE, getJwt(TestData.member)))
            contentType = MediaType.APPLICATION_JSON
            content = """{"deviceToken":"device-token"}"""
        }.andExpect {
            status { isUnauthorized() }
            jsonPath("$.code") { value("auth.refresh.invalid") }
        }
    }

    @Test
    fun `deleting refresh session cascades installation`() {
        val refreshToken = refreshTokenService.createRefreshToken(TestData.member.id!!, null, null)
        mockMvc.post("/api/auth/push/apns/register") {
            cookie(
                Cookie(CookieService.ACCESS_TOKEN_COOKIE, getJwt(TestData.member)),
                Cookie(CookieService.REFRESH_TOKEN_COOKIE, refreshToken.token),
            )
            contentType = MediaType.APPLICATION_JSON
            content = """{"deviceToken":"device-token"}"""
        }.andExpect { status { isOk() } }

        em.flush()
        em.clear()
        refreshTokenRepository.deleteById(refreshToken.id!!)
        refreshTokenRepository.flush()
        em.clear()

        assertThat(apnsInstallationRepository.findByDeviceToken("device-token")).isNull()
    }
}
