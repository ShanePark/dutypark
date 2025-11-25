package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
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

    private val log = logger()
    private val testPass = TestData.testPass

    @Test
    fun `login Success`() {
        val loginDto = LoginDto(TestData.member.email, testPass, false)
        val json = objectMapper.writeValueAsString(loginDto)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.accessToken").exists())
            .andExpect(jsonPath("$.refreshToken").exists())
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
    fun `login Success and return proper token`() {
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
            .andExpect(jsonPath("$.accessToken").exists())
            .andExpect(jsonPath("$.refreshToken").exists())
            .andExpect(jsonPath("$.tokenType").value("Bearer"))
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

}
