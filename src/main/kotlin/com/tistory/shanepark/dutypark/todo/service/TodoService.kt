package com.tistory.shanepark.dutypark.todo.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoBoardResponse
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoCountsResponse
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoResponse
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
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
        return todoRepository.findAllByMemberAndStatusOrderByPosition(member, TodoStatus.TODO)
            .map { todo ->
                val hasAttachments = attachmentService.hasAttachments(
                    AttachmentContextType.TODO,
                    todo.id.toString()
                )
                TodoResponse.from(todo, hasAttachments)
            }
    }

    @Transactional(readOnly = true)
    fun completedTodoList(loginMember: LoginMember): List<TodoResponse> {
        val member = findMember(loginMember)
        return todoRepository.findAllByMemberAndStatusOrderByCompletedDateDesc(member, TodoStatus.DONE)
            .map { todo ->
                val hasAttachments = attachmentService.hasAttachments(
                    AttachmentContextType.TODO,
                    todo.id.toString()
                )
                TodoResponse.from(todo, hasAttachments)
            }
    }

    @Transactional(readOnly = true)
    fun getBoard(loginMember: LoginMember): TodoBoardResponse {
        val member = findMember(loginMember)
        val allTodos = todoRepository.findAllByMemberOrderByStatusAscPositionAsc(member)

        val todoList = mutableListOf<TodoResponse>()
        val inProgressList = mutableListOf<TodoResponse>()
        val doneList = mutableListOf<TodoResponse>()

        allTodos.forEach { todo ->
            val hasAttachments = attachmentService.hasAttachments(
                AttachmentContextType.TODO,
                todo.id.toString()
            )
            val response = TodoResponse.from(todo, hasAttachments)
            when (todo.status) {
                TodoStatus.TODO -> todoList.add(response)
                TodoStatus.IN_PROGRESS -> inProgressList.add(response)
                TodoStatus.DONE -> doneList.add(response)
            }
        }

        return TodoBoardResponse(
            todo = todoList.sortedBy { it.position },
            inProgress = inProgressList.sortedBy { it.position },
            done = doneList.sortedBy { it.position },
            counts = TodoCountsResponse(
                todo = todoList.size,
                inProgress = inProgressList.size,
                done = doneList.size,
                total = allTodos.size
            )
        )
    }

    @Transactional(readOnly = true)
    fun getByStatus(loginMember: LoginMember, status: TodoStatus): List<TodoResponse> {
        val member = findMember(loginMember)
        return todoRepository.findAllByMemberAndStatusOrderByPositionAsc(member, status)
            .map { todo ->
                val hasAttachments = attachmentService.hasAttachments(
                    AttachmentContextType.TODO,
                    todo.id.toString()
                )
                TodoResponse.from(todo, hasAttachments)
            }
    }

    fun addTodo(
        loginMember: LoginMember,
        title: String,
        content: String,
        dueDate: LocalDate? = null,
        attachmentSessionId: UUID? = null,
        orderedAttachmentIds: List<UUID> = emptyList()
    ): TodoResponse {
        val member = findMember(loginMember)
        val todoLastPosition = todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.TODO)

        val todo = Todo(
            member = member,
            title = title,
            content = content,
            position = todoLastPosition - 1,
            status = TodoStatus.TODO,
            completedDate = null,
            dueDate = dueDate
        )
        todoRepository.save(todo)

        attachmentService.synchronizeContextAttachments(
            loginMember = loginMember,
            contextType = AttachmentContextType.TODO,
            contextId = todo.id.toString(),
            attachmentSessionId = attachmentSessionId,
            orderedAttachmentIds = orderedAttachmentIds
        )

        val hasAttachments = attachmentService.hasAttachments(
            AttachmentContextType.TODO,
            todo.id.toString()
        )
        return TodoResponse.from(todo, hasAttachments)
    }

    fun editTodo(
        loginMember: LoginMember,
        id: UUID,
        title: String,
        content: String,
        dueDate: LocalDate? = null,
        attachmentSessionId: UUID? = null,
        orderedAttachmentIds: List<UUID> = emptyList()
    ): TodoResponse {
        val member = findMember(loginMember)

        val todo = todoRepository.findById(id)
            .orElseThrow { IllegalArgumentException("Todo not found") }

        verifyOwnership(todo, member)

        todo.update(title, content)
        todo.dueDate = dueDate

        attachmentService.synchronizeContextAttachments(
            loginMember = loginMember,
            contextType = AttachmentContextType.TODO,
            contextId = todo.id.toString(),
            attachmentSessionId = attachmentSessionId,
            orderedAttachmentIds = orderedAttachmentIds
        )

        val hasAttachments = attachmentService.hasAttachments(
            AttachmentContextType.TODO,
            todo.id.toString()
        )
        return TodoResponse.from(todo, hasAttachments)
    }

    fun updatePosition(loginMember: LoginMember, ids: List<UUID>) {
        val member = findMember(loginMember)

        val indexMap = ids.mapIndexed { index, id -> id to index }.toMap()
        val todos = todoRepository.findAllById(ids).sortedBy { indexMap.getValue(it.id) }

        todos.forEachIndexed { index, todo ->
            verifyOwnership(todo, member)
            if (todo.status != TodoStatus.TODO) {
                throw IllegalArgumentException("Cannot reorder non-TODO status todo")
            }
            todo.position = index
        }
    }

    fun updatePositionsByStatus(
        loginMember: LoginMember,
        status: TodoStatus,
        orderedIds: List<UUID>
    ) {
        val member = findMember(loginMember)

        val indexMap = orderedIds.mapIndexed { index, id -> id to index }.toMap()
        val todos = todoRepository.findAllById(orderedIds)

        todos.forEach { todo ->
            verifyOwnership(todo, member)
            if (todo.status != status) {
                throw IllegalArgumentException("Todo ${todo.id} is not in $status status")
            }
            todo.position = indexMap.getValue(todo.id)
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

        if (todo.status == TodoStatus.TODO || todo.status == TodoStatus.IN_PROGRESS) {
            todo.markCompleted()
        }

        val hasAttachments = attachmentService.hasAttachments(
            AttachmentContextType.TODO,
            todo.id.toString()
        )
        return TodoResponse.from(todo, hasAttachments)
    }

    fun reopenTodo(loginMember: LoginMember, id: UUID): TodoResponse {
        val member = findMember(loginMember)

        val todo = todoRepository.findById(id)
            .orElseThrow { IllegalArgumentException("Todo not found") }

        verifyOwnership(todo, member)

        if (todo.status == TodoStatus.DONE) {
            val todoLastPosition = todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.TODO)
            todo.markActive(todoLastPosition - 1)
        }

        val hasAttachments = attachmentService.hasAttachments(
            AttachmentContextType.TODO,
            todo.id.toString()
        )
        return TodoResponse.from(todo, hasAttachments)
    }

    fun changeStatus(
        loginMember: LoginMember,
        id: UUID,
        newStatus: TodoStatus,
        targetPosition: Int?
    ): TodoResponse {
        val member = findMember(loginMember)
        val todo = todoRepository.findById(id)
            .orElseThrow { IllegalArgumentException("Todo not found") }

        verifyOwnership(todo, member)

        // Ignore if same status
        if (todo.status == newStatus) {
            val hasAttachments = attachmentService.hasAttachments(
                AttachmentContextType.TODO,
                todo.id.toString()
            )
            return TodoResponse.from(todo, hasAttachments)
        }

        // Calculate new position: if targetPosition is null, add to top (min - 1)
        val newPosition = targetPosition
            ?: (todoRepository.findMinPositionByMemberAndStatus(member, newStatus) - 1)

        todo.changeStatus(newStatus, newPosition)

        val hasAttachments = attachmentService.hasAttachments(
            AttachmentContextType.TODO,
            todo.id.toString()
        )
        return TodoResponse.from(todo, hasAttachments)
    }

    @Transactional(readOnly = true)
    fun getTodosByMonth(loginMember: LoginMember, year: Int, month: Int): List<TodoResponse> {
        val member = findMember(loginMember)
        val yearMonth = YearMonth.of(year, month)
        val startDate = yearMonth.atDay(1)
        val endDate = yearMonth.atEndOfMonth()

        return todoRepository.findAllByMemberAndDueDateBetweenOrderByDueDateAsc(member, startDate, endDate)
            .map { todo ->
                val hasAttachments = attachmentService.hasAttachments(
                    AttachmentContextType.TODO,
                    todo.id.toString()
                )
                TodoResponse.from(todo, hasAttachments)
            }
    }

    @Transactional(readOnly = true)
    fun getTodosByDate(loginMember: LoginMember, date: LocalDate): List<TodoResponse> {
        val member = findMember(loginMember)

        return todoRepository.findAllByMemberAndDueDateOrderByPositionAsc(member, date)
            .map { todo ->
                val hasAttachments = attachmentService.hasAttachments(
                    AttachmentContextType.TODO,
                    todo.id.toString()
                )
                TodoResponse.from(todo, hasAttachments)
            }
    }

    @Transactional(readOnly = true)
    fun getOverdueTodos(loginMember: LoginMember): List<TodoResponse> {
        val member = findMember(loginMember)
        val today = LocalDate.now()

        return todoRepository.findAllByMemberAndDueDateLessThanAndStatusNot(member, today, TodoStatus.DONE)
            .map { todo ->
                val hasAttachments = attachmentService.hasAttachments(
                    AttachmentContextType.TODO,
                    todo.id.toString()
                )
                TodoResponse.from(todo, hasAttachments)
            }
    }

    private fun verifyOwnership(todoEntity: Todo, member: Member) {
        if (todoEntity.member.id != member.id) {
            log.warn("$member tried to access todo ${todoEntity.id} which is not his")
            throw IllegalArgumentException("Todo is not yours")
        }
    }

    private fun findMember(loginMember: LoginMember): Member =
        memberRepository.findById(loginMember.id)
            .orElseThrow { IllegalArgumentException("Member not found") }

}
