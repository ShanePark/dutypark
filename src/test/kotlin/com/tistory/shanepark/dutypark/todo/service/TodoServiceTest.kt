package com.tistory.shanepark.dutypark.todo.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.dto.AttachmentDto
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.ArgumentMatchers.any
import org.mockito.Mockito.*
import org.springframework.test.util.ReflectionTestUtils
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.*

class TodoServiceTest {

    private lateinit var todoService: TodoService
    private lateinit var memberRepository: MemberRepository
    private lateinit var todoRepository: TodoRepository
    private lateinit var attachmentService: AttachmentService

    private val loginMember = LoginMember(id = 1, email = "", name = "", team = "", isAdmin = false)
    private val member = Member(name = "", password = "")

    @BeforeEach
    fun setUp() {
        memberRepository = mock(MemberRepository::class.java)
        todoRepository = mock(TodoRepository::class.java)
        attachmentService = mock(AttachmentService::class.java)
        todoService = TodoService(memberRepository, todoRepository, attachmentService)
    }

    @Test
    fun `addTodo should save and return TodoResponse`() {
        // Given
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.TODO)).thenReturn(0)

        val todo = Todo(member, "title", "content", 1)
        `when`(todoRepository.save(any(Todo::class.java))).thenReturn(todo)

        // When
        val response = todoService.addTodo(loginMember, "title", "content")

        // Then
        assertEquals("title", response.title)
        assertEquals("content", response.content)
        verify(todoRepository, times(1)).save(any(Todo::class.java))
    }

    @Test
    fun `editTodo should update and return TodoResponse`() {
        // Given
        val todoId = UUID.randomUUID()
        val todo = Todo(member, "old title", "old content", 1)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        // When
        val updatedResponse = todoService.editTodo(loginMember, todoId, "new title", "new content")

        // Then
        assertEquals("new title", updatedResponse.title)
        assertEquals("new content", updatedResponse.content)
        verify(todoRepository, times(1)).findById(todoId)
    }

    @Test
    fun `editTodo should throw exception if not owner`() {
        // Given
        val todoId = UUID.randomUUID()
        val otherMember = otherMember()
        val todo = Todo(otherMember, "old title", "old content", 1)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        // When & Then
        val exception = assertThrows<IllegalArgumentException> {
            todoService.editTodo(loginMember, todoId, "new title", "new content")
        }
        assertEquals("Todo is not yours", exception.message)
    }

    @Test
    fun `deleteTodoById should delete the todo if owner`() {
        // Given
        val todoId = UUID.randomUUID()
        val todo = Todo(member, "title", "content", 1)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        // When
        todoService.deleteTodo(loginMember, todoId)

        // Then
        verify(todoRepository, times(1)).delete(todo)
    }

    @Test
    fun `deleteTodoById should throw exception if not owner`() {
        // Given
        val todoId = UUID.randomUUID()
        val otherMember = otherMember()
        val todo = Todo(otherMember, "title", "content", 1)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        // When & Then
        val exception = assertThrows<IllegalArgumentException> {
            todoService.deleteTodo(loginMember, todoId)
        }
        assertEquals("Todo is not yours", exception.message)
    }

    @Test
    fun `todoList should return list of TodoResponse`() {
        // Given
        `when`(
            memberRepository.findById(
                loginMember
                    .id
            )
        ).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberAndStatusOrderByPosition(member, TodoStatus.TODO)).thenReturn(
            listOf(
                Todo(member, "title1", "content1", 1),
                Todo(member, "title2", "content2", 2)
            )
        )

        // When
        val response = todoService.todoList(loginMember)

        // Then
        assertEquals(2, response.size)
        assertEquals("title1", response[0].title)
        assertEquals("content1", response[0].content)
        assertEquals("title2", response[1].title)
        assertEquals("content2", response[1].content)
    }

    @Test
    fun `updatePosition should update positions of todos correctly`() {
        // Given
        val todos = listOf(
            Todo(member, "title1", "content1", 1),
            Todo(member, "title2", "content2", 2),
            Todo(member, "title3", "content3", 3)
        )
        val todoIds = todos.map { it.id }

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllById(todoIds)).thenReturn(todos)

        // When
        val reverse = todoIds.reversed()
        todoService.updatePosition(loginMember, reverse)

        // Verify
        verify(todoRepository, times(1)).findAllById(reverse)
        verifyNoMoreInteractions(todoRepository)
    }

    @Test
    fun `completedTodoList should return completed todos`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        val completedTodo = Todo(member, "title", "content", 0, TodoStatus.DONE)
        `when`(
            todoRepository.findAllByMemberAndStatusOrderByCompletedDateDesc(member, TodoStatus.DONE)
        ).thenReturn(listOf(completedTodo))

        val response = todoService.completedTodoList(loginMember)

        assertEquals(1, response.size)
        assertEquals(TodoStatus.DONE, response.first().status)
    }

    @Test
    fun `completeTodo should mark todo as completed with position`() {
        val todoId = UUID.randomUUID()
        val todo = Todo(member, "title", "content", 1)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.DONE)).thenReturn(0)

        val response = todoService.completeTodo(loginMember, todoId)

        assertEquals(TodoStatus.DONE, response.status)
        assertEquals(-1, response.position)
    }

    @Test
    fun `reopenTodo should mark todo as active`() {
        val todoId = UUID.randomUUID()
        val todo = Todo(member, "title", "content", 0)
        todo.markCompleted(0)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.TODO)).thenReturn(0)

        val response = todoService.reopenTodo(loginMember, todoId)

        assertEquals(TodoStatus.TODO, response.status)
        assertNull(response.completedDate)
    }

    @Test
    fun `addTodo should finalize attachment session when attachmentSessionId is provided`() {
        val sessionId = UUID.randomUUID()
        val orderedAttachmentIds = listOf(UUID.randomUUID(), UUID.randomUUID())
        val todoId = UUID.randomUUID()

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.TODO)).thenReturn(0)
        `when`(todoRepository.save(any(Todo::class.java))).thenAnswer { invocation ->
            val savedTodo = invocation.getArgument<Todo>(0)
            ReflectionTestUtils.setField(savedTodo, "id", todoId)
            savedTodo
        }

        todoService.addTodo(
            loginMember = loginMember,
            title = "title",
            content = "content",
            status = null,
            dueDate = null,
            attachmentSessionId = sessionId,
            orderedAttachmentIds = orderedAttachmentIds
        )

        verify(attachmentService, times(1)).synchronizeContextAttachments(
            loginMember = loginMember,
            contextType = AttachmentContextType.TODO,
            contextId = todoId.toString(),
            attachmentSessionId = sessionId,
            orderedAttachmentIds = orderedAttachmentIds
        )
    }

    @Test
    fun `editTodo should reorder attachments when only ordered ids are provided`() {
        val todoId = UUID.randomUUID()
        val todo = Todo(member, "old", "content", 1)
        ReflectionTestUtils.setField(todo, "id", todoId)
        val orderedAttachmentIds = listOf(UUID.randomUUID(), UUID.randomUUID())

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        todoService.editTodo(
            loginMember = loginMember,
            id = todoId,
            title = "new title",
            content = "new content",
            status = null,
            dueDate = null,
            attachmentSessionId = null,
            orderedAttachmentIds = orderedAttachmentIds
        )

        verify(attachmentService, times(1)).synchronizeContextAttachments(
            loginMember = loginMember,
            contextType = AttachmentContextType.TODO,
            contextId = todoId.toString(),
            attachmentSessionId = null,
            orderedAttachmentIds = orderedAttachmentIds
        )
    }

    @Test
    fun `deleteTodo should remove attachments before deleting entity`() {
        val todoId = UUID.randomUUID()
        val todo = Todo(member, "title", "content", 1)
        ReflectionTestUtils.setField(todo, "id", todoId)
        val attachments = listOf(
            createAttachmentDto(UUID.randomUUID()),
            createAttachmentDto(UUID.randomUUID())
        )

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(attachmentService.listAttachments(loginMember, AttachmentContextType.TODO, todoId.toString()))
            .thenReturn(attachments)

        todoService.deleteTodo(loginMember, todoId)

        attachments.forEach { attachment ->
            verify(attachmentService, times(1)).deleteAttachment(loginMember, attachment.id)
        }
        verify(todoRepository, times(1)).delete(todo)
    }

    @Test
    fun `editTodo should not interact with attachments when user is not owner`() {
        val todoId = UUID.randomUUID()
        val otherMember = otherMember()
        val todo = Todo(otherMember, "title", "content", 1)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        assertThrows<IllegalArgumentException> {
            todoService.editTodo(
                loginMember = loginMember,
                id = todoId,
                title = "new title",
                content = "new content",
                status = null,
                dueDate = null,
                attachmentSessionId = UUID.randomUUID(),
                orderedAttachmentIds = listOf(UUID.randomUUID())
            )
        }
        verifyNoInteractions(attachmentService)
    }

    private fun otherMember(): Member {
        val member = Member(name = "", password = "")
        ReflectionTestUtils.setField(member, "id", 2L)
        return member
    }

    private fun createAttachmentDto(id: UUID): AttachmentDto {
        return AttachmentDto(
            id = id,
            contextType = AttachmentContextType.TODO,
            contextId = UUID.randomUUID().toString(),
            originalFilename = "file_$id.jpg",
            contentType = "image/jpeg",
            size = 1024L,
            hasThumbnail = false,
            thumbnailUrl = null,
            orderIndex = 0,
            createdAt = ZonedDateTime.of(2024, 1, 1, 0, 0, 0, 0, ZoneId.systemDefault()),
            createdBy = loginMember.id
        )
    }

    // ========== getBoard Tests ==========

    @Test
    fun `getBoard should return empty board when no todos exist`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberOrderByStatusAscPositionAsc(member)).thenReturn(emptyList())

        val board = todoService.getBoard(loginMember)

        assertEquals(0, board.todo.size)
        assertEquals(0, board.inProgress.size)
        assertEquals(0, board.done.size)
        assertEquals(0, board.counts.total)
    }

    @Test
    fun `getBoard should correctly partition todos by status`() {
        val todoItem = createTodo("todo task", TodoStatus.TODO, 0)
        val inProgressItem = createTodo("in progress task", TodoStatus.IN_PROGRESS, 0)
        val doneItem = createTodo("done task", TodoStatus.DONE, 0)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberOrderByStatusAscPositionAsc(member))
            .thenReturn(listOf(todoItem, inProgressItem, doneItem))

        val board = todoService.getBoard(loginMember)

        assertEquals(1, board.todo.size)
        assertEquals(1, board.inProgress.size)
        assertEquals(1, board.done.size)
        assertEquals(3, board.counts.total)
        assertEquals("todo task", board.todo[0].title)
        assertEquals("in progress task", board.inProgress[0].title)
        assertEquals("done task", board.done[0].title)
    }

    @Test
    fun `getBoard should sort todos by position within each status`() {
        val todo1 = createTodo("second", TodoStatus.TODO, 1)
        val todo2 = createTodo("first", TodoStatus.TODO, 0)
        val todo3 = createTodo("third", TodoStatus.TODO, 2)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberOrderByStatusAscPositionAsc(member))
            .thenReturn(listOf(todo1, todo2, todo3))

        val board = todoService.getBoard(loginMember)

        assertEquals(3, board.todo.size)
        assertEquals("first", board.todo[0].title)
        assertEquals("second", board.todo[1].title)
        assertEquals("third", board.todo[2].title)
    }

    @Test
    fun `getBoard should include hasAttachments flag`() {
        val todoItem = createTodo("task with attachment", TodoStatus.TODO, 0)
        ReflectionTestUtils.setField(todoItem, "id", UUID.randomUUID())

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberOrderByStatusAscPositionAsc(member)).thenReturn(listOf(todoItem))
        `when`(attachmentService.hasAttachments(AttachmentContextType.TODO, todoItem.id.toString())).thenReturn(true)

        val board = todoService.getBoard(loginMember)

        assertEquals(true, board.todo[0].hasAttachments)
    }

    // ========== getByStatus Tests ==========

    @Test
    fun `getByStatus should return only todos with specified status`() {
        val todo1 = createTodo("todo1", TodoStatus.TODO, 0)
        val todo2 = createTodo("todo2", TodoStatus.TODO, 1)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberAndStatusOrderByPositionAsc(member, TodoStatus.TODO))
            .thenReturn(listOf(todo1, todo2))

        val result = todoService.getByStatus(loginMember, TodoStatus.TODO)

        assertEquals(2, result.size)
        assertEquals(TodoStatus.TODO, result[0].status)
        assertEquals(TodoStatus.TODO, result[1].status)
    }

    @Test
    fun `getByStatus should return empty list when no todos with status exist`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberAndStatusOrderByPositionAsc(member, TodoStatus.IN_PROGRESS))
            .thenReturn(emptyList())

        val result = todoService.getByStatus(loginMember, TodoStatus.IN_PROGRESS)

        assertEquals(0, result.size)
    }

    // ========== changeStatus Tests - All 6 Transitions ==========

    @Test
    fun `changeStatus TODO to IN_PROGRESS should update status and position`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("task", TodoStatus.TODO, 0)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findAllById(listOf(todoId))).thenReturn(listOf(todo))

        val result = todoService.changeStatus(loginMember, todoId, TodoStatus.IN_PROGRESS, listOf(todoId))

        assertEquals(TodoStatus.IN_PROGRESS, result.status)
        assertEquals(0, result.position)
        assertNull(result.completedDate)
    }

    @Test
    fun `changeStatus TODO to DONE should set completedDate`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("task", TodoStatus.TODO, 0)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findAllById(listOf(todoId))).thenReturn(listOf(todo))

        val result = todoService.changeStatus(loginMember, todoId, TodoStatus.DONE, listOf(todoId))

        assertEquals(TodoStatus.DONE, result.status)
        assertNotNull(result.completedDate)
    }

    @Test
    fun `changeStatus IN_PROGRESS to TODO should update status`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("task", TodoStatus.IN_PROGRESS, 0)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findAllById(listOf(todoId))).thenReturn(listOf(todo))

        val result = todoService.changeStatus(loginMember, todoId, TodoStatus.TODO, listOf(todoId))

        assertEquals(TodoStatus.TODO, result.status)
        assertNull(result.completedDate)
    }

    @Test
    fun `changeStatus IN_PROGRESS to DONE should set completedDate`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("task", TodoStatus.IN_PROGRESS, 0)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findAllById(listOf(todoId))).thenReturn(listOf(todo))

        val result = todoService.changeStatus(loginMember, todoId, TodoStatus.DONE, listOf(todoId))

        assertEquals(TodoStatus.DONE, result.status)
        assertNotNull(result.completedDate)
    }

    @Test
    fun `changeStatus DONE to TODO should clear completedDate`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("task", TodoStatus.DONE, 0)
        todo.markCompleted(0)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findAllById(listOf(todoId))).thenReturn(listOf(todo))

        assertNotNull(todo.completedDate)

        val result = todoService.changeStatus(loginMember, todoId, TodoStatus.TODO, listOf(todoId))

        assertEquals(TodoStatus.TODO, result.status)
        assertNull(result.completedDate)
    }

    @Test
    fun `changeStatus DONE to IN_PROGRESS should clear completedDate`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("task", TodoStatus.DONE, 0)
        todo.markCompleted(0)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findAllById(listOf(todoId))).thenReturn(listOf(todo))

        val result = todoService.changeStatus(loginMember, todoId, TodoStatus.IN_PROGRESS, listOf(todoId))

        assertEquals(TodoStatus.IN_PROGRESS, result.status)
        assertNull(result.completedDate)
    }

    @Test
    fun `changeStatus with same status should reorder positions`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("task", TodoStatus.TODO, 5)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findAllById(listOf(todoId))).thenReturn(listOf(todo))

        val result = todoService.changeStatus(loginMember, todoId, TodoStatus.TODO, listOf(todoId))

        assertEquals(TodoStatus.TODO, result.status)
        assertEquals(0, result.position)
    }

    @Test
    fun `changeStatus with multiple items should reorder all positions`() {
        val todoId1 = UUID.randomUUID()
        val todoId2 = UUID.randomUUID()
        val todoId3 = UUID.randomUUID()
        val todo1 = createTodo("task1", TodoStatus.TODO, 5)
        val todo2 = createTodo("task2", TodoStatus.IN_PROGRESS, 0)
        val todo3 = createTodo("task3", TodoStatus.TODO, 10)
        ReflectionTestUtils.setField(todo1, "id", todoId1)
        ReflectionTestUtils.setField(todo2, "id", todoId2)
        ReflectionTestUtils.setField(todo3, "id", todoId3)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId2)).thenReturn(Optional.of(todo2))
        `when`(todoRepository.findAllById(listOf(todoId1, todoId2, todoId3))).thenReturn(listOf(todo1, todo2, todo3))

        val result = todoService.changeStatus(loginMember, todoId2, TodoStatus.TODO, listOf(todoId1, todoId2, todoId3))

        assertEquals(TodoStatus.TODO, result.status)
        assertEquals(0, todo1.position)
        assertEquals(1, todo2.position)
        assertEquals(2, todo3.position)
    }

    @Test
    fun `changeStatus should throw exception if not owner`() {
        val todoId = UUID.randomUUID()
        val otherMember = otherMember()
        val todo = createTodo("task", TodoStatus.TODO, 0)
        ReflectionTestUtils.setField(todo, "id", todoId)
        ReflectionTestUtils.setField(todo, "member", otherMember)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        val exception = assertThrows<IllegalArgumentException> {
            todoService.changeStatus(loginMember, todoId, TodoStatus.IN_PROGRESS, listOf(todoId))
        }
        assertEquals("Todo is not yours", exception.message)
    }

    @Test
    fun `changeStatus should throw exception if todo not found`() {
        val todoId = UUID.randomUUID()

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.empty())

        assertThrows<IllegalArgumentException> {
            todoService.changeStatus(loginMember, todoId, TodoStatus.IN_PROGRESS, listOf(todoId))
        }
    }

    @Test
    fun `changeStatus should throw exception if orderedIds contains todo with different status`() {
        val todoId1 = UUID.randomUUID()
        val todoId2 = UUID.randomUUID()
        val todo1 = createTodo("task1", TodoStatus.IN_PROGRESS, 0)
        val todo2 = createTodo("task2", TodoStatus.TODO, 0)  // Different status
        ReflectionTestUtils.setField(todo1, "id", todoId1)
        ReflectionTestUtils.setField(todo2, "id", todoId2)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId1)).thenReturn(Optional.of(todo1))
        `when`(todoRepository.findAllById(listOf(todoId1, todoId2))).thenReturn(listOf(todo1, todo2))

        val exception = assertThrows<IllegalArgumentException> {
            todoService.changeStatus(loginMember, todoId1, TodoStatus.IN_PROGRESS, listOf(todoId1, todoId2))
        }
        assertTrue(exception.message?.contains("is not in IN_PROGRESS status") == true)
    }

    @Test
    fun `changeStatus should throw exception if orderedIds contains other users todo`() {
        val todoId1 = UUID.randomUUID()
        val todoId2 = UUID.randomUUID()
        val otherUser = otherMember()
        val todo1 = createTodo("task1", TodoStatus.IN_PROGRESS, 0)
        val todo2 = createTodo("task2", TodoStatus.IN_PROGRESS, 1)
        ReflectionTestUtils.setField(todo1, "id", todoId1)
        ReflectionTestUtils.setField(todo2, "id", todoId2)
        ReflectionTestUtils.setField(todo2, "member", otherUser)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId1)).thenReturn(Optional.of(todo1))
        `when`(todoRepository.findAllById(listOf(todoId1, todoId2))).thenReturn(listOf(todo1, todo2))

        val exception = assertThrows<IllegalArgumentException> {
            todoService.changeStatus(loginMember, todoId1, TodoStatus.IN_PROGRESS, listOf(todoId1, todoId2))
        }
        assertEquals("Todo is not yours", exception.message)
    }

    @Test
    fun `changeStatus with empty orderedIds should still change status`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("task", TodoStatus.TODO, 5)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findAllById(emptyList<UUID>())).thenReturn(emptyList())

        val result = todoService.changeStatus(loginMember, todoId, TodoStatus.IN_PROGRESS, emptyList())

        assertEquals(TodoStatus.IN_PROGRESS, result.status)
        assertEquals(0, result.position)
    }

    @Test
    fun `changeStatus should correctly insert todo in middle position`() {
        val todoId1 = UUID.randomUUID()
        val todoId2 = UUID.randomUUID()
        val todoId3 = UUID.randomUUID()
        val todo1 = createTodo("existing1", TodoStatus.TODO, 0)
        val todo2 = createTodo("moving", TodoStatus.IN_PROGRESS, 0)
        val todo3 = createTodo("existing2", TodoStatus.TODO, 1)
        ReflectionTestUtils.setField(todo1, "id", todoId1)
        ReflectionTestUtils.setField(todo2, "id", todoId2)
        ReflectionTestUtils.setField(todo3, "id", todoId3)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId2)).thenReturn(Optional.of(todo2))
        `when`(todoRepository.findAllById(listOf(todoId1, todoId2, todoId3))).thenReturn(listOf(todo1, todo2, todo3))

        // Move todo2 (IN_PROGRESS) to TODO, placing it between todo1 and todo3
        val result = todoService.changeStatus(loginMember, todoId2, TodoStatus.TODO, listOf(todoId1, todoId2, todoId3))

        assertEquals(TodoStatus.TODO, result.status)
        assertEquals(0, todo1.position)
        assertEquals(1, todo2.position)
        assertEquals(2, todo3.position)
    }

    // ========== updatePositionsByStatus Tests ==========

    @Test
    fun `updatePositionsByStatus should update positions correctly`() {
        val todo1 = createTodo("task1", TodoStatus.IN_PROGRESS, 0)
        val todo2 = createTodo("task2", TodoStatus.IN_PROGRESS, 1)
        val todo3 = createTodo("task3", TodoStatus.IN_PROGRESS, 2)
        val id1 = UUID.randomUUID()
        val id2 = UUID.randomUUID()
        val id3 = UUID.randomUUID()
        ReflectionTestUtils.setField(todo1, "id", id1)
        ReflectionTestUtils.setField(todo2, "id", id2)
        ReflectionTestUtils.setField(todo3, "id", id3)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllById(listOf(id3, id1, id2))).thenReturn(listOf(todo1, todo2, todo3))

        todoService.updatePositionsByStatus(loginMember, TodoStatus.IN_PROGRESS, listOf(id3, id1, id2))

        assertEquals(1, todo1.position)
        assertEquals(2, todo2.position)
        assertEquals(0, todo3.position)
    }

    @Test
    fun `updatePositionsByStatus should throw exception for wrong status`() {
        val todo = createTodo("task", TodoStatus.TODO, 0)
        val todoId = UUID.randomUUID()
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllById(listOf(todoId))).thenReturn(listOf(todo))

        val exception = assertThrows<IllegalArgumentException> {
            todoService.updatePositionsByStatus(loginMember, TodoStatus.IN_PROGRESS, listOf(todoId))
        }
        assertEquals("Todo $todoId is not in IN_PROGRESS status", exception.message)
    }

    @Test
    fun `updatePositionsByStatus should throw exception if not owner`() {
        val otherMember = otherMember()
        val todo = createTodo("task", TodoStatus.TODO, 0)
        val todoId = UUID.randomUUID()
        ReflectionTestUtils.setField(todo, "id", todoId)
        ReflectionTestUtils.setField(todo, "member", otherMember)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllById(listOf(todoId))).thenReturn(listOf(todo))

        val exception = assertThrows<IllegalArgumentException> {
            todoService.updatePositionsByStatus(loginMember, TodoStatus.TODO, listOf(todoId))
        }
        assertEquals("Todo is not yours", exception.message)
    }

    // ========== completeTodo Edge Cases ==========

    @Test
    fun `completeTodo from IN_PROGRESS should set position and completedDate`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("task", TodoStatus.IN_PROGRESS, 5)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.DONE)).thenReturn(10)

        val result = todoService.completeTodo(loginMember, todoId)

        assertEquals(TodoStatus.DONE, result.status)
        assertEquals(9, result.position)
        assertNotNull(result.completedDate)
    }

    @Test
    fun `completeTodo already DONE should not change anything`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("task", TodoStatus.DONE, 0)
        todo.markCompleted(0)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        val result = todoService.completeTodo(loginMember, todoId)

        assertEquals(TodoStatus.DONE, result.status)
        assertEquals(0, result.position)
    }

    @Test
    fun `completeTodo should throw exception if not owner`() {
        val todoId = UUID.randomUUID()
        val otherMember = otherMember()
        val todo = createTodo("task", TodoStatus.TODO, 0)
        ReflectionTestUtils.setField(todo, "id", todoId)
        ReflectionTestUtils.setField(todo, "member", otherMember)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        val exception = assertThrows<IllegalArgumentException> {
            todoService.completeTodo(loginMember, todoId)
        }
        assertEquals("Todo is not yours", exception.message)
    }

    // ========== reopenTodo Edge Cases ==========

    @Test
    fun `reopenTodo should throw exception if not owner`() {
        val todoId = UUID.randomUUID()
        val otherMember = otherMember()
        val todo = createTodo("task", TodoStatus.DONE, 0)
        todo.markCompleted(0)
        ReflectionTestUtils.setField(todo, "id", todoId)
        ReflectionTestUtils.setField(todo, "member", otherMember)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        val exception = assertThrows<IllegalArgumentException> {
            todoService.reopenTodo(loginMember, todoId)
        }
        assertEquals("Todo is not yours", exception.message)
    }

    @Test
    fun `reopenTodo for non-DONE todo should not change status`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("task", TodoStatus.IN_PROGRESS, 5)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        val result = todoService.reopenTodo(loginMember, todoId)

        assertEquals(TodoStatus.IN_PROGRESS, result.status)
        assertEquals(5, result.position)
    }

    // ========== updatePosition Edge Cases ==========

    @Test
    fun `updatePosition should throw exception for non-TODO status`() {
        val todo = createTodo("task", TodoStatus.IN_PROGRESS, 0)
        val todoId = UUID.randomUUID()
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllById(listOf(todoId))).thenReturn(listOf(todo))

        val exception = assertThrows<IllegalArgumentException> {
            todoService.updatePosition(loginMember, listOf(todoId))
        }
        assertEquals("Cannot reorder non-TODO status todo", exception.message)
    }

    // ========== Due Date Tests ==========

    @Test
    fun `getTodosByMonth should return todos with due dates in specified month`() {
        val todo1 = createTodo("task1", TodoStatus.TODO, 0)
        val todo2 = createTodo("task2", TodoStatus.TODO, 1)
        todo1.dueDate = LocalDate.of(2024, 6, 15)
        todo2.dueDate = LocalDate.of(2024, 6, 20)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberAndDueDateBetweenOrderByDueDateAsc(
            member,
            LocalDate.of(2024, 6, 1),
            LocalDate.of(2024, 6, 30)
        )).thenReturn(listOf(todo1, todo2))

        val result = todoService.getTodosByMonth(loginMember, 2024, 6)

        assertEquals(2, result.size)
    }

    @Test
    fun `getTodosByDate should return todos with specific due date`() {
        val dueDate = LocalDate.of(2024, 6, 15)
        val todo = createTodo("task", TodoStatus.TODO, 0)
        todo.dueDate = dueDate

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberAndDueDateOrderByPositionAsc(member, dueDate))
            .thenReturn(listOf(todo))

        val result = todoService.getTodosByDate(loginMember, dueDate)

        assertEquals(1, result.size)
    }

    @Test
    fun `getOverdueTodos should return only overdue non-DONE todos`() {
        val overdueTodo = createTodo("overdue task", TodoStatus.TODO, 0)
        overdueTodo.dueDate = LocalDate.now().minusDays(1)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberAndDueDateLessThanAndStatusNot(
            member,
            LocalDate.now(),
            TodoStatus.DONE
        )).thenReturn(listOf(overdueTodo))

        val result = todoService.getOverdueTodos(loginMember)

        assertEquals(1, result.size)
        assertEquals("overdue task", result[0].title)
    }

    // ========== Empty List Edge Cases ==========

    @Test
    fun `todoList should return empty list when no todos exist`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberAndStatusOrderByPosition(member, TodoStatus.TODO))
            .thenReturn(emptyList())

        val result = todoService.todoList(loginMember)

        assertEquals(0, result.size)
    }

    @Test
    fun `completedTodoList should return empty list when no completed todos exist`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberAndStatusOrderByCompletedDateDesc(member, TodoStatus.DONE))
            .thenReturn(emptyList())

        val result = todoService.completedTodoList(loginMember)

        assertEquals(0, result.size)
    }

    @Test
    fun `getTodosByMonth should return empty list when no todos in month`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberAndDueDateBetweenOrderByDueDateAsc(
            member,
            LocalDate.of(2024, 6, 1),
            LocalDate.of(2024, 6, 30)
        )).thenReturn(emptyList())

        val result = todoService.getTodosByMonth(loginMember, 2024, 6)

        assertEquals(0, result.size)
    }

    @Test
    fun `getTodosByDate should return empty list when no todos on date`() {
        val date = LocalDate.of(2024, 6, 15)
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberAndDueDateOrderByPositionAsc(member, date))
            .thenReturn(emptyList())

        val result = todoService.getTodosByDate(loginMember, date)

        assertEquals(0, result.size)
    }

    @Test
    fun `getOverdueTodos should return empty list when no overdue todos`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberAndDueDateLessThanAndStatusNot(
            member,
            LocalDate.now(),
            TodoStatus.DONE
        )).thenReturn(emptyList())

        val result = todoService.getOverdueTodos(loginMember)

        assertEquals(0, result.size)
    }

    // ========== Not Found Edge Cases ==========

    @Test
    fun `editTodo should throw exception when todo not found`() {
        val todoId = UUID.randomUUID()

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.empty())

        val exception = assertThrows<IllegalArgumentException> {
            todoService.editTodo(loginMember, todoId, "new title", "new content")
        }
        assertEquals("Todo not found", exception.message)
    }

    @Test
    fun `deleteTodo should throw exception when todo not found`() {
        val todoId = UUID.randomUUID()

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.empty())

        val exception = assertThrows<IllegalArgumentException> {
            todoService.deleteTodo(loginMember, todoId)
        }
        assertEquals("Todo not found", exception.message)
    }

    @Test
    fun `reopenTodo should throw exception when todo not found`() {
        val todoId = UUID.randomUUID()

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.empty())

        assertThrows<IllegalArgumentException> {
            todoService.reopenTodo(loginMember, todoId)
        }
    }

    @Test
    fun `completeTodo should throw exception when todo not found`() {
        val todoId = UUID.randomUUID()

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.empty())

        assertThrows<IllegalArgumentException> {
            todoService.completeTodo(loginMember, todoId)
        }
    }

    // ========== Member Not Found Edge Cases ==========

    @Test
    fun `addTodo should throw exception when member not found`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.empty())

        assertThrows<IllegalArgumentException> {
            todoService.addTodo(loginMember, "title", "content")
        }
    }

    @Test
    fun `getBoard should throw exception when member not found`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.empty())

        assertThrows<IllegalArgumentException> {
            todoService.getBoard(loginMember)
        }
    }

    // ========== updatePosition Edge Cases ==========

    @Test
    fun `updatePosition with empty list should not throw exception`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllById(emptyList())).thenReturn(emptyList())

        todoService.updatePosition(loginMember, emptyList())

        verify(todoRepository).findAllById(emptyList())
    }

    @Test
    fun `updatePosition should throw exception if any todo not owned by member`() {
        val otherMember = otherMember()
        val todo1 = createTodo("task1", TodoStatus.TODO, 0)
        val todo2 = Todo(otherMember, "task2", "content", 1, TodoStatus.TODO)
        val id1 = UUID.randomUUID()
        val id2 = UUID.randomUUID()
        ReflectionTestUtils.setField(todo1, "id", id1)
        ReflectionTestUtils.setField(todo2, "id", id2)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllById(listOf(id1, id2))).thenReturn(listOf(todo1, todo2))

        val exception = assertThrows<IllegalArgumentException> {
            todoService.updatePosition(loginMember, listOf(id1, id2))
        }
        assertEquals("Todo is not yours", exception.message)
    }

    // ========== updatePositionsByStatus Edge Cases ==========

    @Test
    fun `updatePositionsByStatus with empty list should not throw exception`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllById(emptyList())).thenReturn(emptyList())

        todoService.updatePositionsByStatus(loginMember, TodoStatus.TODO, emptyList())

        verify(todoRepository).findAllById(emptyList())
    }

    @Test
    fun `updatePositionsByStatus should validate all todos match status`() {
        val todo1 = createTodo("task1", TodoStatus.IN_PROGRESS, 0)
        val todo2 = createTodo("task2", TodoStatus.TODO, 1)
        val id1 = UUID.randomUUID()
        val id2 = UUID.randomUUID()
        ReflectionTestUtils.setField(todo1, "id", id1)
        ReflectionTestUtils.setField(todo2, "id", id2)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllById(listOf(id1, id2))).thenReturn(listOf(todo1, todo2))

        val exception = assertThrows<IllegalArgumentException> {
            todoService.updatePositionsByStatus(loginMember, TodoStatus.IN_PROGRESS, listOf(id1, id2))
        }
        assertEquals("Todo $id2 is not in IN_PROGRESS status", exception.message)
    }

    // ========== addTodo Position Calculation ==========

    @Test
    fun `addTodo should calculate position as minPosition minus 1`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.TODO)).thenReturn(5)
        `when`(todoRepository.save(any(Todo::class.java))).thenAnswer { invocation ->
            val savedTodo = invocation.getArgument<Todo>(0)
            assertEquals(4, savedTodo.position)
            savedTodo
        }

        todoService.addTodo(loginMember, "new task", "content")

        verify(todoRepository).save(any(Todo::class.java))
    }

    @Test
    fun `addTodo should handle negative min position`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.TODO)).thenReturn(-5)
        `when`(todoRepository.save(any(Todo::class.java))).thenAnswer { invocation ->
            val savedTodo = invocation.getArgument<Todo>(0)
            assertEquals(-6, savedTodo.position)
            savedTodo
        }

        todoService.addTodo(loginMember, "new task", "content")

        verify(todoRepository).save(any(Todo::class.java))
    }

    // ========== addTodo with DueDate ==========

    @Test
    fun `addTodo should set dueDate when provided`() {
        val dueDate = LocalDate.of(2025, 12, 31)
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.TODO)).thenReturn(0)
        `when`(todoRepository.save(any(Todo::class.java))).thenAnswer { invocation ->
            val savedTodo = invocation.getArgument<Todo>(0)
            assertEquals(dueDate, savedTodo.dueDate)
            savedTodo
        }

        todoService.addTodo(
            loginMember = loginMember,
            title = "task with due date",
            content = "content",
            dueDate = dueDate
        )

        verify(todoRepository).save(any(Todo::class.java))
    }

    @Test
    fun `addTodo should allow null dueDate`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.TODO)).thenReturn(0)
        `when`(todoRepository.save(any(Todo::class.java))).thenAnswer { invocation ->
            val savedTodo = invocation.getArgument<Todo>(0)
            assertNull(savedTodo.dueDate)
            savedTodo
        }

        todoService.addTodo(
            loginMember = loginMember,
            title = "task without due date",
            content = "content",
            dueDate = null
        )

        verify(todoRepository).save(any(Todo::class.java))
    }

    // ========== editTodo Edge Cases ==========

    @Test
    fun `editTodo should update dueDate`() {
        val todoId = UUID.randomUUID()
        val newDueDate = LocalDate.of(2025, 12, 31)
        val todo = createTodo("old title", TodoStatus.TODO, 0)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        todoService.editTodo(
            loginMember = loginMember,
            id = todoId,
            title = "new title",
            content = "new content",
            dueDate = newDueDate
        )

        assertEquals(newDueDate, todo.dueDate)
    }

    @Test
    fun `editTodo should clear dueDate when null provided`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("title", TodoStatus.TODO, 0)
        todo.dueDate = LocalDate.of(2025, 6, 15)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        todoService.editTodo(
            loginMember = loginMember,
            id = todoId,
            title = "title",
            content = "content",
            dueDate = null
        )

        assertNull(todo.dueDate)
    }

    // ========== Board Counts Verification ==========

    @Test
    fun `getBoard counts should be accurate`() {
        val todos = listOf(
            createTodo("todo1", TodoStatus.TODO, 0),
            createTodo("todo2", TodoStatus.TODO, 1),
            createTodo("inProgress", TodoStatus.IN_PROGRESS, 0),
            createTodo("done1", TodoStatus.DONE, 0),
            createTodo("done2", TodoStatus.DONE, 1),
            createTodo("done3", TodoStatus.DONE, 2)
        )

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findAllByMemberOrderByStatusAscPositionAsc(member)).thenReturn(todos)

        val board = todoService.getBoard(loginMember)

        assertEquals(2, board.counts.todo)
        assertEquals(1, board.counts.inProgress)
        assertEquals(3, board.counts.done)
        assertEquals(6, board.counts.total)
    }

    // ========== Status Transition with completedDate ==========

    @Test
    fun `completeTodo should verify completedDate is set`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("task", TodoStatus.TODO, 0)
        ReflectionTestUtils.setField(todo, "id", todoId)
        assertNull(todo.completedDate)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.DONE)).thenReturn(0)

        todoService.completeTodo(loginMember, todoId)

        assertNotNull(todo.completedDate)
    }

    @Test
    fun `reopenTodo should clear completedDate`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("task", TodoStatus.DONE, 0)
        todo.markCompleted(0)
        ReflectionTestUtils.setField(todo, "id", todoId)
        assertNotNull(todo.completedDate)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.TODO)).thenReturn(0)

        todoService.reopenTodo(loginMember, todoId)

        assertNull(todo.completedDate)
    }

    // ========== addTodo with Status Tests ==========

    @Test
    fun `addTodo with IN_PROGRESS status should create todo in IN_PROGRESS`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.IN_PROGRESS)).thenReturn(0)
        `when`(todoRepository.save(any(Todo::class.java))).thenAnswer { invocation ->
            val savedTodo = invocation.getArgument<Todo>(0)
            assertEquals(TodoStatus.IN_PROGRESS, savedTodo.status)
            assertNull(savedTodo.completedDate)
            savedTodo
        }

        val response = todoService.addTodo(loginMember, "task", "content", TodoStatus.IN_PROGRESS)

        assertEquals(TodoStatus.IN_PROGRESS, response.status)
        verify(todoRepository).save(any(Todo::class.java))
    }

    @Test
    fun `addTodo with DONE status should create todo with completedDate set`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.DONE)).thenReturn(0)
        `when`(todoRepository.save(any(Todo::class.java))).thenAnswer { invocation ->
            val savedTodo = invocation.getArgument<Todo>(0)
            assertEquals(TodoStatus.DONE, savedTodo.status)
            assertNotNull(savedTodo.completedDate)
            savedTodo
        }

        val response = todoService.addTodo(loginMember, "task", "content", TodoStatus.DONE)

        assertEquals(TodoStatus.DONE, response.status)
        assertNotNull(response.completedDate)
        verify(todoRepository).save(any(Todo::class.java))
    }

    @Test
    fun `addTodo with null status should default to TODO`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.TODO)).thenReturn(0)
        `when`(todoRepository.save(any(Todo::class.java))).thenAnswer { invocation ->
            val savedTodo = invocation.getArgument<Todo>(0)
            assertEquals(TodoStatus.TODO, savedTodo.status)
            assertNull(savedTodo.completedDate)
            savedTodo
        }

        val response = todoService.addTodo(loginMember, "task", "content", null)

        assertEquals(TodoStatus.TODO, response.status)
        verify(todoRepository).save(any(Todo::class.java))
    }

    @Test
    fun `addTodo with status should use correct position query`() {
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.IN_PROGRESS)).thenReturn(5)
        `when`(todoRepository.save(any(Todo::class.java))).thenAnswer { invocation ->
            val savedTodo = invocation.getArgument<Todo>(0)
            assertEquals(4, savedTodo.position)
            savedTodo
        }

        todoService.addTodo(loginMember, "task", "content", TodoStatus.IN_PROGRESS)

        verify(todoRepository).findMinPositionByMemberAndStatus(member, TodoStatus.IN_PROGRESS)
    }

    // ========== editTodo with Status Change Tests ==========

    @Test
    fun `editTodo with status change from TODO to IN_PROGRESS should update status and position`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("old title", TodoStatus.TODO, 5)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.IN_PROGRESS)).thenReturn(10)

        val response = todoService.editTodo(loginMember, todoId, "new title", "new content", TodoStatus.IN_PROGRESS)

        assertEquals(TodoStatus.IN_PROGRESS, response.status)
        assertEquals(9, response.position)
        assertNull(response.completedDate)
    }

    @Test
    fun `editTodo with status change to DONE should set completedDate`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("title", TodoStatus.TODO, 0)
        ReflectionTestUtils.setField(todo, "id", todoId)
        assertNull(todo.completedDate)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.DONE)).thenReturn(0)

        val response = todoService.editTodo(loginMember, todoId, "title", "content", TodoStatus.DONE)

        assertEquals(TodoStatus.DONE, response.status)
        assertNotNull(response.completedDate)
    }

    @Test
    fun `editTodo with status change from DONE to TODO should clear completedDate`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("title", TodoStatus.DONE, 0)
        todo.markCompleted(0)
        ReflectionTestUtils.setField(todo, "id", todoId)
        assertNotNull(todo.completedDate)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.TODO)).thenReturn(0)

        val response = todoService.editTodo(loginMember, todoId, "title", "content", TodoStatus.TODO)

        assertEquals(TodoStatus.TODO, response.status)
        assertNull(response.completedDate)
    }

    @Test
    fun `editTodo with status change from DONE to IN_PROGRESS should clear completedDate`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("title", TodoStatus.DONE, 0)
        todo.markCompleted(0)
        ReflectionTestUtils.setField(todo, "id", todoId)
        assertNotNull(todo.completedDate)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.IN_PROGRESS)).thenReturn(0)

        val response = todoService.editTodo(loginMember, todoId, "title", "content", TodoStatus.IN_PROGRESS)

        assertEquals(TodoStatus.IN_PROGRESS, response.status)
        assertNull(response.completedDate)
    }

    @Test
    fun `editTodo with same status should not change position`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("title", TodoStatus.IN_PROGRESS, 5)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        val response = todoService.editTodo(loginMember, todoId, "updated title", "updated content", TodoStatus.IN_PROGRESS)

        assertEquals(TodoStatus.IN_PROGRESS, response.status)
        assertEquals(5, response.position)
    }

    @Test
    fun `editTodo with null status should not change status`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("title", TodoStatus.IN_PROGRESS, 5)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        val response = todoService.editTodo(loginMember, todoId, "updated title", "updated content", null)

        assertEquals(TodoStatus.IN_PROGRESS, response.status)
        assertEquals(5, response.position)
    }

    @Test
    fun `editTodo with status change from IN_PROGRESS to DONE should set completedDate`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("title", TodoStatus.IN_PROGRESS, 0)
        ReflectionTestUtils.setField(todo, "id", todoId)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.DONE)).thenReturn(0)

        val response = todoService.editTodo(loginMember, todoId, "title", "content", TodoStatus.DONE)

        assertEquals(TodoStatus.DONE, response.status)
        assertNotNull(response.completedDate)
    }

    @Test
    fun `editTodo with status change from IN_PROGRESS to TODO should not affect completedDate`() {
        val todoId = UUID.randomUUID()
        val todo = createTodo("title", TodoStatus.IN_PROGRESS, 0)
        ReflectionTestUtils.setField(todo, "id", todoId)
        assertNull(todo.completedDate)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.TODO)).thenReturn(0)

        val response = todoService.editTodo(loginMember, todoId, "title", "content", TodoStatus.TODO)

        assertEquals(TodoStatus.TODO, response.status)
        assertNull(response.completedDate)
    }

    // ========== Helper Methods ==========

    private fun createTodo(title: String, status: TodoStatus, position: Int): Todo {
        return Todo(member, title, "content", position, status)
    }

}
