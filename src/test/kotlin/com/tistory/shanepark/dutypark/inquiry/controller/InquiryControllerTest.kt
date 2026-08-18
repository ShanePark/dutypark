package com.tistory.shanepark.dutypark.inquiry.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.inquiry.domain.enums.InquiryStatus
import com.tistory.shanepark.dutypark.inquiry.repository.InquiryRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.requestFields
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class InquiryControllerTest : RestDocsTest() {

    @Autowired
    lateinit var inquiryRepository: InquiryRepository

    @Test
    fun `guest creates inquiry`() {
        val json = """
            {
                "email": "guest@dutypark.o-r.kr",
                "subject": "일정이 보이지 않습니다",
                "content": "친구 달력이 열리지 않습니다. 확인 부탁드립니다."
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/inquiries")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isCreated)
            .andExpect(jsonPath("$.id").exists())
            .andDo(
                document(
                    "inquiry/create",
                    requestFields(
                        fieldWithPath("email").description("회신 받을 이메일 (필수, 최대 255자)"),
                        fieldWithPath("subject").description("제목 (선택, 최대 100자)").optional(),
                        fieldWithPath("content").description("문의 내용 (필수, 최대 2000자)"),
                    ),
                    responseFields(
                        fieldWithPath("id").description("생성된 문의 ID"),
                    )
                )
            )

        val inquiries = inquiryRepository.findAll()
        assertThat(inquiries).hasSize(1)
        val inquiry = inquiries.first()
        assertThat(inquiry.member).isNull()
        assertThat(inquiry.email).isEqualTo("guest@dutypark.o-r.kr")
        assertThat(inquiry.subject).isEqualTo("일정이 보이지 않습니다")
        assertThat(inquiry.status).isEqualTo(InquiryStatus.OPEN)
        assertThat(inquiry.ipAddress).isEqualTo("127.0.0.1")
        assertThat(inquiry.closedAt).isNull()
        assertThat(inquiry.closedBy).isNull()
    }

    @Test
    fun `logged in member inquiry records member id and keeps requested email`() {
        val json = """
            {
                "email": "another@dutypark.o-r.kr",
                "subject": null,
                "content": "계정 정지 이의제기 합니다."
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/inquiries")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isCreated)

        val inquiry = inquiryRepository.findAll().first()
        assertThat(inquiry.member?.id).isEqualTo(TestData.member.id)
        assertThat(inquiry.email).isEqualTo("another@dutypark.o-r.kr")
        assertThat(inquiry.subject).isNull()
    }

    @Test
    fun `invalid email is rejected`() {
        val json = """
            {
                "email": "not-an-email",
                "content": "내용"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/inquiries")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isBadRequest)

        assertThat(inquiryRepository.findAll()).isEmpty()
    }

    @Test
    fun `blank email is rejected`() {
        val json = """
            {
                "email": " ",
                "content": "내용"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/inquiries")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `blank content is rejected`() {
        val json = """
            {
                "email": "guest@dutypark.o-r.kr",
                "content": "   "
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/inquiries")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `too long content is rejected`() {
        val json = """
            {
                "email": "guest@dutypark.o-r.kr",
                "content": "${"가".repeat(2001)}"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/inquiries")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isBadRequest)

        assertThat(inquiryRepository.findAll()).isEmpty()
    }

    @Test
    fun `too long subject is rejected`() {
        val json = """
            {
                "email": "guest@dutypark.o-r.kr",
                "subject": "${"제".repeat(101)}",
                "content": "내용"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/inquiries")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `sixth inquiry from the same ip within an hour is rate limited`() {
        repeat(5) {
            inquiryRepository.save(
                Inquiry(
                    member = null,
                    email = "guest@dutypark.o-r.kr",
                    subject = null,
                    content = "문의 $it",
                    ipAddress = "127.0.0.1",
                )
            )
        }
        em.flush()

        val json = """
            {
                "email": "guest@dutypark.o-r.kr",
                "content": "여섯 번째 문의"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/inquiries")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isTooManyRequests)
            .andExpect(jsonPath("$.code").value("inquiry.rateLimit.exceeded"))

        assertThat(inquiryRepository.findAll()).hasSize(5)
    }

    @Test
    fun `inquiries from another ip are not rate limited`() {
        repeat(5) {
            inquiryRepository.save(
                Inquiry(
                    member = null,
                    email = "guest@dutypark.o-r.kr",
                    subject = null,
                    content = "문의 $it",
                    ipAddress = "10.0.0.1",
                )
            )
        }
        em.flush()

        val json = """
            {
                "email": "guest@dutypark.o-r.kr",
                "content": "다른 IP 문의"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/inquiries")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isCreated)
    }
}
