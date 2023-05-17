package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import jakarta.servlet.http.Cookie
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*

@AutoConfigureMockMvc
class AuthViewControllerTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var jwtConfig: JwtConfig

    private val log: org.slf4j.Logger = org.slf4j.LoggerFactory.getLogger(AuthViewControllerTest::class.java)
    private val testPass = TestData.testPass

    @Test
    fun `login Success`() {
        val loginDto = LoginDto(TestData.member.email, testPass)
        val json = objectMapper.writeValueAsString(loginDto)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `login Failed`() {
        val loginDto = LoginDto(TestData.member.email, "wrongPass")
        val json = objectMapper.writeValueAsString(loginDto)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        ).andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `login Success and return proper token`() {
        // Given
        val email = TestData.member.email

        val loginDto = LoginDto(email, testPass)
        val json = objectMapper.writeValueAsString(loginDto)

        // When
        mockMvc.perform(
            MockMvcRequestBuilders.post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        ).andExpect(status().isOk)
            .andExpect(cookie().exists(jwtConfig.cookieName))
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

        val loginDto = LoginDto(anotherMember.email, testPass)
        val loginJson = objectMapper.writeValueAsString(loginDto)

        // save login session token on variable
        val accessToken = mockMvc.perform(
            MockMvcRequestBuilders.post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginJson)
        ).andReturn().response.getCookie(jwtConfig.cookieName)?.let { it.value }

        log.info("accessToken: $accessToken")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/change")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .cookie(Cookie(jwtConfig.cookieName, accessToken))

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

        val loginDto = LoginDto(email = TestData.member.email, password = testPass)
        val loginJson = objectMapper.writeValueAsString(loginDto)

        // save login session token on variable
        val accessToken = mockMvc.perform(
            MockMvcRequestBuilders.post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginJson)
        ).andReturn().response.getCookie(jwtConfig.cookieName)?.let { it.value }

        log.info("accessToken: $accessToken")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/change")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .cookie(Cookie(jwtConfig.cookieName, accessToken))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
    }


    @Test
    fun `if login Member, health point returns login info`() {
        // Given
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val loginDto = LoginDto(email = TestData.member.email, password = testPass)

        // save login session token on variable
        val accessToken = mockMvc.perform(
            MockMvcRequestBuilders.post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(loginDto))
        ).andReturn().response.getCookie(jwtConfig.cookieName)?.let { it.value }

        log.info("accessToken: $accessToken")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.get("/status")
                .contentType(MediaType.APPLICATION_JSON)
                .cookie(Cookie(jwtConfig.cookieName, accessToken))
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
            MockMvcRequestBuilders.get("/status")
                .contentType(MediaType.APPLICATION_JSON)
        ).andExpect(status().isOk)
            .andExpect(content().string(""))
            .andDo(MockMvcResultHandlers.print())
    }

}
