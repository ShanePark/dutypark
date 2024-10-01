package com.tistory.shanepark.dutypark.todo.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import jakarta.servlet.http.Cookie
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

class TodoControllerTest : RestDocsTest() {

    @Autowired
    lateinit var todoRepository: TodoRepository

    @Test
    fun `todoList test`() {
        // Given
        todoRepository.saveAll(
            listOf(
                Todo(
                    member = TestData.member,
                    title = "Todo 1",
                    content = "Content 1",
                    position = 1
                ),
                Todo(
                    member = TestData.member,
                    title = "Todo 2",
                    content = "Content 2",
                    position = 2
                )
            )
        )

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .cookie(Cookie(jwtConfig.cookieName, getJwt(TestData.member)))
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$[0].title").value("Todo 1"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/get-list",
                    responseFields(
                        fieldWithPath("[].id").description("Todo ID"),
                        fieldWithPath("[].title").description("Todo Title"),
                        fieldWithPath("[].content").description("Todo Content"),
                        fieldWithPath("[].position").description("Todo Position")
                    )
                )
            )
    }

    @Test
    fun `addTodo test`() {
        val json = """
            {
                "title": "New Todo",
                "content": "New Content"
            }
        """.trimIndent()

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/todos")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .cookie(Cookie(jwtConfig.cookieName, getJwt(TestData.member)))
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.title").value("New Todo"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/create",
                    requestFields(
                        fieldWithPath("title").description("Todo Title"),
                        fieldWithPath("content").description("Todo Content")
                    ),
                    responseFields(
                        fieldWithPath("id").description("Todo ID"),
                        fieldWithPath("title").description("Todo Title"),
                        fieldWithPath("content").description("Todo Content"),
                        fieldWithPath("position").description("Todo Position")
                    )
                )
            )
    }

    @Test
    fun `editTodo test`() {
        // Given
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 1
            )
        )

        val json = """
            {
                "title": "Updated Todo",
                "content": "Updated Content"
            }
        """.trimIndent()

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .cookie(Cookie(jwtConfig.cookieName, getJwt(TestData.member)))
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.title").value("Updated Todo"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/update",
                    pathParameters(
                        parameterWithName("id").description("Todo ID")
                    ),
                    requestFields(
                        fieldWithPath("title").description("Todo Title"),
                        fieldWithPath("content").description("Todo Content")
                    ),
                    responseFields(
                        fieldWithPath("id").description("Todo ID"),
                        fieldWithPath("title").description("Updated Todo Title"),
                        fieldWithPath("content").description("Updated Todo Content"),
                        fieldWithPath("position").description("Todo Position")
                    )
                )
            )
    }

    @Test
    fun `deleteTodo test`() {
        // Given
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 1
            )
        )

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .cookie(Cookie(jwtConfig.cookieName, getJwt(TestData.member)))
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/delete",
                    pathParameters(
                        parameterWithName("id").description("Todo ID")
                    )
                )
            )
    }

    @Test
    fun `updatePosition test`() {
        // Given
        val saved1 = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo 1",
                content = "Content 1",
                position = 1
            )
        )

        val saved2 = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo 2",
                content = "Content 2",
                position = 2
            )
        )

        val json = """
            [
                "${saved2.id}",
                "${saved1.id}"
            ]
        """.trimIndent()

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/position")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .cookie(Cookie(jwtConfig.cookieName, getJwt(TestData.member)))
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/update-position",
                    requestFields(
                        fieldWithPath("[]").description("Todo ID List")
                    )
                )
            )
    }


}
