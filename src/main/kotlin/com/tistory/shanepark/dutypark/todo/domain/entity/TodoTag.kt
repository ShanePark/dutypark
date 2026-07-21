package com.tistory.shanepark.dutypark.todo.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.BaseTimeEntity
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*

@Entity
@Table(name = "todo_tags")
class TodoTag(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "todo_id", nullable = false)
    val todo: Todo,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @Column(name = "tag_order", nullable = false)
    var tagOrder: Int = 0,

) : BaseTimeEntity() {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

}
