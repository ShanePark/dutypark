package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus.PENDING
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus.REJECTED
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class FriendService(
    private val friendRelationRepository: FriendRelationRepository,
    private val friendRequestRepository: FriendRequestRepository
) {
    @Transactional(readOnly = true)
    fun findAllFriends(member: Member): List<Member> {
        return friendRelationRepository.findAllByMember(member).map { it.friend }
    }

    @Transactional(readOnly = true)
    fun getPendingRequestsTo(member: Member): List<FriendRequest> {
        return friendRequestRepository.findAllByToMemberAndStatus(member, PENDING)
    }

    @Transactional(readOnly = true)
    fun getPendingRequestsFrom(member: Member): List<FriendRequest> {
        return friendRequestRepository.findAllByFromMemberAndStatus(member, PENDING)
    }

    fun sendFriendRequest(member1: Member, member2: Member) {
        if (member1 == member2)
            throw IllegalArgumentException("Cannot send friend request to self")

        if (isFriend(member1, member2))
            throw IllegalArgumentException("Already friend")

        val pending = friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member1, member2, PENDING)

        if (pending.isNotEmpty())
            throw IllegalArgumentException("Already requested")

        friendRequestRepository.save(FriendRequest(member1, member2))
    }

    fun cancelFriendRequest(fromMember: Member, toMember: Member) {
        val friendRequest = findPendingOrThrow(fromMember, toMember)

        if (friendRequest.status != PENDING)
            throw IllegalArgumentException("Already accepted or rejected")
        friendRequestRepository.delete(friendRequest)
    }

    fun rejectFriendRequest(fromMember: Member, toMember: Member) {
        val friendRequest = findPendingOrThrow(fromMember, toMember)
        friendRequest.status = REJECTED
    }


    fun acceptFriendRequest(member1: Member, member2: Member) {
        val friendRequest = findPendingOrThrow(member1, member2)

        friendRequest.accepted()
        friendRelationRepository.save(FriendRelation(member1, member2))
        friendRelationRepository.save(FriendRelation(member2, member1))
    }

    fun unfriend(member1: Member, member2: Member) {
        val isFriend = isFriend(member1, member2)
        if (!isFriend)
            throw IllegalArgumentException("Not friend")

        friendRelationRepository.deleteByMemberAndFriend(member1, member2)
        friendRelationRepository.deleteByMemberAndFriend(member2, member1)
    }

    fun isFriend(member1: Member, member2: Member): Boolean {
        return friendRelationRepository.findByMemberAndFriend(member1, member2) != null
    }

    private fun findPendingOrThrow(from: Member, to: Member): FriendRequest {
        return friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(
            from, to, PENDING
        ).firstOrNull()
            ?: throw IllegalArgumentException("No pending request")
    }

}
