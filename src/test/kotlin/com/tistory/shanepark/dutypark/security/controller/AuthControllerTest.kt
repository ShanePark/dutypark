package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.repository.LoginAttemptRepository
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*

@AutoConfigureMockMvc
class AuthControllerTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var refreshTokenService: RefreshTokenService

    @Autowired
    lateinit var loginAttemptRepository: LoginAttemptRepository

    private val log = logger()
    private val testPass = TestData.testPass

    @BeforeEach
    fun cleanup() {
        loginAttemptRepository.deleteAll()
    }

    @Test
    fun `login Success`() {
        val loginDto = LoginDto(TestData.member.email, testPass, false)
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
            .andDo(MockMvcResultHandlers.print())
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
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `login Success and return proper token via cookie`() {
        // Given
        val email = TestData.member.email

        val loginDto = LoginDto(email, testPass, false)
        val json = objectMapper.writeValueAsString(loginDto)

        // When
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
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `without login session can't ask update duty`() {
        // Given
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

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/change")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        ).andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `different user can't request duty update`() {
        // Given
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
        log.info("accessToken: $accessToken")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/change")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `with proper token, duty update success`() {
        // Given
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
        log.info("accessToken: $accessToken")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/change")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
    }


    @Test
    fun `if login Member, health point returns login info`() {
        // Given
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val accessToken = getJwt(member)

        log.info("accessToken: $accessToken")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/status")
                .contentType(MediaType.APPLICATION_JSON)
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(member.id))
            .andExpect(jsonPath("$.email").value(member.email))
            .andExpect(jsonPath("$.name").value(member.name))
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `even if not login, health point doesn't throws error`() {
        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/status")
                .contentType(MediaType.APPLICATION_JSON)
        ).andExpect(status().isOk)
            .andExpect(content().string(""))
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `impersonate succeeds when manager has permission`() {
        // Given
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)
        em.flush()
        em.clear()

        val accessToken = getJwt(manager)

        // When & Then
        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.expiresIn").exists())
            .andExpect(cookie().exists("access_token"))
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `impersonate fails when manager has no permission`() {
        // Given
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val notManaged = memberRepository.findByEmail(TestData.member2.email).orElseThrow()

        val accessToken = getJwt(manager)

        // When & Then
        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${notManaged.id}")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isForbidden)
            .andExpect(jsonPath("$.error").exists())
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `impersonate fails without login`() {
        // Given
        val targetId = TestData.member.id

        // When & Then
        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/$targetId")
        ).andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `impersonate and status shows impersonated state`() {
        // Given
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)
        em.flush()
        em.clear()

        val accessToken = getJwt(manager)

        // When - Impersonate
        val impersonateResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andReturn()

        val impersonatedToken = impersonateResult.response.getCookie("access_token")?.value

        // Then - Check status shows impersonated state
        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/status")
                .header("Authorization", "Bearer $impersonatedToken")
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(managed.id))
            .andExpect(jsonPath("$.name").value(managed.name))
            .andExpect(jsonPath("$.isImpersonating").value(true))
            .andExpect(jsonPath("$.originalMemberId").value(manager.id))
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `restore succeeds when impersonating`() {
        // Given
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)
        em.flush()
        em.clear()

        val accessToken = getJwt(manager)

        // Impersonate first
        val impersonateResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andReturn()

        val impersonatedToken = impersonateResult.response.getCookie("access_token")?.value

        // When - Restore
        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/restore")
                .header("Authorization", "Bearer $impersonatedToken")
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.expiresIn").exists())
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `restore fails when not impersonating`() {
        // Given
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val accessToken = getJwt(member)

        // When & Then
        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/restore")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.error").exists())
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `double impersonation is not allowed`() {
        // Given
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)
        em.flush()
        em.clear()

        val accessToken = getJwt(manager)

        // First impersonation
        val impersonateResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andReturn()

        val impersonatedToken = impersonateResult.response.getCookie("access_token")?.value

        // When - Try second impersonation
        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $impersonatedToken")
        ).andExpect(status().isForbidden)
            .andExpect(jsonPath("$.error").exists())
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `restore reuses existing refresh token from cookie`() {
        // Given
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

        val accessToken = getJwt(manager)
        val tokenCountBefore = refreshTokenService.findRefreshTokens(manager.id!!, false).size

        // Impersonate
        val impersonateResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
                .cookie(Cookie("refresh_token", originalRefreshToken.token))
        ).andExpect(status().isOk)
            .andReturn()

        val impersonatedToken = impersonateResult.response.getCookie("access_token")?.value

        // When - Restore with existing refresh token in cookie
        val restoreResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/restore")
                .header("Authorization", "Bearer $impersonatedToken")
                .cookie(Cookie("refresh_token", originalRefreshToken.token))
        ).andExpect(status().isOk)
            .andExpect(cookie().exists("refresh_token"))
            .andReturn()

        // Then - Should reuse the same refresh token, not create a new one
        val returnedRefreshToken = restoreResult.response.getCookie("refresh_token")?.value
        assertThat(returnedRefreshToken).isEqualTo(originalRefreshToken.token)

        val tokenCountAfter = refreshTokenService.findRefreshTokens(manager.id!!, false).size
        assertThat(tokenCountAfter).isEqualTo(tokenCountBefore)
    }

    @Test
    fun `restore creates new refresh token when cookie token is missing`() {
        // Given
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)
        em.flush()
        em.clear()

        val accessToken = getJwt(manager)
        val tokenCountBefore = refreshTokenService.findRefreshTokens(manager.id!!, false).size

        // Impersonate
        val impersonateResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andReturn()

        val impersonatedToken = impersonateResult.response.getCookie("access_token")?.value

        // When - Restore without refresh token cookie
        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/restore")
                .header("Authorization", "Bearer $impersonatedToken")
        ).andExpect(status().isOk)
            .andExpect(cookie().exists("refresh_token"))
            .andDo(MockMvcResultHandlers.print())

        // Then - Should create a new refresh token
        val tokenCountAfter = refreshTokenService.findRefreshTokens(manager.id!!, false).size
        assertThat(tokenCountAfter).isEqualTo(tokenCountBefore + 1)
    }

    @Test
    fun `restore creates new refresh token when cookie token belongs to different member`() {
        // Given
        val manager = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val managed = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        makeManagerRelation(manager, managed)

        // Create refresh token for different member (managed)
        val differentMemberToken = refreshTokenService.createRefreshToken(
            memberId = managed.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "test-agent"
        )
        em.flush()
        em.clear()

        val accessToken = getJwt(manager)
        val tokenCountBefore = refreshTokenService.findRefreshTokens(manager.id!!, false).size

        // Impersonate
        val impersonateResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/impersonate/${managed.id}")
                .header("Authorization", "Bearer $accessToken")
        ).andExpect(status().isOk)
            .andReturn()

        val impersonatedToken = impersonateResult.response.getCookie("access_token")?.value

        // When - Restore with refresh token belonging to different member
        val restoreResult = mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/restore")
                .header("Authorization", "Bearer $impersonatedToken")
                .cookie(Cookie("refresh_token", differentMemberToken.token))
        ).andExpect(status().isOk)
            .andExpect(cookie().exists("refresh_token"))
            .andReturn()

        // Then - Should create a new refresh token (not reuse the wrong one)
        val returnedRefreshToken = restoreResult.response.getCookie("refresh_token")?.value
        assertThat(returnedRefreshToken).isNotEqualTo(differentMemberToken.token)

        val tokenCountAfter = refreshTokenService.findRefreshTokens(manager.id!!, false).size
        assertThat(tokenCountAfter).isEqualTo(tokenCountBefore + 1)
    }

}
