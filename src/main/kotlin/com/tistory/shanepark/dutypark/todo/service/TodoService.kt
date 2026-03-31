package com.tistory.shanepark.dutypark.todo.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.notification.event.TodoStatusChangedEvent
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

        val todo = if (tagFriendIds != null) {
            findTodoForTagUpdate(id)
        } else {
            todoRepository.findById(id)
                .orElseThrow { IllegalArgumentException("Todo not found") }
        }

        verifyOwnership(todo, member)

        todo.update(title, content)
        todo.dueDate = dueDate

        // Handle status change if provided and different from current
        val changedStatus = status?.takeIf { it != todo.status }
        if (changedStatus != null) {
            val newPosition = todoRepository.findMinPositionByMemberAndStatus(member, changedStatus) - 1
            todo.changeStatus(changedStatus, newPosition)
        }
        tagFriendIds?.let { syncTodoTags(todo, it) }
        if (changedStatus != null) {
            publishTodoStatusChangedEvents(todo, member, changedStatus)
        }

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

        verifyStatusChangePermission(todo, member)

        if (todo.status == TodoStatus.TODO || todo.status == TodoStatus.IN_PROGRESS) {
            val newPosition = findStatusChangePosition(todo, member, TodoStatus.DONE)
            todo.markCompleted(newPosition)
            publishTodoStatusChangedEvents(todo, member, TodoStatus.DONE)
        }

        return toResponse(todo, member)
    }

    fun reopenTodo(loginMember: LoginMember, id: UUID): TodoResponse {
        val member = findMember(loginMember)

        val todo = todoRepository.findById(id)
            .orElseThrow { IllegalArgumentException("Todo not found") }

        verifyStatusChangePermission(todo, member)

        if (todo.status == TodoStatus.DONE) {
            val newPosition = findStatusChangePosition(todo, member, TodoStatus.TODO)
            todo.markActive(newPosition)
            publishTodoStatusChangedEvents(todo, member, TodoStatus.TODO)
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

        verifyStatusChangePermission(todo, member)
        val isOwner = isOwner(todo, member)
        val statusChanged = todo.status != newStatus

        // Change status first
        if (statusChanged) {
            val targetPosition = if (isOwner && orderedIds.isNotEmpty()) 0 else findStatusChangePosition(todo, member, newStatus)
            todo.changeStatus(newStatus, targetPosition)
            publishTodoStatusChangedEvents(todo, member, newStatus)
        }

        if (!isOwner) {
            return toResponse(todo, member)
        }

        if (orderedIds.isEmpty()) {
            if (statusChanged) {
                return toResponse(todo, member)
            }
            throw IllegalArgumentException("todo.reorder.orderedIds.required")
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
        val todo = findTodoForTagUpdate(todoId)
        val member = findMember(loginMember)
        val friend = memberRepository.findById(friendId).orElseThrow { IllegalArgumentException("Member not found") }

        verifyOwnership(todo, member)
        addTagToTodo(todo, friend)
    }

    fun untagFriend(loginMember: LoginMember, todoId: UUID, friendId: Long) {
        val todo = findTodoForTagUpdate(todoId)
        val member = findMember(loginMember)
        val friend = memberRepository.findById(friendId).orElseThrow { IllegalArgumentException("Member not found") }

        verifyOwnership(todo, member)
        todo.removeTag(friend)
    }

    fun untagSelf(loginMember: LoginMember, todoId: UUID) {
        val todo = findTodoForTagUpdate(todoId)
        val member = findMember(loginMember)
        todo.removeTag(member)
    }

    private fun verifyOwnership(todoEntity: Todo, member: Member) {
        if (todoEntity.member.id != member.id) {
            log.warn("Unauthorized access attempt: memberId={} tried to access todo {} (owner={})", member.id, todoEntity.id, todoEntity.member.id)
            throw IllegalArgumentException("Todo is not yours")
        }
    }

    private fun verifyStatusChangePermission(todoEntity: Todo, member: Member) {
        if (isOwner(todoEntity, member) || isTaggedMember(todoEntity, member)) {
            return
        }
        log.warn(
            "Unauthorized status change attempt: memberId={} tried to change status of todo {} (owner={})",
            member.id,
            todoEntity.id,
            todoEntity.member.id
        )
        throw IllegalArgumentException("Todo status change is not allowed")
    }

    private fun isOwner(todoEntity: Todo, member: Member): Boolean {
        return todoEntity.member.id == member.id
    }

    private fun isTaggedMember(todoEntity: Todo, member: Member): Boolean {
        return todoEntity.tags.any { it.member.id == member.id }
    }

    private fun findStatusChangePosition(todoEntity: Todo, actor: Member, targetStatus: TodoStatus): Int {
        val owner = todoEntity.member
        return todoRepository.findMinPositionByMemberAndStatus(owner, targetStatus) - 1
    }

    private fun ownerScopedSortKey(todo: Todo, viewer: Member): Long {
        return if (todo.member.id == viewer.id) Long.MIN_VALUE else todo.member.id ?: Long.MAX_VALUE
    }

    private fun isTaggedForViewer(todo: Todo, viewer: Member): Boolean {
        return todo.member.id != viewer.id
    }

    private fun findMember(loginMember: LoginMember): Member =
        memberRepository.findById(loginMember.id)
            .orElseThrow { IllegalArgumentException("Member not found") }

    private fun findTodoForTagUpdate(id: UUID): Todo =
        todoRepository.findByIdForUpdate(id)
            .orElseThrow { IllegalArgumentException("Todo not found") }

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
        if (todo.hasTag(friend)) {
            return
        }
        if (!friendService.isFriend(todo.member, friend)) {
            throw AuthException("todo.tag.notFriend")
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

    private fun publishTodoStatusChangedEvents(todo: Todo, actor: Member, newStatus: TodoStatus) {
        val actorId = actor.id ?: return
        val recipientIds = buildSet {
            todo.member.id?.let(::add)
            todo.tags.mapNotNullTo(this) { it.member.id }
        }
            .filterNot { it == actorId }

        recipientIds.forEach { recipientId ->
            eventPublisher.publishEvent(
                TodoStatusChangedEvent(
                    todoId = todo.id,
                    actorId = actorId,
                    recipientMemberId = recipientId,
                    todoTitle = todo.title,
                    newStatus = newStatus
                )
            )
        }
    }

    private fun boardOrderComparator(viewer: Member): Comparator<Todo> {
        return Comparator { left, right ->
            val leftTagged = isTaggedForViewer(left, viewer)
            val rightTagged = isTaggedForViewer(right, viewer)

            when {
                leftTagged && rightTagged -> compareValuesBy(
                    right,
                    left,
                    { it.lastModifiedDate },
                    { it.createdDate },
                    { it.id.toString() }
                )

                leftTagged != rightTagged -> if (leftTagged) -1 else 1

                else -> compareValuesBy(
                    left,
                    right,
                    { it.position ?: Int.MAX_VALUE },
                    { it.createdDate },
                    { it.id.toString() }
                )
            }
        }
    }

    private fun completedOrderComparator(viewer: Member): Comparator<Todo> {
        return compareBy<Todo>({ it.member.id != viewer.id })
            .thenByDescending { it.completedDate ?: LocalDateTime.MIN }
            .thenBy { it.createdDate }
    }

    private fun dueDateOrderComparator(viewer: Member): Comparator<Todo> {
        return compareBy<Todo>({ it.dueDate ?: LocalDate.MAX })
            .thenBy { it.member.id != viewer.id }
            .thenBy { ownerScopedSortKey(it, viewer) }
            .thenBy { it.position ?: Int.MAX_VALUE }
            .thenBy { it.createdDate }
    }

}
