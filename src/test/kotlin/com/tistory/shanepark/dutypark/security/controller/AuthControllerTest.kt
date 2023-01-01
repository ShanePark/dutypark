package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.member.domain.entity.Department
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.repository.LoginSessionRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@SpringBootTest
@AutoConfigureMockMvc
class AuthControllerTest {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var memberRepository: MemberRepository

    @Autowired
    lateinit var loginSessionRepository: LoginSessionRepository

    private val objectMapper = com.fasterxml.jackson.databind.ObjectMapper()

    @Autowired
    lateinit var passwordEncoder: org.springframework.security.crypto.password.PasswordEncoder

    @BeforeEach
    fun clean() {
        memberRepository.deleteAll()
        loginSessionRepository.deleteAll()
        memberRepository.save(
            Member(
                email = "test@duty.park",
                department = Department("devs"),
                name = "test",
                password = passwordEncoder.encode("1234")
            )
        )
    }

    @Test
    fun `login Success`() {
        val loginDto = LoginDto("test@duty.park", "1234")
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
        val password = "1234"

        val loginDto = LoginDto(email, password)
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

}
