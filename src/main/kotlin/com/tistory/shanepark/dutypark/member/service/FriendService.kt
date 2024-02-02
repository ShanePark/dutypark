package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
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
        return friendRequestRepository.findAllByToMemberAndStatus(member, FriendRequestStatus.PENDING)
    }

    @Transactional(readOnly = true)
    fun getPendingRequestsFrom(member: Member): List<FriendRequest> {
        return friendRequestRepository.findAllByFromMemberAndStatus(member, FriendRequestStatus.PENDING)
    }

    fun sendFriendRequest(member1: Member, member2: Member) {
        if (isFriend(member1, member2))
            throw IllegalArgumentException("Already friend")
        friendRequestRepository.save(FriendRequest(member1, member2))
    }

    fun cancelFriendRequest(member1: Member, member2: Member) {
        val friendRequest = friendRequestRepository.findByFromMemberAndToMember(member1, member2)
            ?: throw IllegalArgumentException("There is No friend request from " + member1.id + " to " + member2.id)
        if (friendRequest.status != FriendRequestStatus.PENDING)
            throw IllegalArgumentException("Already accepted or rejected")
        friendRequestRepository.delete(friendRequest)
    }

    fun acceptFriendRequest(member1: Member, member2: Member) {
        val friendRequest = friendRequestRepository.findByFromMemberAndToMember(member1, member2)
            ?: throw IllegalArgumentException("There is No friend request from " + member1.id + " to " + member2.id)

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
        friendRelationRepository.findByMemberAndFriend(member1, member2)
            ?.let { return true }
            .run { return false }
    }

}
