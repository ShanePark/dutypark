package com.tistory.shanepark.dutypark.todo.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*
import java.time.LocalDate
import java.time.LocalDateTime

@Entity
class Todo(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @Column(name = "title", nullable = false, length = 50)
    var title: String,

    @Lob
    @Column(name = "content", nullable = false, columnDefinition = "TEXT")
    var content: String,

    @Column(name = "position")
    var position: Int?,

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    var status: TodoStatus = TodoStatus.TODO,

    @Column(name = "completed_date")
    var completedDate: LocalDateTime? = null,

    @Column(name = "due_date")
    var dueDate: LocalDate? = null,

    ) : EntityBase() {

    @OneToMany(mappedBy = "todo", fetch = FetchType.LAZY, cascade = [CascadeType.ALL], orphanRemoval = true)
    val tags: MutableList<TodoTag> = mutableListOf()

    fun update(title: String, content: String) {
        this.title = title
        this.content = content
    }

    fun hasTag(member: Member): Boolean {
        return tags.any { it.member.id == member.id }
    }

    fun addTag(member: Member) {
        tags.find { it.member.id == member.id }
            ?.let { throw IllegalArgumentException("$member is already tagged in todo $this") }

        val todoTag = TodoTag(this, member)
        tags.add(todoTag)
    }

    fun removeTag(member: Member) {
        val removed = tags.removeAll { it.member.id == member.id }
        if (!removed) {
            throw IllegalArgumentException("$member is not tagged in todo $this")
        }
    }

    fun changeStatus(newStatus: TodoStatus, newPosition: Int) {
        val previousStatus = this.status
        this.status = newStatus
        this.position = newPosition

        // Set completedDate when changing to DONE
        if (newStatus == TodoStatus.DONE && previousStatus != TodoStatus.DONE) {
            this.completedDate = LocalDateTime.now()
        }
        // Clear completedDate when changing from DONE to other status
        if (newStatus != TodoStatus.DONE && previousStatus == TodoStatus.DONE) {
            this.completedDate = null
        }
    }

    fun markCompleted(newPosition: Int, completedAt: LocalDateTime = LocalDateTime.now()) {
        status = TodoStatus.DONE
        completedDate = completedAt
        position = newPosition
    }

    fun markActive(newPosition: Int) {
        status = TodoStatus.TODO
        position = newPosition
        completedDate = null
    }

}
