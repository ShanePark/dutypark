package com.tistory.shanepark.dutypark.todo.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoResponse
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Service
@Transactional
class TodoService(
    private val memberRepository: MemberRepository,
    private val todoRepository: TodoRepository
) {

    @Transactional(readOnly = true)
    fun todoList(loginMember: LoginMember): List<TodoResponse> {
        val member = findMember(loginMember)
        return todoRepository.findAllByMemberOrderByPosition(member)
            .map { TodoResponse.from(it) }
    }

    fun addTodo(loginMember: LoginMember, title: String, content: String): TodoResponse {
        val member = findMember(loginMember)
        val todoLastPosition = todoRepository.findMaxPositionByMember(member)

        val todo = Todo(member = member, title = title, content = content, position = todoLastPosition + 1)
        todoRepository.save(todo)

        return TodoResponse.from(todo)
    }

    fun editTodo(loginMember: LoginMember, id: UUID, title: String, content: String): TodoResponse {
        val member = findMember(loginMember)

        val todo = todoRepository.findById(id)
            .orElseThrow { IllegalArgumentException("Todo not found") }

        verifyOwnership(todo, member)

        todo.update(title, content)
        return TodoResponse.from(todo)
    }

    fun updatePosition(loginMember: LoginMember, ids: List<UUID>) {
        val member = findMember(loginMember)

        val indexMap = ids.mapIndexed { index, id -> id to index }.toMap()
        val todos = todoRepository.findAllById(ids).sortedBy { indexMap.getValue(it.id) }

        todos.forEachIndexed { index, todo ->
            verifyOwnership(todo, member)
            todo.position = index
        }
    }

    fun deleteTodo(loginMember: LoginMember, id: UUID) {
        val member = findMember(loginMember)
        val todo = todoRepository.findById(id).orElseThrow { IllegalArgumentException("Todo not found") }
        verifyOwnership(todo, member)

        todoRepository.delete(todo)
    }

    private fun verifyOwnership(todo: Todo, member: Member) {
        if (todo.member.id != member.id) {
            throw IllegalArgumentException("Todo is not yours")
        }
    }

    private fun findMember(loginMember: LoginMember): Member =
        memberRepository.findById(loginMember.id)
            .orElseThrow { IllegalArgumentException("Member not found") }

}
