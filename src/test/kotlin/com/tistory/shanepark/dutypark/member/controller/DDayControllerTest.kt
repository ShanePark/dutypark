package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent
import com.tistory.shanepark.dutypark.member.repository.DDayRepository
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.*
import org.springframework.restdocs.request.RequestDocumentation.parameterWithName
import org.springframework.restdocs.request.RequestDocumentation.pathParameters
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDate

class DDayControllerTest : RestDocsTest() {

    @Autowired
    lateinit var dDayRepository: DDayRepository

    @Test
    fun `create dday`() {
        val json = """
            {
                "title": "Birthday",
                "date": "${LocalDate.now().plusDays(30)}",
                "isPrivate": false
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/dday")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.title").value("Birthday"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "dday/create",
                    requestFields(
                        fieldWithPath("title").description("D-Day title (1-30 characters)"),
                        fieldWithPath("date").description("Target date (yyyy-MM-dd)"),
                        fieldWithPath("isPrivate").description("Private flag (hidden from friends)")
                    ),
                    responseFields(
                        fieldWithPath("id").description("D-Day ID"),
                        fieldWithPath("title").description("D-Day title"),
                        fieldWithPath("date").description("Target date"),
                        fieldWithPath("isPrivate").description("Private flag"),
                        fieldWithPath("calc").description("Calculated days string"),
                        fieldWithPath("daysLeft").description("Days left (negative if past)")
                    )
                )
            )
    }

    @Test
    fun `update dday`() {
        val saved = dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "Original",
                date = LocalDate.now().plusDays(10),
                isPrivate = false
            )
        )
        em.flush()
        em.clear()

        val json = """
            {
                "id": ${saved.id},
                "title": "Updated Birthday",
                "date": "${LocalDate.now().plusDays(60)}",
                "isPrivate": true
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/dday")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.title").value("Updated Birthday"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "dday/update",
                    requestFields(
                        fieldWithPath("id").description("D-Day ID to update"),
                        fieldWithPath("title").description("D-Day title (1-30 characters)"),
                        fieldWithPath("date").description("Target date (yyyy-MM-dd)"),
                        fieldWithPath("isPrivate").description("Private flag")
                    ),
                    responseFields(
                        fieldWithPath("id").description("D-Day ID"),
                        fieldWithPath("title").description("D-Day title"),
                        fieldWithPath("date").description("Target date"),
                        fieldWithPath("isPrivate").description("Private flag"),
                        fieldWithPath("calc").description("Calculated days string"),
                        fieldWithPath("daysLeft").description("Days left")
                    )
                )
            )
    }

    @Test
    fun `get my ddays`() {
        dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "My Birthday",
                date = LocalDate.now().plusDays(30),
                isPrivate = false
            )
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/dday")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").isArray)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "dday/get-list",
                    responseFields(
                        fieldWithPath("[].id").description("D-Day ID"),
                        fieldWithPath("[].title").description("D-Day title"),
                        fieldWithPath("[].date").description("Target date"),
                        fieldWithPath("[].isPrivate").description("Private flag"),
                        fieldWithPath("[].calc").description("Calculated days string"),
                        fieldWithPath("[].daysLeft").description("Days left")
                    )
                )
            )
    }

    @Test
    fun `get ddays by member id`() {
        dDayRepository.save(
            DDayEvent(
                member = TestData.member2,
                title = "Friend's Event",
                date = LocalDate.now().plusDays(15),
                isPrivate = false
            )
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/dday/{id}", TestData.member2.id)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "dday/get-by-member",
                    pathParameters(
                        parameterWithName("id").description("Member ID to get D-Days for")
                    ),
                    responseFields(
                        fieldWithPath("[].id").description("D-Day ID"),
                        fieldWithPath("[].title").description("D-Day title"),
                        fieldWithPath("[].date").description("Target date"),
                        fieldWithPath("[].isPrivate").description("Private flag"),
                        fieldWithPath("[].calc").description("Calculated days string"),
                        fieldWithPath("[].daysLeft").description("Days left")
                    )
                )
            )
    }

    @Test
    fun `delete dday`() {
        val saved = dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "To Delete",
                date = LocalDate.now().plusDays(5),
                isPrivate = false
            )
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/dday/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "dday/delete",
                    pathParameters(
                        parameterWithName("id").description("D-Day ID to delete")
                    )
                )
            )
    }

}
