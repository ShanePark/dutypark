package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.enums.Color
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Department
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginSessionResponse
import com.tistory.shanepark.dutypark.security.repository.LoginSessionRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.TestInstance
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.nio.charset.Charset

@SpringBootTest
@AutoConfigureMockMvc
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class AuthControllerTest {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var memberRepository: MemberRepository

    @Autowired
    lateinit var loginSessionRepository: LoginSessionRepository

    @Autowired
    lateinit var departmentRepository: DepartmentRepository

    @Autowired
    lateinit var dutyTypeRepository: DutyTypeRepository

    @Autowired
    lateinit var passwordEncoder: org.springframework.security.crypto.password.PasswordEncoder

    private val objectMapper = com.fasterxml.jackson.databind.ObjectMapper()
    private val log: org.slf4j.Logger = org.slf4j.LoggerFactory.getLogger(AuthControllerTest::class.java)

    var depId = 0L
    var dutyTypeId = 0L
    val memberEmail = "test@duty.park"
    val memberPassword = "1234"

    @BeforeAll
    fun beforeAll() {
        val member = memberRepository.save(
            Member(
                email = memberEmail,
                department = Department("devs"),
                name = "test",
                password = passwordEncoder.encode(memberPassword)
            )
        )
        val department = member.department
        departmentRepository.save(department)
        val dutyTypes = listOf(
            DutyType("오전", 0, department, Color.BLUE),
            DutyType("오후", 1, department, Color.RED),
            DutyType("야간", 2, department, Color.GREEN),
        )
        dutyTypeRepository.saveAll(dutyTypes)

        depId = department.id!!
        dutyTypeId = dutyTypes[0].id!!


    }

    @BeforeEach
    fun clean() {
        loginSessionRepository.deleteAll()
    }

    @Test
    fun `login Success`() {
        val loginDto = LoginDto("test@duty.park", memberPassword)
        val json = objectMapper.writeValueAsString(loginDto)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `login Failed`() {
        val loginDto = LoginDto("test@duty.park", "wrongPass")
        val json = objectMapper.writeValueAsString(loginDto)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        ).andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `login Success and make a session`() {
        // Given
        val email = "test@duty.park"

        val loginDto = LoginDto(email, memberPassword)
        val json = objectMapper.writeValueAsString(loginDto)

        // When
        mockMvc.perform(
            MockMvcRequestBuilders.post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.accessToken").isNotEmpty)
            .andDo(MockMvcResultHandlers.print())

        val member = memberRepository.findByEmail(email).orElseThrow()

        // Then
        assertThat(loginSessionRepository.findByMember(member)).hasSize(1)
        assertThat(loginSessionRepository.count()).isEqualTo(1)
    }

    @Test
    fun `without login session can't ask update duty`() {
        // Given
        val member = memberRepository.findByEmail(memberEmail).orElseThrow()
        val dutyUpdateDto =
            DutyUpdateDto(year = 2023, month = 1, day = 1, dutyTypeId = dutyTypeId, memberId = member.id!!)
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
        val member = memberRepository.findByEmail(memberEmail).orElseThrow()
        val dutyUpdateDto =
            DutyUpdateDto(year = 2023, month = 1, day = 1, dutyTypeId = dutyTypeId, memberId = member.id!!)
        val json = objectMapper.writeValueAsString(dutyUpdateDto)

        val anotherMember = memberRepository.save(
            Member(
                email = "diff@duty.park",
                department = Department("others"),
                name = "diff",
                password = passwordEncoder.encode(memberPassword)
            )
        )
        val loginDto = LoginDto(anotherMember.email, memberPassword)
        val loginJson = objectMapper.writeValueAsString(loginDto)

        // save login session token on variable
        val accessToken = mockMvc.perform(
            MockMvcRequestBuilders.post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginJson)
        ).andReturn().response.getContentAsString(Charset.defaultCharset()).let {
            objectMapper.readValue(it, LoginSessionResponse::class.java).accessToken
        }

        log.info("accessToken: $accessToken")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/update")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .header("Authorization", accessToken)
        ).andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `with proper token, duty update success`() {
        // Given
        val member = memberRepository.findByEmail(memberEmail).orElseThrow()
        val dutyUpdateDto =
            DutyUpdateDto(year = 2023, month = 1, day = 1, dutyTypeId = dutyTypeId, memberId = member.id!!)
        val json = objectMapper.writeValueAsString(dutyUpdateDto)

        val loginDto = LoginDto(email = memberEmail, password = memberPassword)
        val loginJson = objectMapper.writeValueAsString(loginDto)

        // save login session token on variable
        val accessToken = mockMvc.perform(
            MockMvcRequestBuilders.post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginJson)
        ).andReturn().response.getContentAsString(Charset.defaultCharset()).let {
            objectMapper.readValue(it, LoginSessionResponse::class.java).accessToken
        }

        log.info("accessToken: $accessToken")

        // Therefore
        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/duty/update")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .header("Authorization", accessToken)
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
    }

}