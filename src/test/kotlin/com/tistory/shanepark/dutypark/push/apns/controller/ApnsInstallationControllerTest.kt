package com.tistory.shanepark.dutypark.push.apns.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.push.apns.domain.repository.ApnsInstallationRepository
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

    @Test
    fun `register stores installation with access token cookie`() {
        mockMvc.post("/api/auth/push/apns/register") {
            cookie(Cookie(CookieService.ACCESS_TOKEN_COOKIE, getJwt(TestData.member)))
            contentType = MediaType.APPLICATION_JSON
            content = """{"deviceToken":"device-token","sandbox":true}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.success") { value(true) }
        }

        val installation = apnsInstallationRepository.findByDeviceToken("device-token")
        assertThat(installation?.member?.id).isEqualTo(TestData.member.id)
        assertThat(installation?.sandbox).isTrue()
    }

    @Test
    fun `unregister removes only current member installation`() {
        mockMvc.post("/api/auth/push/apns/register") {
            cookie(Cookie(CookieService.ACCESS_TOKEN_COOKIE, getJwt(TestData.member)))
            contentType = MediaType.APPLICATION_JSON
            content = """{"deviceToken":"device-token"}"""
        }.andExpect { status { isOk() } }

        mockMvc.post("/api/auth/push/apns/unregister") {
            cookie(Cookie(CookieService.ACCESS_TOKEN_COOKIE, getJwt(TestData.member2)))
            contentType = MediaType.APPLICATION_JSON
            content = """{"deviceToken":"device-token"}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.success") { value(false) }
        }
        assertThat(apnsInstallationRepository.findByDeviceToken("device-token")).isNotNull

        mockMvc.post("/api/auth/push/apns/unregister") {
            cookie(Cookie(CookieService.ACCESS_TOKEN_COOKIE, getJwt(TestData.member)))
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
        mockMvc.post("/api/auth/push/apns/register") {
            cookie(Cookie(CookieService.ACCESS_TOKEN_COOKIE, getJwt(TestData.member)))
            contentType = MediaType.APPLICATION_JSON
            content = """{"deviceToken":" "}"""
        }.andExpect {
            status { isBadRequest() }
            jsonPath("$.code") { value("common.validation.failed") }
        }
    }
}
