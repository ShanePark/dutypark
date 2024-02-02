package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import org.springframework.data.jpa.repository.JpaRepository

interface FriendRequestRepository : JpaRepository<FriendRequest, Long> {

    fun findByFromMemberAndToMember(fromMember: Member, toMember: Member): FriendRequest?

    fun findAllByToMemberAndStatus(toMember: Member, status: FriendRequestStatus): List<FriendRequest>
    fun findAllByFromMemberAndStatus(fromMember: Member, status: FriendRequestStatus): List<FriendRequest>

}
