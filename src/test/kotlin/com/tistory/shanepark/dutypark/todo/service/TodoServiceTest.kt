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
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.ArgumentMatchers.any
import org.mockito.Mockito.*
import org.springframework.test.util.ReflectionTestUtils
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.*

class TodoServiceTest {

    private lateinit var todoService: TodoService
    private lateinit var memberRepository: MemberRepository
    private lateinit var todoRepository: TodoRepository
    private lateinit var attachmentService: AttachmentService

    private val loginMember = LoginMember(1, "", "", "", false)
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
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.ACTIVE)).thenReturn(0)

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
        `when`(todoRepository.findAllByMemberAndStatusOrderByPosition(member, TodoStatus.ACTIVE)).thenReturn(
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
        val completedTodo = Todo(member, "title", "content", null, TodoStatus.COMPLETED)
        `when`(
            todoRepository.findAllByMemberAndStatusOrderByCompletedDateDesc(member, TodoStatus.COMPLETED)
        ).thenReturn(listOf(completedTodo))

        val response = todoService.completedTodoList(loginMember)

        assertEquals(1, response.size)
        assertEquals(TodoStatus.COMPLETED, response.first().status)
    }

    @Test
    fun `completeTodo should mark todo as completed`() {
        val todoId = UUID.randomUUID()
        val todo = Todo(member, "title", "content", 1)

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))

        val response = todoService.completeTodo(loginMember, todoId)

        assertEquals(TodoStatus.COMPLETED, response.status)
    }

    @Test
    fun `reopenTodo should mark todo as active`() {
        val todoId = UUID.randomUUID()
        val todo = Todo(member, "title", "content", null)
        todo.markCompleted()

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findById(todoId)).thenReturn(Optional.of(todo))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.ACTIVE)).thenReturn(0)

        val response = todoService.reopenTodo(loginMember, todoId)

        assertEquals(TodoStatus.ACTIVE, response.status)
        assertEquals(null, response.completedDate)
    }

    @Test
    fun `addTodo should finalize attachment session when attachmentSessionId is provided`() {
        val sessionId = UUID.randomUUID()
        val orderedAttachmentIds = listOf(UUID.randomUUID(), UUID.randomUUID())
        val todoId = UUID.randomUUID()

        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.ACTIVE)).thenReturn(0)
        `when`(todoRepository.save(any(Todo::class.java))).thenAnswer { invocation ->
            val savedTodo = invocation.getArgument<Todo>(0)
            ReflectionTestUtils.setField(savedTodo, "id", todoId)
            savedTodo
        }

        todoService.addTodo(loginMember, "title", "content", sessionId, orderedAttachmentIds)

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

        todoService.editTodo(loginMember, todoId, "new title", "new content", null, orderedAttachmentIds)

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
            todoService.editTodo(loginMember, todoId, "new title", "new content", UUID.randomUUID(), listOf(UUID.randomUUID()))
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

}
