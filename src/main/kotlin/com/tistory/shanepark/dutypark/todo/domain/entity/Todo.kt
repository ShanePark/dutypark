package com.tistory.shanepark.dutypark.todo.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
class Todo(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @Column(name = "title", nullable = false, length = 50)
    var title: String,

    @Column(name = "content", nullable = false, length = 50)
    var content: String,

    @Column(name = "position")
    var position: Int?,

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    var status: TodoStatus = TodoStatus.ACTIVE,

    @Column(name = "completed_date")
    var completedDate: LocalDateTime? = null,

    ) : EntityBase() {

    fun update(title: String, content: String) {
        this.title = title
        this.content = content
    }

    fun markCompleted(completedAt: LocalDateTime = LocalDateTime.now()) {
        status = TodoStatus.COMPLETED
        completedDate = completedAt
        position = null
    }

    fun markActive(newPosition: Int) {
        status = TodoStatus.ACTIVE
        position = newPosition
        completedDate = null
    }

}
