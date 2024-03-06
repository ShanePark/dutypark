package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.requestFields
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class MemberControllerTest : RestDocsTest() {

    @Test
    fun updateCalendarVisibility() {
        // Given
        val member = TestData.member
        assertThat(member.calendarVisibility).isEqualTo(Visibility.FRIENDS)

        // When
        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/${member.id}/visibility")
                .accept("application/json")
                .contentType("application/json")
                .content("{\"visibility\": \"PRIVATE\"}")
                .cookie(Cookie(jwtConfig.cookieName, getJwt(member)))
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "members/update-visibility",
                    requestFields(
                        fieldWithPath("visibility").description("Calendar visibility")
                    )
                )
            )

        // Then
        val findMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(findMember.calendarVisibility).isEqualTo(Visibility.PRIVATE)
    }

}
