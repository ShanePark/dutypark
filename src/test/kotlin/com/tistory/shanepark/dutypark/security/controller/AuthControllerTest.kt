package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.repository.LoginAttemptRepository
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*
import java.time.LocalDateTime

@AutoConfigureMockMvc
class AuthControllerTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var refreshTokenService: RefreshTokenService

    @Autowired
    lateinit var loginAttemptRepository: LoginAttemptRepository

    private val testPass = TestData.testPass

    @BeforeEach
    fun cleanup() {
        loginAttemptRepository.deleteAll()
    }

    @Test
    fun `login Failed`() {
        val loginDto = LoginDto(TestData.member.email, "wrongPass", false)
        val json = objectMapper.writeValueAsString(loginDto)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        ).andExpect(status().isUnauthorized)
    }

    @Test
    fun `login Success and return proper token via cookie`() {
        val email = TestData.member.email

        val loginDto = LoginDto(email, testPass, false)
        val json = objectMapper.writeValueAsString(loginDto)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.expiresIn").exists())
            .andExpect(jsonPath("$.tokenType").doesNotExist())
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))
            .andExpect(cookie().httpOnly("access_token", true))
            .andExpect(cookie().httpOnly("refresh_token", true))
    }

    @Test
    fun `refresh succeeds with valid refresh token cookie`() {
        val loginDto = LoginDto(TestData.member.email, testPass, false)
        val json = objectMapper.writeValueAsString(loginDto)

        val loginResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isOk)
            .andReturn()

        val refreshCookie = loginResult.response.getCookie("refresh_token") ?: error("refresh cookie missing")

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/refresh")
                .cookie(refreshCookie)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.expiresIn").exists())
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))
    }

    @Test
    fun `refresh returns invalid code when refresh token cookie is missing`() {
        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/refresh")
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.status").value(401))
            .andExpect(jsonPath("$.code").value("auth.refresh.invalid"))
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))
    }

    @Test
    fun `refresh returns expired code when refresh token is expired`() {
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "test-agent"
        )
        refreshToken.validUntil = LocalDateTime.now().minusMinutes(1)
        em.flush()
        em.clear()

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/refresh")
                .cookie(Cookie("refresh_token", refreshToken.token))
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.status").value(401))
            .andExpect(jsonPath("$.code").value("auth.refresh.expired"))
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))
    }

    @Test
    fun `logout succeeds with refresh token cookie even when access token is missing`() {
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "test-agent"
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/logout")
                .cookie(Cookie("refresh_token", refreshToken.token))
        )
            .andExpect(status().isNoContent)
            .andExpect(cookie().maxAge("access_token", 0))
            .andExpect(cookie().maxAge("refresh_token", 0))

        assertThat(refreshTokenService.findByToken(refreshToken.token)).isNull()
    }

    @Test
    fun `deleting current refresh token also clears local token cookies`() {
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "test-agent"
        )
        em.flush()
        em.clear()
        val accessToken = getJwt(memberRepository.findByEmail(TestData.member.email).orElseThrow())

        mockMvc.perform(
            MockMvcRequestBuilders.delete("/api/auth/refresh-tokens/{id}", refreshToken.id)
                .cookie(Cookie("refresh_token", refreshToken.token))
                .header(HttpHeaders.AUTHORIZATION, "Bearer $accessToken")
        )
            .andExpect(status().isNoContent)
            .andExpect(cookie().maxAge("access_token", 0))
            .andExpect(cookie().maxAge("refresh_token", 0))

        assertThat(refreshTokenService.findByToken(refreshToken.token)).isNull()
    }

    @Test
    fun `revoking another session immediately invalidates its access token`() {
        val loginBody = objectMapper.writeValueAsString(
            LoginDto(TestData.member.email, testPass, false)
        )
        val firstLogin = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginBody)
        ).andExpect(status().isOk).andReturn()
        val firstAccessToken = firstLogin.response.getCookie("access_token")?.value
            ?: error("first access token missing")
        val firstRefreshToken = firstLogin.response.getCookie("refresh_token")?.value
            ?: error("first refresh token missing")
        val firstSessionId = refreshTokenService.findByToken(firstRefreshToken)?.id
            ?: error("first refresh session missing")

        val secondLogin = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginBody)
        ).andExpect(status().isOk).andReturn()
        val secondAccessToken = secondLogin.response.getCookie("access_token")?.value
            ?: error("second access token missing")

        mockMvc.perform(
            MockMvcRequestBuilders.delete("/api/auth/refresh-tokens/{id}", firstSessionId)
                .header(HttpHeaders.AUTHORIZATION, "Bearer $secondAccessToken")
        ).andExpect(status().isNoContent)

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/refresh-tokens")
                .header(HttpHeaders.AUTHORIZATION, "Bearer $firstAccessToken")
        ).andExpect(status().isUnauthorized)
    }

    @Test
    fun `logout while impersonating invalidates original refresh token`() {
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)
        em.flush()
        em.clear()

        val loginDto = LoginDto(TestData.member.email, testPass, false)
        val loginJson = objectMapper.writeValueAsString(loginDto)

        val loginResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginJson)
        )
            .andExpect(status().isOk)
            .andReturn()

        val originalRefreshToken = loginResult.response.getCookie("refresh_token")
            ?: error("original refresh token missing")
        val managerAccessToken = loginResult.response.getCookie("access_token")?.value
            ?: error("manager access token missing")

        val impersonateResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $managerAccessToken")
                .cookie(originalRefreshToken)
        )
            .andExpect(status().isOk)
            .andReturn()

        val impersonatedAccessToken = impersonateResult.response.getCookie("access_token")?.value
            ?: error("impersonated access token missing")

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/logout")
                .header("Authorization", "Bearer $impersonatedAccessToken")
                .cookie(originalRefreshToken)
        )
            .andExpect(status().isNoContent)
            .andExpect(cookie().maxAge("access_token", 0))
            .andExpect(cookie().maxAge("refresh_token", 0))

        assertThat(refreshTokenService.findByToken(originalRefreshToken.value)).isNull()

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/refresh")
                .cookie(originalRefreshToken)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.refresh.invalid"))
    }

    @Test
    fun `without login session can't ask update duty`() {
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val dutyUpdateDto =
            DutyUpdateDto(
                year = 2023,
                month = 1,
                day = 1,
                dutyTypeId = TestData.dutyTypes[0].id,
                memberId = member.id!!
            )
        val json = objectMapper.writeValueAsString(dutyUpdateDto)

        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/change")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        ).andExpect(status().isUnauthorized)
    }

    @Test
    fun `different user can't request duty update`() {
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val dutyUpdateDto =
            DutyUpdateDto(
                year = 2023,
                month = 1,
                day = 1,
                dutyTypeId = TestData.dutyTypes[0].id,
                memberId = member.id!!
            )
        val json = objectMapper.writeValueAsString(dutyUpdateDto)
        val anotherMember = memberRepository.findByEmail(TestData.member2.email).orElseThrow()

        val accessToken = getJwt(anotherMember)

        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/change")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isUnauthorized)
    }

    @Test
    fun `with proper token, duty update success`() {
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val dutyUpdateDto =
            DutyUpdateDto(
                year = 2023,
                month = 1,
                day = 1,
                dutyTypeId = TestData.dutyTypes[0].id,
                memberId = member.id!!
            )
        val json = objectMapper.writeValueAsString(dutyUpdateDto)

        val accessToken = getJwt(member)

        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/change")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
    }


    @Test
    fun `if login Member, health point returns login info`() {
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val accessToken = getJwt(member)

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/status")
                .contentType(MediaType.APPLICATION_JSON)
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(member.id))
            .andExpect(jsonPath("$.email").value(member.email))
            .andExpect(jsonPath("$.name").value(member.name))
            .andExpect(jsonPath("$.sessionId").doesNotExist())
    }

    @Test
    fun `status falls back to access token cookie when bearer header is invalid`() {
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val accessToken = getJwt(member)

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/status")
                .contentType(MediaType.APPLICATION_JSON)
                .header(HttpHeaders.AUTHORIZATION, "Bearer garbage")
                .cookie(Cookie("access_token", accessToken))
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(member.id))
            .andExpect(jsonPath("$.email").value(member.email))
            .andExpect(jsonPath("$.name").value(member.name))
    }

    @Test
    fun `even if not login, health point doesn't throws error`() {
        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/status")
                .contentType(MediaType.APPLICATION_JSON)
        ).andExpect(status().isOk)
            .andExpect(content().string(""))
    }

    @Test
    fun `impersonate succeeds when manager has permission`() {
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)
        em.flush()
        em.clear()

        val accessToken = getJwt(manager)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.expiresIn").exists())
            .andExpect(cookie().exists("access_token"))
    }

    @Test
    fun `impersonate fails when manager has no permission`() {
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val notManaged = memberRepository.findByEmail(TestData.member2.email).orElseThrow()

        val accessToken = getJwt(manager)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${notManaged.id}")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isForbidden)
            .andExpect(jsonPath("$.code").exists())
    }

    @Test
    fun `impersonate fails without login`() {
        val targetId = TestData.member.id

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/$targetId")
        ).andExpect(status().isUnauthorized)
    }

    @Test
    fun `impersonate and status shows impersonated state`() {
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)
        em.flush()
        em.clear()

        val accessToken = getJwt(manager)

        val impersonateResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andReturn()

        val impersonatedToken = impersonateResult.response.getCookie("access_token")?.value

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/status")
                .header("Authorization", "Bearer $impersonatedToken")
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(managed.id))
            .andExpect(jsonPath("$.name").value(managed.name))
            .andExpect(jsonPath("$.isImpersonating").value(true))
            .andExpect(jsonPath("$.originalMemberId").value(manager.id))
    }

    @Test
    fun `restore succeeds when impersonating`() {
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)
        em.flush()
        em.clear()

        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = manager.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "test-agent",
        )
        val accessToken = getJwt(manager, requireNotNull(refreshToken.id))

        val impersonateResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
                .cookie(Cookie("refresh_token", refreshToken.token))
        ).andExpect(status().isOk)
            .andReturn()

        val impersonatedToken = impersonateResult.response.getCookie("access_token")?.value

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/restore")
                .header("Authorization", "Bearer $impersonatedToken")
                .cookie(Cookie("refresh_token", refreshToken.token))
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.expiresIn").exists())
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))
    }

    @Test
    fun `restore fails when not impersonating`() {
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val accessToken = getJwt(member)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/restore")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").exists())
    }

    @Test
    fun `restore failure message follows accept language`() {
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val accessToken = getJwt(member)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/restore")
                .header("Authorization", "Bearer $accessToken")
                .header(HttpHeaders.ACCEPT_LANGUAGE, "en")
        ).andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("auth.restore.notImpersonating"))
    }

    @Test
    fun `double impersonation is not allowed`() {
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)
        em.flush()
        em.clear()

        val accessToken = getJwt(manager)

        val impersonateResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andReturn()

        val impersonatedToken = impersonateResult.response.getCookie("access_token")?.value

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $impersonatedToken")
        ).andExpect(status().isForbidden)
            .andExpect(jsonPath("$.code").exists())
    }

    @Test
    fun `restore reuses existing refresh token from cookie`() {
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)

        val originalRefreshToken = refreshTokenService.createRefreshToken(
            memberId = manager.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "test-agent"
        )
        em.flush()
        em.clear()

        val accessToken = getJwt(manager, requireNotNull(originalRefreshToken.id))
        val tokenCountBefore = refreshTokenService.findRefreshTokens(manager.id!!, false).size

        val impersonateResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
                .cookie(Cookie("refresh_token", originalRefreshToken.token))
        ).andExpect(status().isOk)
            .andReturn()

        val impersonatedToken = impersonateResult.response.getCookie("access_token")?.value

        val restoreResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/restore")
                .header("Authorization", "Bearer $impersonatedToken")
                .cookie(Cookie("refresh_token", originalRefreshToken.token))
        ).andExpect(status().isOk)
            .andExpect(cookie().exists("refresh_token"))
            .andReturn()

        val returnedRefreshToken = restoreResult.response.getCookie("refresh_token")?.value
        assertThat(returnedRefreshToken).isEqualTo(originalRefreshToken.token)

        val tokenCountAfter = refreshTokenService.findRefreshTokens(manager.id!!, false).size
        assertThat(tokenCountAfter).isEqualTo(tokenCountBefore)
    }

    @Test
    fun `restore rejects missing refresh cookie without creating a new session`() {
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)
        em.flush()
        em.clear()

        val accessToken = getJwt(manager)
        val tokenCountBefore = refreshTokenService.findRefreshTokens(manager.id!!, false).size

        val impersonateResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andReturn()

        val impersonatedToken = impersonateResult.response.getCookie("access_token")?.value

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/restore")
                .header("Authorization", "Bearer $impersonatedToken")
        ).andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("auth.restore.sessionInvalid"))

        val tokenCountAfter = refreshTokenService.findRefreshTokens(manager.id!!, false).size
        assertThat(tokenCountAfter).isEqualTo(tokenCountBefore)
    }

    @Test
    fun `restore rejects refresh cookie belonging to a different session`() {
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)

        val differentMemberToken = refreshTokenService.createRefreshToken(
            memberId = managed.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "test-agent"
        )
        em.flush()
        em.clear()

        val accessToken = getJwt(manager)
        val tokenCountBefore = refreshTokenService.findRefreshTokens(manager.id!!, false).size

        val impersonateResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andReturn()

        val impersonatedToken = impersonateResult.response.getCookie("access_token")?.value

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/restore")
                .header("Authorization", "Bearer $impersonatedToken")
                .cookie(Cookie("refresh_token", differentMemberToken.token))
        ).andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("auth.restore.sessionInvalid"))

        val tokenCountAfter = refreshTokenService.findRefreshTokens(manager.id!!, false).size
        assertThat(tokenCountAfter).isEqualTo(tokenCountBefore)
    }

}
