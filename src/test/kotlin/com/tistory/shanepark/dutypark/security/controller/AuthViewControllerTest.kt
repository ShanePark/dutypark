package com.tistory.shanepark.dutypark.security.controller

import com.fasterxml.jackson.databind.ObjectMapper
import com.tistory.shanepark.dutypark.TestData
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.MemoDto
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import jakarta.servlet.http.Cookie
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*
import org.springframework.transaction.annotation.Transactional

@SpringBootTest
@Transactional
@AutoConfigureMockMvc
class AuthViewControllerTest {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var memberRepository: MemberRepository

    @Autowired
    lateinit var objectMapper: ObjectMapper

    private val log: org.slf4j.Logger = org.slf4j.LoggerFactory.getLogger(AuthViewControllerTest::class.java)

    @Test
    fun `login Success`() {
        val loginDto = LoginDto(TestData.member.email, TestData.member.password)
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

        val loginDto = LoginDto(email, TestData.member.password)
        val json = objectMapper.writeValueAsString(loginDto)

        // When
        mockMvc.perform(
            MockMvcRequestBuilders.post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        ).andExpect(status().isOk)
            .andExpect(cookie().exists("SESSION"))
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
            MockMvcRequestBuilders.put("/api/duty/update")
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

        val loginDto = LoginDto(anotherMember.email, TestData.member.password)
        val loginJson = objectMapper.writeValueAsString(loginDto)

        // save login session token on variable
        val accessToken = mockMvc.perform(
            MockMvcRequestBuilders.post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginJson)
        ).andReturn().response.getCookie("SESSION")?.let { it.value }

        log.info("accessToken: $accessToken")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/update")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .cookie(Cookie("SESSION", accessToken))

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

        val loginDto = LoginDto(email = TestData.member.email, password = TestData.member.password)
        val loginJson = objectMapper.writeValueAsString(loginDto)

        // save login session token on variable
        val accessToken = mockMvc.perform(
            MockMvcRequestBuilders.post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginJson)
        ).andReturn().response.getCookie("SESSION")?.let { it.value }

        log.info("accessToken: $accessToken")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/update")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .cookie(Cookie("SESSION", accessToken))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `without login session can't update memo`() {
        // Given
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val momoDto =
            MemoDto(year = 2023, month = 1, day = 1, memberId = member.id!!, memo = "memo")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/memo")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(momoDto))
        ).andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `different user can't request memo update`() {
        // Given
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val momoDto =
            MemoDto(year = 2023, month = 1, day = 1, memberId = member.id!!, memo = "memo")

        val anotherMember = memberRepository.findByEmail(TestData.member2.email).orElseThrow()
        val loginDto = LoginDto(anotherMember.email, TestData.member.password)

        // save login session token on variable
        val accessToken = mockMvc.perform(
            MockMvcRequestBuilders.post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(loginDto))
        ).andReturn().response.getCookie("SESSION")?.let { it.value }

        log.info("accessToken: $accessToken")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/memo")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(momoDto))
                .cookie(Cookie("SESSION", accessToken))
        ).andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `with proper token, memo update success`() {
        // Given
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val momoDto =
            MemoDto(year = 2023, month = 1, day = 1, memberId = member.id!!, memo = "memo")
        val json = objectMapper.writeValueAsString(momoDto)

        val loginDto = LoginDto(email = TestData.member.email, password = TestData.member.password)

        // save login session token on variable
        val accessToken = mockMvc.perform(
            MockMvcRequestBuilders.post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(loginDto))
        ).andReturn().response.getCookie("SESSION")?.let { it.value }

        log.info("accessToken: $accessToken")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/memo")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .cookie(Cookie("SESSION", accessToken))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `if login Member, health point returns login info`() {
        // Given
        val member = memberRepository.findByEmail(TestData.member.email).orElseThrow()
        val loginDto = LoginDto(email = TestData.member.email, password = TestData.member.password)

        // save login session token on variable
        val accessToken = mockMvc.perform(
            MockMvcRequestBuilders.post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(loginDto))
        ).andReturn().response.getCookie("SESSION")?.let { it.value }

        log.info("accessToken: $accessToken")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.get("/status")
                .contentType(MediaType.APPLICATION_JSON)
                .cookie(Cookie("SESSION", accessToken))
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
