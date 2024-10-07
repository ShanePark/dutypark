package com.tistory.shanepark.dutypark.todo.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoRequest
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoResponse
import com.tistory.shanepark.dutypark.todo.service.TodoService
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.*
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

    @PostMapping
    fun addTodo(
        @Login loginMember: LoginMember,
        @RequestBody @Validated todoRequest: TodoRequest
    ): TodoResponse {
        return todoService.addTodo(loginMember, todoRequest.title, todoRequest.content)
    }

    @PutMapping("/{id}")
    fun editTodo(
        @Login loginMember: LoginMember,
        @PathVariable id: UUID,
        @RequestBody @Validated todoRequest: TodoRequest
    ): TodoResponse {
        return todoService.editTodo(loginMember, id, todoRequest.title, todoRequest.content)
    }

    @PatchMapping("/position")
    fun updatePosition(
        @Login loginMember: LoginMember,
        @RequestBody ids: List<UUID>
    ) {
        todoService.updatePosition(loginMember, ids)
    }

    @DeleteMapping("/{id}")
    fun deleteTodo(
        @Login loginMember: LoginMember,
        @PathVariable id: UUID
    ) {
        todoService.deleteTodo(loginMember, id)
    }

}
