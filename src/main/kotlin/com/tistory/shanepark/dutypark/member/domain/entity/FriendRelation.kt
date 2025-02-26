package com.tistory.shanepark.dutypark.member.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.BaseTimeEntity
import jakarta.persistence.*

@Entity
@Table(name = "friends")
class FriendRelation(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    var member: Member,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "friend_id")
    var friend: Member,

    ) : BaseTimeEntity() {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

    @Column(name = "is_family")
    var isFamily: Boolean = false

    @Column(name = "pin_order")
    var pinOrder: Long? = null

}
