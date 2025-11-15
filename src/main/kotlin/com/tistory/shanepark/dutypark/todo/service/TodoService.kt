package com.tistory.shanepark.dutypark.todo.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.dto.FinalizeSessionRequest
import com.tistory.shanepark.dutypark.attachment.dto.ReorderAttachmentsRequest
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoResponse
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Service
@Transactional
class TodoService(
    private val memberRepository: MemberRepository,
    private val todoRepository: TodoRepository,
    private val attachmentService: AttachmentService
) {
    private val log = logger()

    @Transactional(readOnly = true)
    fun todoList(loginMember: LoginMember): List<TodoResponse> {
        val member = findMember(loginMember)
        return todoRepository.findAllByMemberAndStatusOrderByPosition(member, TodoStatus.ACTIVE)
            .map { TodoResponse.from(it) }
    }

    @Transactional(readOnly = true)
    fun completedTodoList(loginMember: LoginMember): List<TodoResponse> {
        val member = findMember(loginMember)
        return todoRepository.findAllByMemberAndStatusOrderByCompletedDateDesc(member, TodoStatus.COMPLETED)
            .map { TodoResponse.from(it) }
    }

    fun addTodo(
        loginMember: LoginMember,
        title: String,
        content: String,
        attachmentSessionId: UUID? = null,
        orderedAttachmentIds: List<UUID> = emptyList()
    ): TodoResponse {
        val member = findMember(loginMember)
        val todoLastPosition = todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.ACTIVE)

        val todo = Todo(
            member = member,
            title = title,
            content = content,
            position = todoLastPosition - 1,
            status = TodoStatus.ACTIVE,
            completedDate = null
        )
        todoRepository.save(todo)

        handleAttachmentsAfterChange(
            loginMember = loginMember,
            todoId = todo.id.toString(),
            attachmentSessionId = attachmentSessionId,
            orderedAttachmentIds = orderedAttachmentIds
        )

        return TodoResponse.from(todo)
    }

    fun editTodo(
        loginMember: LoginMember,
        id: UUID,
        title: String,
        content: String,
        attachmentSessionId: UUID? = null,
        orderedAttachmentIds: List<UUID> = emptyList()
    ): TodoResponse {
        val member = findMember(loginMember)

        val todo = todoRepository.findById(id)
            .orElseThrow { IllegalArgumentException("Todo not found") }

        verifyOwnership(todo, member)

        todo.update(title, content)

        handleAttachmentsAfterChange(
            loginMember = loginMember,
            todoId = todo.id.toString(),
            attachmentSessionId = attachmentSessionId,
            orderedAttachmentIds = orderedAttachmentIds
        )

        return TodoResponse.from(todo)
    }

    fun updatePosition(loginMember: LoginMember, ids: List<UUID>) {
        val member = findMember(loginMember)

        val indexMap = ids.mapIndexed { index, id -> id to index }.toMap()
        val todos = todoRepository.findAllById(ids).sortedBy { indexMap.getValue(it.id) }

        todos.forEachIndexed { index, todo ->
            verifyOwnership(todo, member)
            if (todo.status != TodoStatus.ACTIVE) {
                throw IllegalArgumentException("Cannot reorder non-active todo")
            }
            todo.position = index
        }
    }

    fun deleteTodo(loginMember: LoginMember, id: UUID) {
        val member = findMember(loginMember)
        val todo = todoRepository.findById(id).orElseThrow { IllegalArgumentException("Todo not found") }
        verifyOwnership(todo, member)

        val attachments =
            attachmentService.listAttachments(loginMember, AttachmentContextType.TODO, id.toString())
        attachments.forEach { attachmentDto ->
            attachmentService.deleteAttachment(loginMember, attachmentDto.id)
        }

        todoRepository.delete(todo)
    }

    fun completeTodo(loginMember: LoginMember, id: UUID): TodoResponse {
        val member = findMember(loginMember)

        val todo = todoRepository.findById(id)
            .orElseThrow { IllegalArgumentException("Todo not found") }

        verifyOwnership(todo, member)

        if (todo.status == TodoStatus.ACTIVE) {
            todo.markCompleted()
        }

        return TodoResponse.from(todo)
    }

    fun reopenTodo(loginMember: LoginMember, id: UUID): TodoResponse {
        val member = findMember(loginMember)

        val todo = todoRepository.findById(id)
            .orElseThrow { IllegalArgumentException("Todo not found") }

        verifyOwnership(todo, member)

        if (todo.status == TodoStatus.COMPLETED) {
            val todoLastPosition = todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.ACTIVE)
            todo.markActive(todoLastPosition - 1)
        }

        return TodoResponse.from(todo)
    }

    private fun verifyOwnership(todoEntity: Todo, member: Member) {
        if (todoEntity.member.id != member.id) {
            log.warn("$member tried to access todo ${todoEntity.id} which is not his")
            throw IllegalArgumentException("Todo is not yours")
        }
    }

    private fun handleAttachmentsAfterChange(
        loginMember: LoginMember,
        todoId: String,
        attachmentSessionId: UUID?,
        orderedAttachmentIds: List<UUID>
    ) {
        when {
            attachmentSessionId != null -> {
                val request = FinalizeSessionRequest(
                    contextId = todoId,
                    orderedAttachmentIds = orderedAttachmentIds
                )
                attachmentService.finalizeSession(loginMember, attachmentSessionId, request)
            }

            orderedAttachmentIds.isNotEmpty() -> {
                val reorderRequest = ReorderAttachmentsRequest(
                    contextType = AttachmentContextType.TODO,
                    contextId = todoId,
                    orderedAttachmentIds = orderedAttachmentIds
                )
                attachmentService.reorderAttachments(loginMember, reorderRequest)
            }
        }
    }

    private fun findMember(loginMember: LoginMember): Member =
        memberRepository.findById(loginMember.id)
            .orElseThrow { IllegalArgumentException("Member not found") }

}
