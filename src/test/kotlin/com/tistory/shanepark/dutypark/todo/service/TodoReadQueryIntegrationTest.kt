package com.tistory.shanepark.dutypark.todo.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoResponse
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.SoftAssertions
import org.hibernate.SessionFactory
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.time.LocalDate
import java.util.UUID

class TodoReadQueryIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    private lateinit var todoService: TodoService

    @Autowired
    private lateinit var todoRepository: TodoRepository

    @Autowired
    private lateinit var attachmentRepository: AttachmentRepository

    @Test
    fun `list endpoints preserve attachment flags with a constant query count`() {
        val viewer = memberRepository.save(Member("viewer", "viewer@query.test", "password"))
        val other = memberRepository.save(Member("other", "other@query.test", "password"))
        val dueDate = LocalDate.now().minusDays(1)
        val deletedAttachments = mutableListOf<Attachment>()
        val todos = TodoStatus.entries.flatMap { status ->
            (0 until 30).map { index ->
                val owner = if (index % 2 == 0) viewer else other
                todoRepository.save(
                    Todo(owner, "$status-$index", "content-$index", index, status, dueDate = dueDate)
                        .apply {
                            if (owner == other) {
                                addTag(viewer)
                                tags.single().tagOrder = index
                            }
                        }
                ).also { todo ->
                    when (index % 3) {
                        0 -> repeat(2) { saveAttachment(todo.id.toString(), viewer.id!!, AttachmentContextType.TODO) }
                        1 -> saveAttachment(todo.id.toString(), viewer.id!!, AttachmentContextType.SCHEDULE)
                        2 -> {
                            deletedAttachments.add(saveAttachment(todo.id.toString(), viewer.id!!, AttachmentContextType.TODO))
                        }
                    }
                }
            }
        }
        todoRepository.save(Todo(other, "not shared", "hidden", 0, dueDate = dueDate))
        saveAttachment(null, viewer.id!!, AttachmentContextType.TODO)
        em.flush()
        attachmentRepository.deleteAll(deletedAttachments)
        em.flush()
        em.clear()

        val expected = todoRepository.findAccessibleTodos(viewer).associate { todo ->
            todo.id.toString() to TodoResponse.from(todo, viewer, todo.title.substringAfterLast('-').toInt() % 3 == 0)
        }
        val login = loginMember(viewer)
        val endpoints = linkedMapOf<String, Pair<Int, () -> List<TodoResponse>>>(
            "board" to (90 to { todoService.getBoard(login).let { it.todo + it.inProgress + it.done } }),
            "todoList" to (30 to { todoService.todoList(login) }),
            "completedTodoList" to (30 to { todoService.completedTodoList(login) }),
            "status" to (30 to { todoService.getByStatus(login, TodoStatus.IN_PROGRESS) }),
            "month" to (90 to { todoService.getTodosByMonth(login, dueDate.year, dueDate.monthValue) }),
            "date" to (90 to { todoService.getTodosByDate(login, dueDate) }),
            "overdue" to (60 to { todoService.getOverdueTodos(login) }),
        )
        val statistics = em.entityManagerFactory.unwrap(SessionFactory::class.java).statistics
        val previouslyEnabled = statistics.isStatisticsEnabled
        statistics.isStatisticsEnabled = true
        val softly = SoftAssertions()
        try {
            endpoints.forEach { (name, request) ->
                em.clear()
                statistics.clear()
                val response = request.second()
                val queries = statistics.prepareStatementCount
                println("PERF todo-read endpoint=$name rows=${response.size} statements=$queries")

                softly.assertThat(response).describedAs("%s response size", name).hasSize(request.first)
                response.forEach { dto ->
                    softly.assertThat(dto).describedAs("%s response %s", name, dto.title).isEqualTo(expected.getValue(dto.id))
                }
                softly.assertThat(queries).describedAs("%s query count", name).isEqualTo(3)
            }
            softly.assertAll()
        } finally {
            statistics.isStatisticsEnabled = previouslyEnabled
        }
        assertThat(todos).hasSize(90)
    }

    @Test
    fun `empty board does not query attachments`() {
        val viewer = memberRepository.save(Member("empty", "empty@query.test", "password"))
        em.flush()
        em.clear()
        val statistics = em.entityManagerFactory.unwrap(SessionFactory::class.java).statistics
        val previouslyEnabled = statistics.isStatisticsEnabled
        statistics.isStatisticsEnabled = true
        try {
            statistics.clear()
            val response = todoService.getBoard(loginMember(viewer))
            assertThat(response.counts.total).isZero()
            assertThat(statistics.prepareStatementCount).isEqualTo(2)
        } finally {
            statistics.isStatisticsEnabled = previouslyEnabled
        }
    }

    private fun saveAttachment(contextId: String?, ownerId: Long, contextType: AttachmentContextType): Attachment =
        attachmentRepository.save(
            Attachment(
                contextType = contextType,
                contextId = contextId,
                uploadSessionId = if (contextId == null) UUID.randomUUID() else null,
                originalFilename = "test.txt",
                storedFilename = "test.txt",
                contentType = "text/plain",
                size = 1,
                storagePath = "query-test",
                createdBy = ownerId,
            )
        )
}
