package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository

interface FriendRequestRepository : JpaRepository<FriendRequest, Long> {

    fun findAllByFromMemberAndToMemberAndStatus(
        fromMember: Member,
        toMember: Member,
        status: FriendRequestStatus,
    ): List<FriendRequest>

    @EntityGraph(attributePaths = ["fromMember", "toMember"])
    fun findAllByToMemberAndStatus(toMember: Member, status: FriendRequestStatus): List<FriendRequest>

    @EntityGraph(attributePaths = ["fromMember", "toMember"])
    fun findAllByFromMemberAndStatus(fromMember: Member, status: FriendRequestStatus): List<FriendRequest>

    fun countByToMemberIdAndStatus(toMemberId: Long, status: FriendRequestStatus): Long

}
