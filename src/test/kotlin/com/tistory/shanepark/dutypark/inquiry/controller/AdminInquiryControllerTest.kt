package com.tistory.shanepark.dutypark.inquiry.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.inquiry.domain.enums.InquiryStatus
import com.tistory.shanepark.dutypark.inquiry.repository.InquiryRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.requestFields
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.restdocs.request.RequestDocumentation.parameterWithName
import org.springframework.restdocs.request.RequestDocumentation.pathParameters
import org.springframework.restdocs.request.RequestDocumentation.queryParameters
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDateTime

class AdminInquiryControllerTest : RestDocsTest() {

    @Autowired
    lateinit var inquiryRepository: InquiryRepository

    private val baseTime: LocalDateTime = LocalDateTime.of(2026, 8, 18, 10, 0, 0)

    @Test
    fun `admin sees every inquiry in created date desc order`() {
        saveInquiry(content = "가장 오래된 문의", createdDate = baseTime.minusHours(2))
        saveInquiry(content = "중간 문의", createdDate = baseTime.minusHours(1), status = InquiryStatus.CLOSED)
        saveInquiry(content = "가장 최근 문의", createdDate = baseTime, member = TestData.member)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/admin/api/inquiries")
                .param("page", "0")
                .param("size", "10")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalElements").value(3))
            .andExpect(jsonPath("$.content[0].content").value("가장 최근 문의"))
            .andExpect(jsonPath("$.content[0].memberId").value(TestData.member.id))
            .andExpect(jsonPath("$.content[0].memberName").value(TestData.member.name))
            .andExpect(jsonPath("$.content[2].content").value("가장 오래된 문의"))
            .andExpect(jsonPath("$.content[2].memberId").doesNotExist())
            .andDo(
                document(
                    "admin/inquiries-list",
                    queryParameters(
                        parameterWithName("page").description("페이지 번호(0부터)"),
                        parameterWithName("size").description("페이지 크기"),
                    ),
                    responseFields(
                        fieldWithPath("content").description("문의 목록"),
                        fieldWithPath("content[].id").description("문의 ID"),
                        fieldWithPath("content[].memberId").description("작성 회원 ID (비로그인 문의면 null)").optional(),
                        fieldWithPath("content[].memberName").description("작성 회원 이름 (비로그인 문의면 null)").optional(),
                        fieldWithPath("content[].email").description("회신 이메일"),
                        fieldWithPath("content[].subject").description("제목 (선택)").optional(),
                        fieldWithPath("content[].content").description("문의 내용"),
                        fieldWithPath("content[].status").description("처리 상태 (OPEN, CLOSED)"),
                        fieldWithPath("content[].adminMemo").description("관리자 메모").optional(),
                        fieldWithPath("content[].createdAt").description("접수 일시"),
                        fieldWithPath("content[].closedAt").description("종료 일시").optional(),
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
    }

    @Test
    fun `admin filters inquiries by status`() {
        saveInquiry(content = "열린 문의", createdDate = baseTime.minusHours(1))
        saveInquiry(content = "닫힌 문의", createdDate = baseTime, status = InquiryStatus.CLOSED)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/admin/api/inquiries")
                .param("status", "OPEN")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalElements").value(1))
            .andExpect(jsonPath("$.content[0].content").value("열린 문의"))

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/admin/api/inquiries")
                .param("status", "CLOSED")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalElements").value(1))
            .andExpect(jsonPath("$.content[0].content").value("닫힌 문의"))

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/admin/api/inquiries")
                .param("status", "ALL")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalElements").value(2))
    }

    @Test
    fun `admin inquiry list is paged`() {
        saveInquiry(content = "문의 1", createdDate = baseTime.minusHours(1))
        saveInquiry(content = "문의 2", createdDate = baseTime)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/admin/api/inquiries")
                .param("page", "1")
                .param("size", "1")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalElements").value(2))
            .andExpect(jsonPath("$.totalPages").value(2))
            .andExpect(jsonPath("$.numberOfElements").value(1))
            .andExpect(jsonPath("$.content[0].content").value("문의 1"))
    }

    @Test
    fun `admin reads inquiry detail`() {
        val inquiry = saveInquiry(
            content = "상세 문의 내용",
            createdDate = baseTime,
            subject = "제목",
            member = TestData.member,
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/admin/api/inquiries/{id}", inquiry.id)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(inquiry.id.toString()))
            .andExpect(jsonPath("$.content").value("상세 문의 내용"))
            .andExpect(jsonPath("$.status").value("OPEN"))
            .andDo(
                document(
                    "admin/inquiries-detail",
                    pathParameters(
                        parameterWithName("id").description("문의 ID")
                    ),
                    responseFields(
                        fieldWithPath("id").description("문의 ID"),
                        fieldWithPath("memberId").description("작성 회원 ID (비로그인 문의면 null)").optional(),
                        fieldWithPath("memberName").description("작성 회원 이름 (비로그인 문의면 null)").optional(),
                        fieldWithPath("email").description("회신 이메일"),
                        fieldWithPath("subject").description("제목 (선택)").optional(),
                        fieldWithPath("content").description("문의 내용"),
                        fieldWithPath("status").description("처리 상태 (OPEN, CLOSED)"),
                        fieldWithPath("adminMemo").description("관리자 메모").optional(),
                        fieldWithPath("createdAt").description("접수 일시"),
                        fieldWithPath("closedAt").description("종료 일시").optional(),
                    )
                )
            )
    }

    @Test
    fun `unknown inquiry id returns not found`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/admin/api/inquiries/{id}", java.util.UUID.randomUUID())
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isNotFound)
    }

    @Test
    fun `admin closes inquiry with memo`() {
        val inquiry = saveInquiry(content = "종료할 문의", createdDate = baseTime)
        em.flush()
        em.clear()

        val json = """
            {
                "status": "CLOSED",
                "memo": "이메일로 회신 완료"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/admin/api/inquiries/{id}/status", inquiry.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("CLOSED"))
            .andExpect(jsonPath("$.adminMemo").value("이메일로 회신 완료"))
            .andExpect(jsonPath("$.closedAt").exists())
            .andDo(
                document(
                    "admin/inquiries-change-status",
                    pathParameters(
                        parameterWithName("id").description("문의 ID")
                    ),
                    requestFields(
                        fieldWithPath("status").description("변경할 상태 (OPEN, CLOSED)"),
                        fieldWithPath("memo").description("관리자 메모 (생략하면 기존 메모 유지)").optional(),
                    ),
                    responseFields(
                        fieldWithPath("id").description("문의 ID"),
                        fieldWithPath("memberId").description("작성 회원 ID (비로그인 문의면 null)").optional(),
                        fieldWithPath("memberName").description("작성 회원 이름 (비로그인 문의면 null)").optional(),
                        fieldWithPath("email").description("회신 이메일"),
                        fieldWithPath("subject").description("제목 (선택)").optional(),
                        fieldWithPath("content").description("문의 내용"),
                        fieldWithPath("status").description("처리 상태 (OPEN, CLOSED)"),
                        fieldWithPath("adminMemo").description("관리자 메모").optional(),
                        fieldWithPath("createdAt").description("접수 일시"),
                        fieldWithPath("closedAt").description("종료 일시").optional(),
                    )
                )
            )

        em.flush()
        em.clear()
        val closed = inquiryRepository.findById(inquiry.id).orElseThrow()
        assertThat(closed.status).isEqualTo(InquiryStatus.CLOSED)
        assertThat(closed.closedAt).isNotNull()
        assertThat(closed.closedBy).isEqualTo(TestData.admin.id)
        assertThat(closed.adminMemo).isEqualTo("이메일로 회신 완료")
    }

    @Test
    fun `reopening inquiry clears closed information`() {
        val inquiry = saveInquiry(
            content = "재오픈 문의",
            createdDate = baseTime,
            status = InquiryStatus.CLOSED,
            memo = "처리 완료",
        )
        em.flush()
        em.clear()

        val json = """
            {
                "status": "OPEN"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/admin/api/inquiries/{id}/status", inquiry.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("OPEN"))
            .andExpect(jsonPath("$.closedAt").doesNotExist())
            .andExpect(jsonPath("$.adminMemo").value("처리 완료"))

        em.flush()
        em.clear()
        val reopened = inquiryRepository.findById(inquiry.id).orElseThrow()
        assertThat(reopened.status).isEqualTo(InquiryStatus.OPEN)
        assertThat(reopened.closedAt).isNull()
        assertThat(reopened.closedBy).isNull()
        assertThat(reopened.adminMemo).isEqualTo("처리 완료")
    }

    private fun saveInquiry(
        content: String,
        createdDate: LocalDateTime,
        subject: String? = null,
        status: InquiryStatus = InquiryStatus.OPEN,
        member: Member? = null,
        memo: String? = null,
    ): Inquiry {
        val inquiry = inquiryRepository.save(
            Inquiry(
                member = member,
                email = "guest@dutypark.o-r.kr",
                subject = subject,
                content = content,
                ipAddress = "127.0.0.1",
            )
        )
        if (status == InquiryStatus.CLOSED) {
            inquiry.changeStatus(InquiryStatus.CLOSED, memo, TestData.admin.id!!, createdDate)
        }
        inquiry.createdDate = createdDate
        return inquiry
    }
}
