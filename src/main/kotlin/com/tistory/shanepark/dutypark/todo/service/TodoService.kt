package com.tistory.shanepark.dutypark.todo.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.notification.event.TodoTaggedEvent
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoBoardResponse
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoCountsResponse
import com.tistory.shanepark.dutypark.todo.domain.dto.TodoResponse
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.springframework.context.ApplicationEventPublisher
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth
import java.util.*

@Service
@Transactional
class TodoService(
    private val memberRepository: MemberRepository,
    private val todoRepository: TodoRepository,
    private val attachmentService: AttachmentService,
    private val friendService: FriendService,
    private val eventPublisher: ApplicationEventPublisher
) {
    private val log = logger()

    @Transactional(readOnly = true)
    fun todoList(loginMember: LoginMember): List<TodoResponse> {
        val member = findMember(loginMember)
        return todoRepository.findAccessibleTodosByStatus(member, TodoStatus.TODO)
            .sortedWith(boardOrderComparator(member))
            .map { toResponse(it, member) }
    }

    @Transactional(readOnly = true)
    fun completedTodoList(loginMember: LoginMember): List<TodoResponse> {
        val member = findMember(loginMember)
        return todoRepository.findAccessibleTodosByStatus(member, TodoStatus.DONE)
            .sortedWith(completedOrderComparator(member))
            .map { toResponse(it, member) }
    }

    @Transactional(readOnly = true)
    fun getBoard(loginMember: LoginMember): TodoBoardResponse {
        val member = findMember(loginMember)
        val allTodos = todoRepository.findAccessibleTodos(member)

        val todoList = mutableListOf<TodoResponse>()
        val inProgressList = mutableListOf<TodoResponse>()
        val doneList = mutableListOf<TodoResponse>()

        allTodos
            .sortedWith(compareBy<Todo>({ it.status.ordinal }).then(boardOrderComparator(member)))
            .forEach { todo ->
            val response = toResponse(todo, member)
            when (todo.status) {
                TodoStatus.TODO -> todoList.add(response)
                TodoStatus.IN_PROGRESS -> inProgressList.add(response)
                TodoStatus.DONE -> doneList.add(response)
            }
        }

        return TodoBoardResponse(
            todo = todoList,
            inProgress = inProgressList,
            done = doneList,
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
        return todoRepository.findAccessibleTodosByStatus(member, status)
            .sortedWith(boardOrderComparator(member))
            .map { toResponse(it, member) }
    }

    fun addTodo(
        loginMember: LoginMember,
        title: String,
        content: String,
        status: TodoStatus? = null,
        dueDate: LocalDate? = null,
        tagFriendIds: List<Long> = emptyList(),
        attachmentSessionId: UUID? = null,
        orderedAttachmentIds: List<UUID> = emptyList()
    ): TodoResponse {
        val member = findMember(loginMember)
        val targetStatus = status ?: TodoStatus.TODO
        val todoLastPosition = todoRepository.findMinPositionByMemberAndStatus(member, targetStatus)

        val todo = Todo(
            member = member,
            title = title,
            content = content,
            position = todoLastPosition - 1,
            status = targetStatus,
            completedDate = if (targetStatus == TodoStatus.DONE) java.time.LocalDateTime.now() else null,
            dueDate = dueDate
        )
        todoRepository.save(todo)
        syncTodoTags(todo, tagFriendIds)

        attachmentService.synchronizeContextAttachments(
            loginMember = loginMember,
            contextType = AttachmentContextType.TODO,
            contextId = todo.id.toString(),
            attachmentSessionId = attachmentSessionId,
            orderedAttachmentIds = orderedAttachmentIds
        )

        return toResponse(todo, member)
    }

    fun editTodo(
        loginMember: LoginMember,
        id: UUID,
        title: String,
        content: String,
        status: TodoStatus? = null,
        dueDate: LocalDate? = null,
        tagFriendIds: List<Long>? = null,
        attachmentSessionId: UUID? = null,
        orderedAttachmentIds: List<UUID> = emptyList()
    ): TodoResponse {
        val member = findMember(loginMember)

        val todo = todoRepository.findById(id)
            .orElseThrow { IllegalArgumentException("Todo not found") }

        verifyOwnership(todo, member)

        todo.update(title, content)
        todo.dueDate = dueDate

        // Handle status change if provided and different from current
        if (status != null && status != todo.status) {
            val newPosition = todoRepository.findMinPositionByMemberAndStatus(member, status) - 1
            todo.changeStatus(status, newPosition)
        }
        tagFriendIds?.let { syncTodoTags(todo, it) }

        attachmentService.synchronizeContextAttachments(
            loginMember = loginMember,
            contextType = AttachmentContextType.TODO,
            contextId = todo.id.toString(),
            attachmentSessionId = attachmentSessionId,
            orderedAttachmentIds = orderedAttachmentIds
        )

        return toResponse(todo, member)
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
            val newPosition = todoRepository.findMinPositionByMemberAndStatus(member, TodoStatus.DONE) - 1
            todo.markCompleted(newPosition)
        }

        return toResponse(todo, member)
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

        return toResponse(todo, member)
    }

    fun changeStatus(
        loginMember: LoginMember,
        id: UUID,
        newStatus: TodoStatus,
        orderedIds: List<UUID>
    ): TodoResponse {
        val member = findMember(loginMember)
        val todo = todoRepository.findById(id)
            .orElseThrow { IllegalArgumentException("Todo not found") }

        verifyOwnership(todo, member)

        // Change status first
        if (todo.status != newStatus) {
            todo.changeStatus(newStatus, 0)
        }

        // Reorder all todos in target column based on orderedIds
        val indexMap = orderedIds.mapIndexed { index, todoId -> todoId to index }.toMap()
        val todos = todoRepository.findAllById(orderedIds)

        todos.forEach { t ->
            verifyOwnership(t, member)
            if (t.status != newStatus) {
                throw IllegalArgumentException("Todo ${t.id} is not in $newStatus status")
            }
            t.position = indexMap.getValue(t.id)
        }

        return toResponse(todo, member)
    }

    @Transactional(readOnly = true)
    fun getTodosByMonth(loginMember: LoginMember, year: Int, month: Int): List<TodoResponse> {
        val member = findMember(loginMember)
        val yearMonth = YearMonth.of(year, month)
        val startDate = yearMonth.atDay(1)
        val endDate = yearMonth.atEndOfMonth()

        return todoRepository.findAccessibleTodosByDueDateBetween(member, startDate, endDate)
            .sortedWith(dueDateOrderComparator(member))
            .map { toResponse(it, member) }
    }

    @Transactional(readOnly = true)
    fun getTodosByDate(loginMember: LoginMember, date: LocalDate): List<TodoResponse> {
        val member = findMember(loginMember)

        return todoRepository.findAccessibleTodosByDueDate(member, date)
            .sortedWith(boardOrderComparator(member))
            .map { toResponse(it, member) }
    }

    @Transactional(readOnly = true)
    fun getOverdueTodos(loginMember: LoginMember): List<TodoResponse> {
        val member = findMember(loginMember)
        val today = LocalDate.now()

        return todoRepository.findAccessibleOverdueTodos(member, today, TodoStatus.DONE)
            .sortedWith(dueDateOrderComparator(member))
            .map { toResponse(it, member) }
    }

    fun tagFriend(loginMember: LoginMember, todoId: UUID, friendId: Long) {
        val todo = todoRepository.findById(todoId).orElseThrow { IllegalArgumentException("Todo not found") }
        val member = findMember(loginMember)
        val friend = memberRepository.findById(friendId).orElseThrow { IllegalArgumentException("Member not found") }

        verifyOwnership(todo, member)
        addTagToTodo(todo, friend)
    }

    fun untagFriend(loginMember: LoginMember, todoId: UUID, friendId: Long) {
        val todo = todoRepository.findById(todoId).orElseThrow { IllegalArgumentException("Todo not found") }
        val member = findMember(loginMember)
        val friend = memberRepository.findById(friendId).orElseThrow { IllegalArgumentException("Member not found") }

        verifyOwnership(todo, member)
        todo.removeTag(friend)
    }

    fun untagSelf(loginMember: LoginMember, todoId: UUID) {
        val todo = todoRepository.findById(todoId).orElseThrow { IllegalArgumentException("Todo not found") }
        val member = findMember(loginMember)
        todo.removeTag(member)
    }

    private fun verifyOwnership(todoEntity: Todo, member: Member) {
        if (todoEntity.member.id != member.id) {
            log.warn("Unauthorized access attempt: memberId={} tried to access todo {} (owner={})", member.id, todoEntity.id, todoEntity.member.id)
            throw IllegalArgumentException("Todo is not yours")
        }
    }

    private fun findMember(loginMember: LoginMember): Member =
        memberRepository.findById(loginMember.id)
            .orElseThrow { IllegalArgumentException("Member not found") }

    private fun toResponse(todo: Todo, viewer: Member): TodoResponse {
        val hasAttachments = attachmentService.hasAttachments(
            AttachmentContextType.TODO,
            todo.id.toString()
        )
        return TodoResponse.from(todo, viewer, hasAttachments)
    }

    private fun syncTodoTags(todo: Todo, tagFriendIds: List<Long>) {
        val desiredTagIds = tagFriendIds.distinct()
        val desiredTagSet = desiredTagIds.toSet()

        todo.tags
            .mapNotNull { it.member.id }
            .filterNot(desiredTagSet::contains)
            .forEach { memberId ->
                val member = memberRepository.findById(memberId).orElseThrow { IllegalArgumentException("Member not found") }
                todo.removeTag(member)
            }

        val existingTagIds = todo.tags.mapNotNull { it.member.id }.toSet()
        desiredTagIds
            .filterNot(existingTagIds::contains)
            .forEach { friendId ->
                val friend = memberRepository.findById(friendId).orElseThrow { IllegalArgumentException("Member not found") }
                addTagToTodo(todo, friend)
            }
    }

    private fun addTagToTodo(todo: Todo, friend: Member) {
        if (!friendService.isFriend(todo.member, friend)) {
            throw AuthException("$friend is not friend of ${todo.member}")
        }
        todo.addTag(friend)
        publishTodoTaggedEvent(todo, friend)
    }

    private fun publishTodoTaggedEvent(todo: Todo, friend: Member) {
        eventPublisher.publishEvent(
            TodoTaggedEvent(
                todoId = todo.id,
                ownerId = todo.member.id!!,
                taggedMemberId = friend.id!!,
                todoTitle = todo.title
            )
        )
    }

    private fun boardOrderComparator(viewer: Member): Comparator<Todo> {
        return compareBy<Todo>({ it.member.id != viewer.id }, { it.position ?: Int.MAX_VALUE }, { it.createdDate })
    }

    private fun completedOrderComparator(viewer: Member): Comparator<Todo> {
        return compareBy<Todo>({ it.member.id != viewer.id })
            .thenByDescending { it.completedDate ?: LocalDateTime.MIN }
            .thenBy { it.createdDate }
    }

    private fun dueDateOrderComparator(viewer: Member): Comparator<Todo> {
        return compareBy<Todo>({ it.dueDate ?: LocalDate.MAX })
            .thenBy { it.member.id != viewer.id }
            .thenBy { it.position ?: Int.MAX_VALUE }
            .thenBy { it.createdDate }
    }

}
