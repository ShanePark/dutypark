package com.tistory.shanepark.dutypark.todo.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*

@Entity
class Todo(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @Column(name = "title", nullable = false, length = 50)
    var title: String,

    @Column(name = "content", nullable = false, length = 50)
    var content: String,

    @Column(name = "position", nullable = false)
    var position: Int,

    ) : EntityBase() {

    fun update(title: String, content: String) {
        this.title = title
        this.content = content
    }

}
