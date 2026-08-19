package com.tistory.shanepark.dutypark.inquiry.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.inquiry.domain.enums.InquiryStatus
import com.tistory.shanepark.dutypark.inquiry.repository.InquiryRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.requestFields
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.restdocs.request.RequestDocumentation.parameterWithName
import org.springframework.restdocs.request.RequestDocumentation.queryParameters
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDateTime

class InquiryControllerTest : RestDocsTest() {

    @Autowired
    lateinit var inquiryRepository: InquiryRepository

    private val baseTime: LocalDateTime = LocalDateTime.of(2026, 8, 18, 10, 0, 0)

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
                        fieldWithPath("email").description("회신 받을 이메일 (비회원 필수, 회원은 생략 - 최대 255자)").optional(),
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
    fun `inquiry with invalid authentication credentials is rejected instead of stored as guest`() {
        val json = """
            {
                "email": "guest@dutypark.o-r.kr",
                "content": "인증 실패 요청은 비회원 문의가 되어서는 안 됩니다."
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/inquiries")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .header(HttpHeaders.AUTHORIZATION, "Bearer invalid-access-token")
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.unauthorized"))

        assertThat(inquiryRepository.findAll()).isEmpty()
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
    fun `logged in member inquiry without email records the account email`() {
        val json = """
            {
                "content": "회신 주소를 묻지 않는 회원 문의입니다."
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
        assertThat(inquiry.email).isEqualTo(TestData.member.email)
    }

    @Test
    fun `member without an account email can send an inquiry without a reply address`() {
        val socialMember = memberRepository.save(Member(name = "social"))
        em.flush()
        em.clear()

        val json = """
            {
                "content": "소셜 로그인 계정이라 이메일이 없습니다."
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/inquiries")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(socialMember)
        )
            .andExpect(status().isCreated)

        val inquiry = inquiryRepository.findAll().first()
        assertThat(inquiry.member?.id).isEqualTo(socialMember.id)
        assertThat(inquiry.email).isNull()
    }

    @Test
    fun `guest inquiry without email is rejected`() {
        val json = """
            {
                "content": "비회원은 답변을 받을 곳이 이메일뿐입니다."
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

    @Test
    fun `member reads own inquiries in created date desc order`() {
        // created_date 는 JPA Auditing 이 채우므로 저장 순서가 곧 오래된 순이다.
        saveInquiry(member = null, subject = "비회원 문의", content = "비회원 문의 내용")
        saveInquiry(member = TestData.member2, subject = "다른 회원 문의", content = "다른 회원 문의 내용")
        saveInquiry(member = TestData.member, content = "답변 대기 문의")
        val answered = saveInquiry(
            member = TestData.member,
            subject = "답변 완료 문의",
            content = "언제 답변이 오나요?",
        )
        answered.writeAnswer("확인 후 처리했습니다.", TestData.admin.id!!, baseTime)
        em.flush()
        em.clear()

        val response = mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/inquiries/me")
                .param("page", "0")
                .param("size", "10")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalElements").value(2))
            .andExpect(jsonPath("$.content[0].id").value(answered.id.toString()))
            .andExpect(jsonPath("$.content[0].subject").value("답변 완료 문의"))
            .andExpect(jsonPath("$.content[0].status").value("OPEN"))
            .andExpect(jsonPath("$.content[0].answer").value("확인 후 처리했습니다."))
            .andExpect(jsonPath("$.content[0].answeredAt").exists())
            .andExpect(jsonPath("$.content[1].content").value("답변 대기 문의"))
            .andExpect(jsonPath("$.content[1].answer").doesNotExist())
            .andExpect(jsonPath("$.content[1].answeredAt").doesNotExist())
            .andDo(
                document(
                    "inquiry/my-list",
                    queryParameters(
                        parameterWithName("page").description("페이지 번호(0부터)"),
                        parameterWithName("size").description("페이지 크기"),
                    ),
                    responseFields(
                        fieldWithPath("content").description("내 문의 목록"),
                        fieldWithPath("content[].id").description("문의 ID"),
                        fieldWithPath("content[].email").description("회신 이메일"),
                        fieldWithPath("content[].subject").description("제목 (선택)").optional(),
                        fieldWithPath("content[].content").description("문의 내용"),
                        fieldWithPath("content[].status").description("처리 상태 (OPEN, CLOSED)"),
                        fieldWithPath("content[].createdAt").description("접수 일시"),
                        fieldWithPath("content[].answer").description("관리자 답변 (없으면 null)").optional(),
                        fieldWithPath("content[].answeredAt").description("답변 일시 (없으면 null)").optional(),
                        fieldWithPath("totalPages").description("전체 페이지 수"),
                        fieldWithPath("totalElements").description("전체 건수"),
                        fieldWithPath("first").description("첫 페이지 여부"),
                        fieldWithPath("last").description("마지막 페이지 여부"),
                        fieldWithPath("size").description("페이지 크기"),
                        fieldWithPath("number").description("현재 페이지 번호"),
                        fieldWithPath("numberOfElements").description("현재 페이지 요소 수"),
                        fieldWithPath("empty").description("비어 있는지 여부"),
                        fieldWithPath("pageable").description("페이지 정보"),
                        fieldWithPath("pageable.pageNumber").description("페이지 번호"),
                        fieldWithPath("pageable.pageSize").description("페이지 크기"),
                        fieldWithPath("pageable.sort").description("정렬 정보"),
                        fieldWithPath("pageable.sort.empty").description("정렬 조건 없음 여부"),
                        fieldWithPath("pageable.sort.sorted").description("정렬 여부"),
                        fieldWithPath("pageable.sort.unsorted").description("미정렬 여부"),
                        fieldWithPath("pageable.offset").description("오프셋"),
                        fieldWithPath("pageable.paged").description("페이징 여부"),
                        fieldWithPath("pageable.unpaged").description("비페이징 여부"),
                    )
                )
            )
            .andReturn().response.contentAsString

        assertThat(response).doesNotContain("adminMemo", "ipAddress", "closedBy", "closedAt", "answeredBy", "memberId")
    }

    @Test
    fun `my inquiry list requires login`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/inquiries/me")
                .accept(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `my inquiry list is paged`() {
        saveInquiry(member = TestData.member, content = "문의 1")
        saveInquiry(member = TestData.member, content = "문의 2")
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/inquiries/me")
                .param("page", "1")
                .param("size", "1")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalElements").value(2))
            .andExpect(jsonPath("$.totalPages").value(2))
            .andExpect(jsonPath("$.numberOfElements").value(1))
            .andExpect(jsonPath("$.content[0].content").value("문의 1"))
    }

    private fun saveInquiry(
        member: Member?,
        content: String,
        subject: String? = null,
    ): Inquiry {
        return inquiryRepository.save(
            Inquiry(
                member = member,
                email = "guest@dutypark.o-r.kr",
                subject = subject,
                content = content,
                ipAddress = "127.0.0.1",
            )
        )
    }
}
