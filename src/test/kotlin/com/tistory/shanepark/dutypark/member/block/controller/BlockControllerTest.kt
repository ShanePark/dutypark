package com.tistory.shanepark.dutypark.member.block.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.block.repository.MemberBlockRepository
import com.tistory.shanepark.dutypark.member.block.service.BlockService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.JsonFieldType
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.restdocs.request.RequestDocumentation.parameterWithName
import org.springframework.restdocs.request.RequestDocumentation.pathParameters
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class BlockControllerTest : RestDocsTest() {

    @Autowired
    lateinit var blockService: BlockService

    @Autowired
    lateinit var memberBlockRepository: MemberBlockRepository

    @Test
    fun `block member`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/blocks/{memberId}", TestData.member2.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "blocks/block",
                    pathParameters(
                        parameterWithName("memberId").description("Target member ID to block")
                    )
                )
            )

        assertThat(memberBlockRepository.findAll()).hasSize(1)
    }

    @Test
    fun `block member is idempotent`() {
        blockMember()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/blocks/{memberId}", TestData.member2.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        assertThat(memberBlockRepository.findAll()).hasSize(1)
    }

    @Test
    fun `block self returns bad request`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/blocks/{memberId}", TestData.member.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.status").value(400))
            .andExpect(jsonPath("$.code").value("block.self"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "blocks/block-bad-request",
                    pathParameters(
                        parameterWithName("memberId").description("Target member ID to block")
                    ),
                    standardErrorResponseFields("Machine-readable error code (`block.self`)")
                )
            )
    }

    @Test
    fun `block unknown member returns not found`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/blocks/{memberId}", -1L)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isNotFound)
    }

    @Test
    fun `block without login is unauthorized`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/blocks/{memberId}", TestData.member2.id!!)
                .accept(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `unblock member`() {
        blockMember()

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/blocks/{memberId}", TestData.member2.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "blocks/unblock",
                    pathParameters(
                        parameterWithName("memberId").description("Target member ID to unblock")
                    )
                )
            )

        assertThat(memberBlockRepository.findAll()).isEmpty()
    }

    @Test
    fun `unblock is idempotent`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/blocks/{memberId}", TestData.member2.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
    }

    @Test
    fun `get blocked members`() {
        blockMember()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/blocks")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").isArray)
            .andExpect(jsonPath("$[0].id").value(TestData.member2.id!!))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "blocks/get-list",
                    responseFields(
                        fieldWithPath("[].id").description("Blocked member ID"),
                        fieldWithPath("[].name").description("Blocked member name"),
                        fieldWithPath("[].hasProfilePhoto").description("Whether the blocked member has a profile photo"),
                        fieldWithPath("[].profilePhotoVersion").description("Profile photo version for cache busting"),
                        fieldWithPath("[].blockedAt").description("When the member was blocked")
                    )
                )
            )
    }

    private fun blockMember() {
        blockService.block(TestData.member.id!!, TestData.member2.id!!)
        em.flush()
        em.clear()
    }

    private fun standardErrorResponseFields(codeDescription: String) = responseFields(
        fieldWithPath("status").type(JsonFieldType.NUMBER).description("HTTP status code"),
        fieldWithPath("code").type(JsonFieldType.STRING).description(codeDescription),
        fieldWithPath("details").type(JsonFieldType.OBJECT).optional().description("Additional error details"),
        fieldWithPath("fieldErrors").type(JsonFieldType.ARRAY).optional().description("Field validation errors")
    )

}
