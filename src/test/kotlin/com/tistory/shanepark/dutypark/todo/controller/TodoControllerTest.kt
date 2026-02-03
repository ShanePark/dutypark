package com.tistory.shanepark.dutypark.todo.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.*
import org.springframework.restdocs.request.RequestDocumentation.parameterWithName
import org.springframework.restdocs.request.RequestDocumentation.pathParameters
import org.springframework.restdocs.request.RequestDocumentation.queryParameters
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDate

class TodoControllerTest : RestDocsTest() {

    @Autowired
    lateinit var todoRepository: TodoRepository

    private val fixedDate = LocalDate.of(2025, 1, 15)

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
                .withAuth(TestData.member)
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
                        fieldWithPath("[].position").description("Todo Position"),
                        fieldWithPath("[].status").description("Todo Status"),
                        fieldWithPath("[].createdDate").description("createdDate"),
                        fieldWithPath("[].completedDate").description("completedDate"),
                        fieldWithPath("[].dueDate").description("Due date for the todo"),
                        fieldWithPath("[].isOverdue").description("Whether the todo is overdue"),
                        fieldWithPath("[].hasAttachments").description("Whether todo has attachments")
                    )
                )
            )
    }

    @Test
    fun `addTodo test`() {
        val json = """
            {
                "title": "New Todo",
                "content": "New Content",
                "dueDate": "2025-12-31",
                "attachmentSessionId": null,
                "orderedAttachmentIds": []
            }
        """.trimIndent()

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/todos")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.title").value("New Todo"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/create",
                    requestFields(
                        fieldWithPath("title").description("Todo Title"),
                        fieldWithPath("content").description("Todo Content"),
                        fieldWithPath("dueDate").optional().description("Due date for the todo (YYYY-MM-DD)"),
                        fieldWithPath("attachmentSessionId").optional().description("첨부 업로드 세션 ID"),
                        fieldWithPath("orderedAttachmentIds").optional().description("저장 순서를 유지할 첨부 ID 배열")
                    ),
                    responseFields(
                        fieldWithPath("id").description("Todo ID"),
                        fieldWithPath("title").description("Todo Title"),
                        fieldWithPath("content").description("Todo Content"),
                        fieldWithPath("position").description("Todo Position"),
                        fieldWithPath("status").description("Todo Status"),
                        fieldWithPath("createdDate").description("createdDate"),
                        fieldWithPath("completedDate").description("completedDate"),
                        fieldWithPath("dueDate").description("Due date for the todo"),
                        fieldWithPath("isOverdue").description("Whether the todo is overdue"),
                        fieldWithPath("hasAttachments").description("Whether todo has attachments")
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
                "content": "Updated Content",
                "dueDate": "2025-12-31",
                "attachmentSessionId": null,
                "orderedAttachmentIds": []
            }
        """.trimIndent()

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
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
                        fieldWithPath("content").description("Todo Content"),
                        fieldWithPath("dueDate").optional().description("Due date for the todo (YYYY-MM-DD)"),
                        fieldWithPath("attachmentSessionId").optional().description("첨부 업로드 세션 ID"),
                        fieldWithPath("orderedAttachmentIds").optional().description("저장 순서를 유지할 첨부 ID 배열")
                    ),
                    responseFields(
                        fieldWithPath("id").description("Todo ID"),
                        fieldWithPath("title").description("Updated Todo Title"),
                        fieldWithPath("content").description("Updated Todo Content"),
                        fieldWithPath("position").description("Todo Position"),
                        fieldWithPath("status").description("Todo Status"),
                        fieldWithPath("createdDate").description("createdDate"),
                        fieldWithPath("completedDate").description("completedDate"),
                        fieldWithPath("dueDate").description("Due date for the todo"),
                        fieldWithPath("isOverdue").description("Whether the todo is overdue"),
                        fieldWithPath("hasAttachments").description("Whether todo has attachments")
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
                .withAuth(TestData.member)
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
                .withAuth(TestData.member)
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

    @Test
    fun `completedTodoList test`() {
        val completed = Todo(
            member = TestData.member,
            title = "Todo Completed",
            content = "Content Completed",
            position = 0,
            status = TodoStatus.DONE
        )
        completed.markCompleted(0)
        todoRepository.save(completed)

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos/completed")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$[0].status").value("DONE"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/get-completed-list",
                    responseFields(
                        fieldWithPath("[].id").description("Todo ID"),
                        fieldWithPath("[].title").description("Todo Title"),
                        fieldWithPath("[].content").description("Todo Content"),
                        fieldWithPath("[].position").description("Todo Position"),
                        fieldWithPath("[].status").description("Todo Status"),
                        fieldWithPath("[].createdDate").description("createdDate"),
                        fieldWithPath("[].completedDate").description("completedDate"),
                        fieldWithPath("[].dueDate").description("Due date for the todo"),
                        fieldWithPath("[].isOverdue").description("Whether the todo is overdue"),
                        fieldWithPath("[].hasAttachments").description("Whether todo has attachments")
                    )
                )
            )
    }

    @Test
    fun `completeTodo test`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 1
            )
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/{id}/complete", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("DONE"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/complete",
                    pathParameters(
                        parameterWithName("id").description("Todo ID")
                    ),
                    responseFields(
                        fieldWithPath("id").description("Todo ID"),
                        fieldWithPath("title").description("Todo Title"),
                        fieldWithPath("content").description("Todo Content"),
                        fieldWithPath("position").description("Todo Position"),
                        fieldWithPath("status").description("Todo Status"),
                        fieldWithPath("createdDate").description("createdDate"),
                        fieldWithPath("completedDate").description("completedDate"),
                        fieldWithPath("dueDate").description("Due date for the todo"),
                        fieldWithPath("isOverdue").description("Whether the todo is overdue"),
                        fieldWithPath("hasAttachments").description("Whether todo has attachments")
                    )
                )
            )
    }

    @Test
    fun `reopenTodo test`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.DONE
            ).apply { markCompleted(0) }
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/{id}/reopen", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("TODO"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/reopen",
                    pathParameters(
                        parameterWithName("id").description("Todo ID")
                    ),
                    responseFields(
                        fieldWithPath("id").description("Todo ID"),
                        fieldWithPath("title").description("Todo Title"),
                        fieldWithPath("content").description("Todo Content"),
                        fieldWithPath("position").description("Todo Position"),
                        fieldWithPath("status").description("Todo Status"),
                        fieldWithPath("createdDate").description("createdDate"),
                        fieldWithPath("completedDate").description("completedDate"),
                        fieldWithPath("dueDate").description("Due date for the todo"),
                        fieldWithPath("isOverdue").description("Whether the todo is overdue"),
                        fieldWithPath("hasAttachments").description("Whether todo has attachments")
                    )
                )
            )
    }

    // ========== Kanban Board Endpoints ==========

    @Test
    fun `getBoard test`() {
        // Given
        todoRepository.saveAll(
            listOf(
                Todo(
                    member = TestData.member,
                    title = "Todo Task",
                    content = "Todo Content",
                    position = 0,
                    status = TodoStatus.TODO
                ),
                Todo(
                    member = TestData.member,
                    title = "In Progress Task",
                    content = "In Progress Content",
                    position = 0,
                    status = TodoStatus.IN_PROGRESS
                ),
                Todo(
                    member = TestData.member,
                    title = "Done Task",
                    content = "Done Content",
                    position = 0,
                    status = TodoStatus.DONE
                )
            )
        )

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos/board")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.todo").isArray)
            .andExpect(jsonPath("$.inProgress").isArray)
            .andExpect(jsonPath("$.done").isArray)
            .andExpect(jsonPath("$.counts.total").value(3))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/get-board",
                    responseFields(
                        fieldWithPath("todo").description("List of TODO status todos"),
                        fieldWithPath("todo[].id").description("Todo ID"),
                        fieldWithPath("todo[].title").description("Todo Title"),
                        fieldWithPath("todo[].content").description("Todo Content"),
                        fieldWithPath("todo[].position").description("Todo Position"),
                        fieldWithPath("todo[].status").description("Todo Status"),
                        fieldWithPath("todo[].createdDate").description("Created date"),
                        fieldWithPath("todo[].completedDate").description("Completed date"),
                        fieldWithPath("todo[].dueDate").description("Due date"),
                        fieldWithPath("todo[].isOverdue").description("Whether overdue"),
                        fieldWithPath("todo[].hasAttachments").description("Has attachments"),
                        fieldWithPath("inProgress").description("List of IN_PROGRESS status todos"),
                        fieldWithPath("inProgress[].id").description("Todo ID"),
                        fieldWithPath("inProgress[].title").description("Todo Title"),
                        fieldWithPath("inProgress[].content").description("Todo Content"),
                        fieldWithPath("inProgress[].position").description("Todo Position"),
                        fieldWithPath("inProgress[].status").description("Todo Status"),
                        fieldWithPath("inProgress[].createdDate").description("Created date"),
                        fieldWithPath("inProgress[].completedDate").description("Completed date"),
                        fieldWithPath("inProgress[].dueDate").description("Due date"),
                        fieldWithPath("inProgress[].isOverdue").description("Whether overdue"),
                        fieldWithPath("inProgress[].hasAttachments").description("Has attachments"),
                        fieldWithPath("done").description("List of DONE status todos"),
                        fieldWithPath("done[].id").description("Todo ID"),
                        fieldWithPath("done[].title").description("Todo Title"),
                        fieldWithPath("done[].content").description("Todo Content"),
                        fieldWithPath("done[].position").description("Todo Position"),
                        fieldWithPath("done[].status").description("Todo Status"),
                        fieldWithPath("done[].createdDate").description("Created date"),
                        fieldWithPath("done[].completedDate").description("Completed date"),
                        fieldWithPath("done[].dueDate").description("Due date"),
                        fieldWithPath("done[].isOverdue").description("Whether overdue"),
                        fieldWithPath("done[].hasAttachments").description("Has attachments"),
                        fieldWithPath("counts").description("Todo counts by status"),
                        fieldWithPath("counts.todo").description("Count of TODO status todos"),
                        fieldWithPath("counts.inProgress").description("Count of IN_PROGRESS status todos"),
                        fieldWithPath("counts.done").description("Count of DONE status todos"),
                        fieldWithPath("counts.total").description("Total count of all todos")
                    )
                )
            )
    }

    @Test
    fun `getByStatus test`() {
        // Given
        todoRepository.saveAll(
            listOf(
                Todo(
                    member = TestData.member,
                    title = "In Progress 1",
                    content = "Content 1",
                    position = 0,
                    status = TodoStatus.IN_PROGRESS
                ),
                Todo(
                    member = TestData.member,
                    title = "In Progress 2",
                    content = "Content 2",
                    position = 1,
                    status = TodoStatus.IN_PROGRESS
                )
            )
        )

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos/status/{status}", "IN_PROGRESS")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").isArray)
            .andExpect(jsonPath("$[0].status").value("IN_PROGRESS"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/get-by-status",
                    pathParameters(
                        parameterWithName("status").description("Todo status (TODO, IN_PROGRESS, DONE)")
                    ),
                    responseFields(
                        fieldWithPath("[].id").description("Todo ID"),
                        fieldWithPath("[].title").description("Todo Title"),
                        fieldWithPath("[].content").description("Todo Content"),
                        fieldWithPath("[].position").description("Todo Position"),
                        fieldWithPath("[].status").description("Todo Status"),
                        fieldWithPath("[].createdDate").description("Created date"),
                        fieldWithPath("[].completedDate").description("Completed date"),
                        fieldWithPath("[].dueDate").description("Due date"),
                        fieldWithPath("[].isOverdue").description("Whether overdue"),
                        fieldWithPath("[].hasAttachments").description("Has attachments")
                    )
                )
            )
    }

    @Test
    fun `changeStatus test`() {
        // Given
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.TODO
            )
        )

        val json = """
            {
                "status": "IN_PROGRESS",
                "orderedIds": ["${saved.id}"]
            }
        """.trimIndent()

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/{id}/status", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/change-status",
                    pathParameters(
                        parameterWithName("id").description("Todo ID")
                    ),
                    requestFields(
                        fieldWithPath("status").description("New status (TODO, IN_PROGRESS, DONE)"),
                        fieldWithPath("orderedIds").description("Ordered list of todo IDs in the target column after the move")
                    ),
                    responseFields(
                        fieldWithPath("id").description("Todo ID"),
                        fieldWithPath("title").description("Todo Title"),
                        fieldWithPath("content").description("Todo Content"),
                        fieldWithPath("position").description("Todo Position"),
                        fieldWithPath("status").description("Todo Status"),
                        fieldWithPath("createdDate").description("Created date"),
                        fieldWithPath("completedDate").description("Completed date"),
                        fieldWithPath("dueDate").description("Due date"),
                        fieldWithPath("isOverdue").description("Whether overdue"),
                        fieldWithPath("hasAttachments").description("Has attachments")
                    )
                )
            )
    }

    @Test
    fun `updatePositionsByStatus test`() {
        // Given
        val saved1 = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "In Progress 1",
                content = "Content 1",
                position = 0,
                status = TodoStatus.IN_PROGRESS
            )
        )

        val saved2 = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "In Progress 2",
                content = "Content 2",
                position = 1,
                status = TodoStatus.IN_PROGRESS
            )
        )

        val json = """
            {
                "status": "IN_PROGRESS",
                "orderedIds": ["${saved2.id}", "${saved1.id}"]
            }
        """.trimIndent()

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/positions")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/update-positions-by-status",
                    requestFields(
                        fieldWithPath("status").description("Status of todos being reordered (TODO, IN_PROGRESS, DONE)"),
                        fieldWithPath("orderedIds").description("Ordered list of todo IDs representing new positions")
                    )
                )
            )
    }

    // ========== Due Date Endpoints ==========

    @Test
    fun `getTodosByCalendar test`() {
        // Given
        todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Task with due date",
                content = "Content",
                position = 0,
                status = TodoStatus.TODO
            ).apply { dueDate = java.time.LocalDate.of(2025, 6, 15) }
        )

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos/calendar")
                .param("year", "2025")
                .param("month", "6")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").isArray)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/get-calendar",
                    queryParameters(
                        parameterWithName("year").description("Year to query"),
                        parameterWithName("month").description("Month to query (1-12)")
                    ),
                    responseFields(
                        fieldWithPath("[].id").description("Todo ID"),
                        fieldWithPath("[].title").description("Todo Title"),
                        fieldWithPath("[].content").description("Todo Content"),
                        fieldWithPath("[].position").description("Todo Position"),
                        fieldWithPath("[].status").description("Todo Status"),
                        fieldWithPath("[].createdDate").description("Created date"),
                        fieldWithPath("[].completedDate").description("Completed date"),
                        fieldWithPath("[].dueDate").description("Due date"),
                        fieldWithPath("[].isOverdue").description("Whether overdue"),
                        fieldWithPath("[].hasAttachments").description("Has attachments")
                    )
                )
            )
    }

    @Test
    fun `getTodosByDue test`() {
        // Given
        todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Task due today",
                content = "Content",
                position = 0,
                status = TodoStatus.TODO
            ).apply { dueDate = java.time.LocalDate.of(2025, 6, 15) }
        )

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos/due")
                .param("date", "2025-06-15")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").isArray)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/get-due",
                    queryParameters(
                        parameterWithName("date").description("Date to query (YYYY-MM-DD format)")
                    ),
                    responseFields(
                        fieldWithPath("[].id").description("Todo ID"),
                        fieldWithPath("[].title").description("Todo Title"),
                        fieldWithPath("[].content").description("Todo Content"),
                        fieldWithPath("[].position").description("Todo Position"),
                        fieldWithPath("[].status").description("Todo Status"),
                        fieldWithPath("[].createdDate").description("Created date"),
                        fieldWithPath("[].completedDate").description("Completed date"),
                        fieldWithPath("[].dueDate").description("Due date"),
                        fieldWithPath("[].isOverdue").description("Whether overdue"),
                        fieldWithPath("[].hasAttachments").description("Has attachments")
                    )
                )
            )
    }

    @Test
    fun `getOverdueTodos test`() {
        // Given
        todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Overdue Task",
                content = "Content",
                position = 0,
                status = TodoStatus.TODO
            ).apply { dueDate = fixedDate.minusDays(1) }
        )

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos/overdue")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").isArray)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "todos/get-overdue",
                    responseFields(
                        fieldWithPath("[].id").description("Todo ID"),
                        fieldWithPath("[].title").description("Todo Title"),
                        fieldWithPath("[].content").description("Todo Content"),
                        fieldWithPath("[].position").description("Todo Position"),
                        fieldWithPath("[].status").description("Todo Status"),
                        fieldWithPath("[].createdDate").description("Created date"),
                        fieldWithPath("[].completedDate").description("Completed date"),
                        fieldWithPath("[].dueDate").description("Due date"),
                        fieldWithPath("[].isOverdue").description("Whether overdue"),
                        fieldWithPath("[].hasAttachments").description("Has attachments")
                    )
                )
            )
    }

    // ========== 401 Unauthorized Tests ==========

    @Test
    fun `todoList without auth returns 401`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `addTodo without auth returns 401`() {
        val json = """{"title": "Test", "content": "Content"}"""

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/todos")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `getBoard without auth returns 401`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos/board")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isUnauthorized)
    }

    // ========== 404 Not Found Tests ==========

    @Test
    fun `editTodo with non-existent id returns 400`() {
        val nonExistentId = java.util.UUID.randomUUID()
        val json = """{"title": "Updated", "content": "Content"}"""

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", nonExistentId)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `deleteTodo with non-existent id returns 400`() {
        val nonExistentId = java.util.UUID.randomUUID()

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/todos/{id}", nonExistentId)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `completeTodo with non-existent id returns 400`() {
        val nonExistentId = java.util.UUID.randomUUID()

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/{id}/complete", nonExistentId)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `reopenTodo with non-existent id returns 400`() {
        val nonExistentId = java.util.UUID.randomUUID()

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/{id}/reopen", nonExistentId)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `changeStatus with non-existent id returns 400`() {
        val nonExistentId = java.util.UUID.randomUUID()
        val json = """{"status": "IN_PROGRESS", "position": 0}"""

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/{id}/status", nonExistentId)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }

    // ========== 403/400 Ownership Violation Tests ==========

    @Test
    fun `editTodo by different member returns 400`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 1
            )
        )

        val json = """{"title": "Hacked", "content": "Hacked Content"}"""

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `deleteTodo by different member returns 400`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 1
            )
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `completeTodo by different member returns 400`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 1
            )
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/{id}/complete", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `reopenTodo by different member returns 400`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.DONE
            ).apply { markCompleted(0) }
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/{id}/reopen", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `changeStatus by different member returns 400`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.TODO
            )
        )

        val json = """{"status": "DONE", "position": 0}"""

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/{id}/status", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `updatePosition by different member returns 400`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 1
            )
        )

        val json = """["${saved.id}"]"""

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/position")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `updatePositionsByStatus by different member returns 400`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.IN_PROGRESS
            )
        )

        val json = """{"status": "IN_PROGRESS", "orderedIds": ["${saved.id}"]}"""

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/positions")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isBadRequest)
    }

    // ========== 400 Bad Request - Validation Tests ==========

    @Test
    fun `updatePosition with non-TODO status returns 400`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "In Progress Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.IN_PROGRESS
            )
        )

        val json = """["${saved.id}"]"""

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/position")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `updatePositionsByStatus with status mismatch returns 400`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.TODO
            )
        )

        val json = """{"status": "IN_PROGRESS", "orderedIds": ["${saved.id}"]}"""

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/positions")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `getByStatus with invalid status returns 400`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos/status/{status}", "INVALID_STATUS")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `changeStatus with invalid status returns 400`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.TODO
            )
        )

        val json = """{"status": "INVALID_STATUS", "position": 0}"""

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/{id}/status", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }

    // ========== Edge Case Tests ==========

    @Test
    fun `todoList returns empty array when no todos`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").isArray)
            .andExpect(jsonPath("$.length()").value(0))
    }

    @Test
    fun `completedTodoList returns empty array when no completed todos`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos/completed")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").isArray)
            .andExpect(jsonPath("$.length()").value(0))
    }

    @Test
    fun `getBoard returns empty lists when no todos`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos/board")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.todo").isArray)
            .andExpect(jsonPath("$.todo.length()").value(0))
            .andExpect(jsonPath("$.inProgress").isArray)
            .andExpect(jsonPath("$.inProgress.length()").value(0))
            .andExpect(jsonPath("$.done").isArray)
            .andExpect(jsonPath("$.done.length()").value(0))
            .andExpect(jsonPath("$.counts.total").value(0))
    }

    @Test
    fun `getOverdueTodos returns empty array when no overdue todos`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos/overdue")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").isArray)
            .andExpect(jsonPath("$.length()").value(0))
    }

    @Test
    fun `member can only see own todos in list`() {
        // Given: member1 creates a todo
        todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Member1 Todo",
                content = "Content",
                position = 0
            )
        )

        // When: member2 fetches todo list
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.length()").value(0))
    }

    @Test
    fun `member can only see own todos in board`() {
        // Given: member1 creates todos in all statuses
        todoRepository.saveAll(
            listOf(
                Todo(member = TestData.member, title = "Member1 Todo", content = "", position = 0, status = TodoStatus.TODO),
                Todo(member = TestData.member, title = "Member1 In Progress", content = "", position = 0, status = TodoStatus.IN_PROGRESS),
                Todo(member = TestData.member, title = "Member1 Done", content = "", position = 0, status = TodoStatus.DONE)
            )
        )

        // When: member2 fetches board
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/todos/board")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.counts.total").value(0))
    }

    @Test
    fun `changeStatus from TODO to DONE sets completedDate`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.TODO
            )
        )

        val json = """{"status": "DONE", "orderedIds": ["${saved.id}"]}"""

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/{id}/status", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("DONE"))
            .andExpect(jsonPath("$.completedDate").isNotEmpty)
    }

    @Test
    fun `changeStatus from DONE to TODO clears completedDate`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.DONE
            ).apply { markCompleted(0) }
        )

        val json = """{"status": "TODO", "orderedIds": ["${saved.id}"]}"""

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/{id}/status", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("TODO"))
            .andExpect(jsonPath("$.completedDate").isEmpty)
    }

    @Test
    fun `changeStatus to same status reorders positions`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 5,
                status = TodoStatus.IN_PROGRESS
            )
        )

        val json = """{"status": "IN_PROGRESS", "orderedIds": ["${saved.id}"]}"""

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/todos/{id}/status", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
            .andExpect(jsonPath("$.position").value(0))
    }

    @Test
    fun `addTodo with dueDate sets dueDate correctly`() {
        val json = """
            {
                "title": "Todo with due date",
                "content": "Content",
                "dueDate": "2025-06-15"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/todos")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.dueDate").value("2025-06-15"))
    }

    @Test
    fun `editTodo can update dueDate`() {
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
                "content": "Updated Content",
                "dueDate": "2025-12-25"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.dueDate").value("2025-12-25"))
    }

    @Test
    fun `editTodo can clear dueDate`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 1
            ).apply { dueDate = java.time.LocalDate.of(2025, 6, 15) }
        )

        val json = """
            {
                "title": "Updated Todo",
                "content": "Updated Content",
                "dueDate": null
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.dueDate").isEmpty)
    }

    // ========== addTodo with Status Tests ==========

    @Test
    fun `addTodo with IN_PROGRESS status creates todo in IN_PROGRESS`() {
        val json = """
            {
                "title": "In Progress Todo",
                "content": "Content",
                "status": "IN_PROGRESS"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/todos")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.title").value("In Progress Todo"))
            .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
            .andExpect(jsonPath("$.completedDate").isEmpty)
    }

    @Test
    fun `addTodo with DONE status creates todo with completedDate`() {
        val json = """
            {
                "title": "Completed Todo",
                "content": "Content",
                "status": "DONE"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/todos")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.title").value("Completed Todo"))
            .andExpect(jsonPath("$.status").value("DONE"))
            .andExpect(jsonPath("$.completedDate").isNotEmpty)
    }

    @Test
    fun `addTodo without status defaults to TODO`() {
        val json = """
            {
                "title": "Default Status Todo",
                "content": "Content"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/todos")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("TODO"))
    }

    @Test
    fun `addTodo with status and dueDate`() {
        val json = """
            {
                "title": "Scheduled In Progress",
                "content": "Content",
                "status": "IN_PROGRESS",
                "dueDate": "2025-12-31"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/todos")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
            .andExpect(jsonPath("$.dueDate").value("2025-12-31"))
    }

    // ========== editTodo with Status Change Tests ==========

    @Test
    fun `editTodo with status change from TODO to IN_PROGRESS`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.TODO
            )
        )

        val json = """
            {
                "title": "Updated Todo",
                "content": "Updated Content",
                "status": "IN_PROGRESS"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
            .andExpect(jsonPath("$.completedDate").isEmpty)
    }

    @Test
    fun `editTodo with status change from TODO to DONE sets completedDate`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.TODO
            )
        )

        val json = """
            {
                "title": "Completed Todo",
                "content": "Content",
                "status": "DONE"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("DONE"))
            .andExpect(jsonPath("$.completedDate").isNotEmpty)
    }

    @Test
    fun `editTodo with status change from DONE to TODO clears completedDate`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Completed Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.DONE
            ).apply { markCompleted(0) }
        )

        val json = """
            {
                "title": "Reopened Todo",
                "content": "Content",
                "status": "TODO"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("TODO"))
            .andExpect(jsonPath("$.completedDate").isEmpty)
    }

    @Test
    fun `editTodo with status change from DONE to IN_PROGRESS clears completedDate`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Completed Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.DONE
            ).apply { markCompleted(0) }
        )

        val json = """
            {
                "title": "In Progress Todo",
                "content": "Content",
                "status": "IN_PROGRESS"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
            .andExpect(jsonPath("$.completedDate").isEmpty)
    }

    @Test
    fun `editTodo with status change from IN_PROGRESS to DONE sets completedDate`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "In Progress Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.IN_PROGRESS
            )
        )

        val json = """
            {
                "title": "Completed Todo",
                "content": "Content",
                "status": "DONE"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("DONE"))
            .andExpect(jsonPath("$.completedDate").isNotEmpty)
    }

    @Test
    fun `editTodo without status does not change existing status`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "In Progress Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.IN_PROGRESS
            )
        )

        val json = """
            {
                "title": "Updated Title",
                "content": "Updated Content"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.title").value("Updated Title"))
            .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
    }

    @Test
    fun `editTodo with same status does not change position`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "In Progress Todo",
                content = "Content",
                position = 5,
                status = TodoStatus.IN_PROGRESS
            )
        )

        val json = """
            {
                "title": "Updated Title",
                "content": "Updated Content",
                "status": "IN_PROGRESS"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
            .andExpect(jsonPath("$.position").value(5))
    }

    @Test
    fun `editTodo with status and dueDate together`() {
        val saved = todoRepository.save(
            Todo(
                member = TestData.member,
                title = "Todo",
                content = "Content",
                position = 0,
                status = TodoStatus.TODO
            )
        )

        val json = """
            {
                "title": "Updated Todo",
                "content": "Updated Content",
                "status": "IN_PROGRESS",
                "dueDate": "2025-12-31"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/todos/{id}", saved.id)
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
            .andExpect(jsonPath("$.dueDate").value("2025-12-31"))
    }

}
