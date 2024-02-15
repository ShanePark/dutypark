package com.tistory.shanepark.dutypark.member.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.BaseTimeEntity
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import jakarta.persistence.*

@Entity
@Table(name = "friend_requests")
class FriendRequest(

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "from_member_id")
    var fromMember: Member,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "to_member_id")
    var toMember: Member,

    @Column(name = "status", nullable = false)
    @Enumerated(EnumType.STRING)
    var status: FriendRequestStatus = FriendRequestStatus.PENDING
) : BaseTimeEntity() {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

    fun accepted() {
        this.status = FriendRequestStatus.ACCEPTED
    }

}
