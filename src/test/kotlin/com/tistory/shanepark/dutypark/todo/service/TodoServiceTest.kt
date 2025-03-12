package com.tistory.shanepark.dutypark.todo.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.ArgumentMatchers.any
import org.mockito.Mockito.*
import java.util.*

class TodoServiceTest {

    private lateinit var todoService: TodoService
    private lateinit var memberRepository: MemberRepository
    private lateinit var todoRepository: TodoRepository

    private val loginMember = LoginMember(1, "", "",  "", false)
    private val member = Member(name = "", password = "")

    @BeforeEach
    fun setUp() {
        memberRepository = mock(MemberRepository::class.java)
        todoRepository = mock(TodoRepository::class.java)
        todoService = TodoService(memberRepository, todoRepository)
    }

    @Test
    fun `addTodo should save and return TodoResponse`() {
        // Given
        `when`(memberRepository.findById(loginMember.id)).thenReturn(Optional.of(member))
        `when`(todoRepository.findMaxPositionByMember(member)).thenReturn(0)

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
        `when`(todoRepository.findAllByMemberOrderByPosition(member)).thenReturn(
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

    private fun otherMember(): Member {
        val member = Member(name = "", password = "")
        member.id = 2
        return member
    }

}
