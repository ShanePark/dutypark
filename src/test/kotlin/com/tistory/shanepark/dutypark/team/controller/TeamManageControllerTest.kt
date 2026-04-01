package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.batch.exceptions.NotSupportedFileException
import com.tistory.shanepark.dutypark.duty.batch.exceptions.YearMonthNotMatchException
import com.tistory.shanepark.dutypark.duty.batch.service.DutyBatchSungsimService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.team.domain.enums.WorkType
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.http.MediaType
import org.springframework.http.HttpHeaders
import org.springframework.mock.web.MockMultipartFile
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.JsonFieldType
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.restdocs.request.RequestDocumentation.parameterWithName
import org.springframework.restdocs.request.RequestDocumentation.queryParameters
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.whenever
import java.time.YearMonth

class TeamManageControllerTest : RestDocsTest() {

    @MockitoBean
    lateinit var dutyBatchSungsimService: DutyBatchSungsimService

    @Test
    fun `manager can load team details`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/teams/manage/{teamId}", TestData.team.id!!)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(TestData.team.id))
            .andExpect(jsonPath("$.name").value(TestData.team.name))
    }

    @Test
    fun `non-manager cannot load team details`() {
        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/teams/manage/{teamId}", TestData.team.id!!)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("team.manage.forbidden"))
    }

    @Test
    fun `manager can change team admin`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/teams/manage/{teamId}/admin", TestData.team.id!!)
                .param("memberId", TestData.member2.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val updated = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(updated.admin?.id).isEqualTo(TestData.member2.id)
    }

    @Test
    fun `manager can update batch template`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            MockMvcRequestBuilders.patch("/api/teams/manage/{teamId}/batch-template", TestData.team.id!!)
                .param("templateName", DutyBatchTemplate.SUNGSIM_CAKE.name)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val updated = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(updated.dutyBatchTemplate).isEqualTo(DutyBatchTemplate.SUNGSIM_CAKE)
    }

    @Test
    fun `manager can update work type`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            MockMvcRequestBuilders.patch("/api/teams/manage/{teamId}/work-type", TestData.team.id!!)
                .param("workType", WorkType.FLEXIBLE.name)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val updated = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(updated.workType).isEqualTo(WorkType.FLEXIBLE)
    }

    @Test
    fun `batch upload requires template`() {
        setTeamAdmin(TestData.member.id!!)
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        team.dutyBatchTemplate = null
        teamRepository.save(team)

        val file = MockMultipartFile(
            "file",
            "duty.xlsx",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "dummy".toByteArray()
        )

        mockMvc.perform(
            MockMvcRequestBuilders.multipart("/api/teams/manage/{teamId}/duty", TestData.team.id!!)
                .file(file)
                .param("year", "2024")
                .param("month", "1")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("dutyBatch.template.required"))
    }

    @Test
    fun `team batch upload returns errorCode and errorDetails when file format is unsupported`() {
        setTeamAdmin(TestData.member.id!!)
        teamRepository.findById(TestData.team.id!!).orElseThrow().apply {
            dutyBatchTemplate = DutyBatchTemplate.SUNGSIM_CAKE
            teamRepository.save(this)
        }
        whenever(
            dutyBatchSungsimService.batchUploadTeam(any(), eq(TestData.team.id!!), eq(YearMonth.of(2024, 1)))
        ).thenThrow(NotSupportedFileException(".xls,.xlsx"))

        mockMvc.perform(
            MockMvcRequestBuilders.multipart("/api/teams/manage/{teamId}/duty", TestData.team.id!!)
                .file(validFile())
                .param("year", "2024")
                .param("month", "1")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.result").value(false))
            .andExpect(jsonPath("$.errorCode").value("dutyBatch.notSupportedFile"))
            .andExpect(jsonPath("$.errorDetails.supportedFile").value(".xls,.xlsx"))
    }

    @Test
    fun `team batch upload returns year and month details for mismatched files`() {
        setTeamAdmin(TestData.member.id!!)
        teamRepository.findById(TestData.team.id!!).orElseThrow().apply {
            dutyBatchTemplate = DutyBatchTemplate.SUNGSIM_CAKE
            teamRepository.save(this)
        }
        whenever(
            dutyBatchSungsimService.batchUploadTeam(any(), eq(TestData.team.id!!), eq(YearMonth.of(2024, 1)))
        ).thenThrow(YearMonthNotMatchException(YearMonth.of(2023, 12)))

        mockMvc.perform(
            MockMvcRequestBuilders.multipart("/api/teams/manage/{teamId}/duty", TestData.team.id!!)
                .file(validFile())
                .param("year", "2024")
                .param("month", "1")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.result").value(false))
            .andExpect(jsonPath("$.errorCode").value("dutyBatch.yearMonthNotMatch"))
            .andExpect(jsonPath("$.errorDetails.year").value(2023))
            .andExpect(jsonPath("$.errorDetails.month").value(12))
    }

    @Test
    fun `manager can update default duty`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            MockMvcRequestBuilders.patch("/api/teams/manage/{teamId}/default-duty", TestData.team.id!!)
                .param("color", "#123456")
                .param("name", "DEFAULT")
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val updated = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(updated.defaultDutyName).isEqualTo("DEFAULT")
        assertThat(updated.defaultDutyColor).isEqualTo("#123456")
    }

    @Test
    fun `manager can add member to team`() {
        setTeamAdmin(TestData.member.id!!)
        val newMember = memberRepository.save(Member("joiner", "joiner@duty.park", "pass"))

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/teams/manage/{teamId}/members", TestData.team.id!!)
                .param("memberId", newMember.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val updatedMember = memberRepository.findById(newMember.id!!).orElseThrow()
        assertThat(updatedMember.team?.id).isEqualTo(TestData.team.id)
    }

    @Test
    fun `add member returns code-first bad request when member already belongs to a team`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/teams/manage/{teamId}/members", TestData.team.id!!)
                .param("memberId", TestData.member.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("team.member.alreadyAssigned"))
    }

    @Test
    fun `manager can remove member from team`() {
        setTeamAdmin(TestData.member.id!!)
        val member = memberRepository.save(Member("removee", "removee@duty.park", "pass"))
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        team.addMember(member)
        teamRepository.save(team)

        mockMvc.perform(
            MockMvcRequestBuilders.delete("/api/teams/manage/{teamId}/members", TestData.team.id!!)
                .param("memberId", member.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val updatedMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(updatedMember.team).isNull()
    }

    @Test
    fun `remove member returns code-first bad request when member does not belong to team`() {
        setTeamAdmin(TestData.member.id!!)
        val outsider = memberRepository.save(Member("outsider", "outsider@duty.park", "pass"))

        mockMvc.perform(
            MockMvcRequestBuilders.delete("/api/teams/manage/{teamId}/members", TestData.team.id!!)
                .param("memberId", outsider.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("team.member.notInTeam"))
    }

    @Test
    fun `members endpoint requires login`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/teams/manage/members")
                .param("teamId", TestData.team.id!!.toString())
                .param("keyword", "candidate")
                .param("page", "0")
                .param("size", "10")
                .accept(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.required"))
            .andDo(
                document(
                    "teams/manage/search-members-unauthorized",
                    queryParameters(
                        parameterWithName("teamId").description("Team ID that the caller manages"),
                        parameterWithName("keyword").description("Search keyword for member name"),
                        parameterWithName("page").description("Page number (0-based)"),
                        parameterWithName("size").description("Page size")
                    ),
                    standardErrorResponseFields("Machine-readable error code (`auth.required`)")
                )
            )
    }

    @Test
    fun `non-manager cannot search invite members`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/teams/manage/members")
                .param("teamId", TestData.team.id!!.toString())
                .param("keyword", "candidate")
                .param("page", "0")
                .param("size", "10")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("team.manage.forbidden"))
            .andDo(
                document(
                    "teams/manage/search-members-forbidden",
                    queryParameters(
                        parameterWithName("teamId").description("Team ID that the caller manages"),
                        parameterWithName("keyword").description("Search keyword for member name"),
                        parameterWithName("page").description("Page number (0-based)"),
                        parameterWithName("size").description("Page size")
                    ),
                    standardErrorResponseFields("Machine-readable error code (`team.manage.forbidden`)")
                )
            )
    }

    @Test
    fun `manager can search invite members for team`() {
        setTeamAdmin(TestData.member.id!!)
        val member = memberRepository.save(Member("candidate", "candidate@duty.park", "pass"))

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/teams/manage/members")
                .param("teamId", TestData.team.id!!.toString())
                .param("keyword", "candidate")
                .param("page", "0")
                .param("size", "10")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.content.length()").value(1))
            .andExpect(jsonPath("$.content[0].id").value(member.id))
            .andExpect(jsonPath("$.content[0].name").value(member.name))
            .andExpect(jsonPath("$.content[0].email").value(member.email))
            .andExpect(jsonPath("$.content[0].kakaoId").doesNotExist())
            .andExpect(jsonPath("$.content[0].naverId").doesNotExist())
            .andExpect(jsonPath("$.content[0].hasPassword").doesNotExist())
            .andExpect(jsonPath("$.content[0].calendarVisibility").doesNotExist())
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "teams/manage/search-members",
                    queryParameters(
                        parameterWithName("teamId").description("Team ID that the caller manages"),
                        parameterWithName("keyword").description("Search keyword for member name"),
                        parameterWithName("page").description("Page number (0-based)"),
                        parameterWithName("size").description("Page size")
                    ),
                    responseFields(
                        fieldWithPath("content").description("List of invite candidates"),
                        fieldWithPath("content[].id").description("Member ID"),
                        fieldWithPath("content[].name").description("Member name"),
                        fieldWithPath("content[].email").description("Member email (nullable)"),
                        fieldWithPath("content[].teamId").description("Assigned team ID (nullable)"),
                        fieldWithPath("content[].team").description("Assigned team name (nullable)"),
                        fieldWithPath("content[].hasProfilePhoto").description("Whether the member has a profile photo"),
                        fieldWithPath("content[].profilePhotoVersion").description("Profile photo version for cache busting"),
                        fieldWithPath("totalPages").description("Total pages"),
                        fieldWithPath("totalElements").description("Total elements"),
                        fieldWithPath("first").description("Is first page"),
                        fieldWithPath("last").description("Is last page"),
                        fieldWithPath("size").description("Page size"),
                        fieldWithPath("number").description("Current page number"),
                        fieldWithPath("numberOfElements").description("Number of elements in current page"),
                        fieldWithPath("empty").description("Is empty"),
                        fieldWithPath("pageable").description("Pageable info"),
                        fieldWithPath("pageable.pageNumber").description("Page number"),
                        fieldWithPath("pageable.pageSize").description("Page size"),
                        fieldWithPath("pageable.sort").description("Sort info"),
                        fieldWithPath("pageable.sort.empty").description("Is sort empty"),
                        fieldWithPath("pageable.sort.sorted").description("Is sorted"),
                        fieldWithPath("pageable.sort.unsorted").description("Is unsorted"),
                        fieldWithPath("pageable.offset").description("Offset"),
                        fieldWithPath("pageable.paged").description("Is paged"),
                        fieldWithPath("pageable.unpaged").description("Is unpaged")
                    )
                )
            )
    }

    @Test
    fun `team admin can add and remove manager`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/teams/manage/{teamId}/manager", TestData.team.id!!)
                .param("memberId", TestData.member2.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        var team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(team.isManager(TestData.member2.id)).isTrue

        mockMvc.perform(
            MockMvcRequestBuilders.delete("/api/teams/manage/{teamId}/manager", TestData.team.id!!)
                .param("memberId", TestData.member2.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(team.isManager(TestData.member2.id)).isFalse
    }

    @Test
    fun `add manager returns code-first bad request when member does not belong to team`() {
        setTeamAdmin(TestData.member.id!!)
        val outsider = memberRepository.save(Member("mgrout", "mgrout@duty.park", "pass"))

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/teams/manage/{teamId}/manager", TestData.team.id!!)
                .param("memberId", outsider.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("team.member.notInTeam"))
    }

    @Test
    fun `remove manager returns code-first bad request when member does not belong to team`() {
        setTeamAdmin(TestData.member.id!!)
        val outsider = memberRepository.save(Member("rmgout", "rmgout@duty.park", "pass"))

        mockMvc.perform(
            MockMvcRequestBuilders.delete("/api/teams/manage/{teamId}/manager", TestData.team.id!!)
                .param("memberId", outsider.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("team.member.notInTeam"))
    }

    @Test
    fun `only admin can add manager`() {
        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/teams/manage/{teamId}/manager", TestData.team.id!!)
                .param("memberId", TestData.member2.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("team.admin.required"))
    }

    private fun setTeamAdmin(memberId: Long) {
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        val member = memberRepository.findById(memberId).orElseThrow()
        team.changeAdmin(member)
        teamRepository.save(team)
        em.flush()
        em.clear()
    }

    private fun validFile(): MockMultipartFile {
        return MockMultipartFile(
            "file",
            "duty.xlsx",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "dummy".toByteArray()
        )
    }

    private fun standardErrorResponseFields(codeDescription: String) = responseFields(
        fieldWithPath("status").type(JsonFieldType.NUMBER).description("HTTP status code"),
        fieldWithPath("code").type(JsonFieldType.STRING).description(codeDescription),
        fieldWithPath("details").type(JsonFieldType.OBJECT).optional().description("Additional error details"),
        fieldWithPath("fieldErrors").type(JsonFieldType.ARRAY).optional().description("Field validation errors")
    )
}
