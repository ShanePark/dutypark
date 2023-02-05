package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.MemoDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.enums.Color
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Department
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import jakarta.servlet.http.Cookie
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.TestInstance
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*

@SpringBootTest
@AutoConfigureMockMvc
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class AuthViewControllerTest {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var memberRepository: MemberRepository

    @Autowired
    lateinit var dutyTypeRepository: DutyTypeRepository

    @Autowired
    lateinit var departmentRepository: DepartmentRepository

    @Autowired
    lateinit var passwordEncoder: org.springframework.security.crypto.password.PasswordEncoder

    private val objectMapper = com.fasterxml.jackson.databind.ObjectMapper()
    private val log: org.slf4j.Logger = org.slf4j.LoggerFactory.getLogger(AuthViewControllerTest::class.java)

    var dutyTypeId = 0L
    val memberEmail = "test@duty.park"
    val anotherMemberEmail = "diff@duty.park"
    val memberPassword = "1234"

    @BeforeAll
    fun beforeAll() {
        val dept1 = Department("devs")
        val dept2 = Department("others")
        departmentRepository.save(dept1)
        departmentRepository.save(dept2)

        val member = memberRepository.save(
            Member(
                email = memberEmail,
                department = dept1,
                name = "test",
                password = passwordEncoder.encode(memberPassword)
            )
        )
        memberRepository.save(
            Member(
                email = anotherMemberEmail,
                department = dept2,
                name = "diff",
                password = passwordEncoder.encode(memberPassword)
            )
        )

        val department = member.department
        val dutyTypes = listOf(
            DutyType("오전", 0, department, Color.BLUE),
            DutyType("오후", 1, department, Color.RED),
            DutyType("야간", 2, department, Color.GREEN),
        )
        dutyTypeRepository.saveAll(dutyTypes)

        dutyTypeId = dutyTypes[0].id!!
    }

    @Test
    fun `login Success`() {
        val loginDto = LoginDto("test@duty.park", memberPassword)
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
        val loginDto = LoginDto("test@duty.park", "wrongPass")
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
        val email = "test@duty.park"

        val loginDto = LoginDto(email, memberPassword)
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
        val anotherMember = memberRepository.findByEmail(anotherMemberEmail).orElseThrow()

        val loginDto = LoginDto(anotherMember.email, memberPassword)
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
        val member = memberRepository.findByEmail(memberEmail).orElseThrow()
        val dutyUpdateDto =
            DutyUpdateDto(year = 2023, month = 1, day = 1, dutyTypeId = dutyTypeId, memberId = member.id!!)
        val json = objectMapper.writeValueAsString(dutyUpdateDto)

        val loginDto = LoginDto(email = memberEmail, password = memberPassword)
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
        val member = memberRepository.findByEmail(memberEmail).orElseThrow()
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
        val member = memberRepository.findByEmail(memberEmail).orElseThrow()
        val momoDto =
            MemoDto(year = 2023, month = 1, day = 1, memberId = member.id!!, memo = "memo")

        val anotherMember = memberRepository.findByEmail(anotherMemberEmail).orElseThrow()
        val loginDto = LoginDto(anotherMember.email, memberPassword)

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
        val member = memberRepository.findByEmail(memberEmail).orElseThrow()
        val momoDto =
            MemoDto(year = 2023, month = 1, day = 1, memberId = member.id!!, memo = "memo")
        val json = objectMapper.writeValueAsString(momoDto)

        val loginDto = LoginDto(email = memberEmail, password = memberPassword)

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
        val member = memberRepository.findByEmail(memberEmail).orElseThrow()
        val loginDto = LoginDto(email = memberEmail, password = memberPassword)

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
