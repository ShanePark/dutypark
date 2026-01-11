package com.tistory.shanepark.dutypark.todo.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoBoardResponse
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoPositionUpdateRequest
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoRequest
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoResponse
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoStatusChangeRequest
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import com.tistory.shanepark.dutypark.todo.service.TodoService
import org.springframework.format.annotation.DateTimeFormat
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.*
import java.time.LocalDate
import java.util.*

@RestController
@RequestMapping("/api/todos")
class TodoController(
    private val todoService: TodoService
) {

    @GetMapping
    fun todoList(
        @Login loginMember: LoginMember
    ): List<TodoResponse> {
        return todoService.todoList(loginMember)
    }

    @GetMapping("/completed")
    fun completedTodoList(
        @Login loginMember: LoginMember
    ): List<TodoResponse> {
        return todoService.completedTodoList(loginMember)
    }

    @GetMapping("/board")
    fun getBoard(
        @Login loginMember: LoginMember
    ): TodoBoardResponse {
        return todoService.getBoard(loginMember)
    }

    @GetMapping("/status/{status}")
    fun getByStatus(
        @Login loginMember: LoginMember,
        @PathVariable status: TodoStatus
    ): List<TodoResponse> {
        return todoService.getByStatus(loginMember, status)
    }

    @PostMapping
    fun addTodo(
        @Login loginMember: LoginMember,
        @RequestBody @Validated todoRequest: TodoRequest
    ): TodoResponse {
        return todoService.addTodo(
            loginMember = loginMember,
            title = todoRequest.title,
            content = todoRequest.content,
            dueDate = todoRequest.dueDate,
            attachmentSessionId = todoRequest.attachmentSessionId,
            orderedAttachmentIds = todoRequest.orderedAttachmentIds
        )
    }

    @PutMapping("/{id}")
    fun editTodo(
        @Login loginMember: LoginMember,
        @PathVariable id: UUID,
        @RequestBody @Validated todoRequest: TodoRequest
    ): TodoResponse {
        return todoService.editTodo(
            loginMember = loginMember,
            id = id,
            title = todoRequest.title,
            content = todoRequest.content,
            dueDate = todoRequest.dueDate,
            attachmentSessionId = todoRequest.attachmentSessionId,
            orderedAttachmentIds = todoRequest.orderedAttachmentIds
        )
    }

    @PatchMapping("/position")
    fun updatePosition(
        @Login loginMember: LoginMember,
        @RequestBody ids: List<UUID>
    ) {
        todoService.updatePosition(loginMember, ids)
    }

    @PatchMapping("/positions")
    fun updatePositionsByStatus(
        @Login loginMember: LoginMember,
        @RequestBody request: TodoPositionUpdateRequest
    ) {
        todoService.updatePositionsByStatus(loginMember, request.status, request.orderedIds)
    }

    @PatchMapping("/{id}/status")
    fun changeStatus(
        @Login loginMember: LoginMember,
        @PathVariable id: UUID,
        @RequestBody request: TodoStatusChangeRequest
    ): TodoResponse {
        return todoService.changeStatus(loginMember, id, request.status, request.position)
    }

    @PatchMapping("/{id}/complete")
    fun completeTodo(
        @Login loginMember: LoginMember,
        @PathVariable id: UUID,
    ): TodoResponse {
        return todoService.completeTodo(loginMember, id)
    }

    @PatchMapping("/{id}/reopen")
    fun reopenTodo(
        @Login loginMember: LoginMember,
        @PathVariable id: UUID,
    ): TodoResponse {
        return todoService.reopenTodo(loginMember, id)
    }

    @DeleteMapping("/{id}")
    fun deleteTodo(
        @Login loginMember: LoginMember,
        @PathVariable id: UUID
    ) {
        todoService.deleteTodo(loginMember, id)
    }

    @GetMapping("/calendar")
    fun getTodosByMonth(
        @Login loginMember: LoginMember,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): List<TodoResponse> {
        return todoService.getTodosByMonth(loginMember, year, month)
    }

    @GetMapping("/due")
    fun getTodosByDate(
        @Login loginMember: LoginMember,
        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) date: LocalDate
    ): List<TodoResponse> {
        return todoService.getTodosByDate(loginMember, date)
    }

    @GetMapping("/overdue")
    fun getOverdueTodos(
        @Login loginMember: LoginMember
    ): List<TodoResponse> {
        return todoService.getOverdueTodos(loginMember)
    }

}
