package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.dto.FriendRequestDto
import com.tistory.shanepark.dutypark.member.domain.dto.FriendsInfoDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus.PENDING
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus.REJECTED
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class FriendService(
    private val friendRelationRepository: FriendRelationRepository,
    private val friendRequestRepository: FriendRequestRepository,
    private val memberRepository: MemberRepository
) {

    @Transactional(readOnly = true)
    fun findAllFriends(loginMember: LoginMember): List<MemberDto> {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        return friendRelationRepository.findAllByMember(member)
            .map { it.friend }
            .map { MemberDto(it) }
    }

    @Transactional(readOnly = true)
    fun getMyFriendInfo(loginMember: LoginMember): FriendsInfoDto {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        val friends = findAllFriends(loginMember)
        val pendingRequestsTo = getPendingRequestsTo(member).map { FriendRequestDto(it) }
        val pendingRequestsFrom = getPendingRequestsFrom(member).map { FriendRequestDto(it) }
        return FriendsInfoDto(friends, pendingRequestsTo, pendingRequestsFrom)
    }

    @Transactional(readOnly = true)
    fun getPendingRequestsTo(member: Member): List<FriendRequest> {
        return friendRequestRepository.findAllByToMemberAndStatus(member, PENDING)
    }

    @Transactional(readOnly = true)
    fun getPendingRequestsFrom(member: Member): List<FriendRequest> {
        return friendRequestRepository.findAllByFromMemberAndStatus(member, PENDING)
    }

    fun sendFriendRequest(loginMember: LoginMember, toMemberId: Long) {
        val fromMember = memberRepository.findById(loginMember.id).orElseThrow()
        val toMember = memberRepository.findById(toMemberId).orElseThrow()

        if (fromMember == toMember)
            throw IllegalArgumentException("Cannot send friend request to self")

        if (isFriend(fromMember, toMember))
            throw IllegalArgumentException("Already friend")

        val pending = friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(fromMember, toMember, PENDING)

        if (pending.isNotEmpty())
            throw IllegalArgumentException("Already requested")

        friendRequestRepository.save(FriendRequest(fromMember, toMember))
    }

    fun cancelFriendRequest(login: LoginMember, targetId: Long) {
        val fromMember = memberRepository.findById(login.id).orElseThrow()
        val targetMember = memberRepository.findById(targetId).orElseThrow()

        val friendRequest = findPendingOrThrow(fromMember, targetMember)

        if (friendRequest.status != PENDING)
            throw IllegalArgumentException("Already accepted or rejected")
        friendRequestRepository.delete(friendRequest)
    }

    fun rejectFriendRequest(fromMember: Member, toMember: Member) {
        val friendRequest = findPendingOrThrow(fromMember, toMember)
        friendRequest.status = REJECTED
    }


    fun acceptFriendRequest(login: LoginMember, friendId: Long) {
        val loginMember = memberRepository.findById(login.id).orElseThrow()
        val friend = memberRepository.findById(friendId).orElseThrow()

        val friendRequest = findPendingOrThrow(loginMember, friend)

        friendRequest.accepted()
        friendRelationRepository.save(FriendRelation(loginMember, friend))
        friendRelationRepository.save(FriendRelation(friend, loginMember))
    }

    fun unfriend(login: LoginMember, target: Long) {
        val member = memberRepository.findById(login.id).orElseThrow()
        val targetMember = memberRepository.findById(target).orElseThrow()

        val isFriend = isFriend(member, targetMember)
        if (!isFriend)
            throw IllegalArgumentException("Not friend")

        friendRelationRepository.deleteByMemberAndFriend(member, targetMember)
        friendRelationRepository.deleteByMemberAndFriend(targetMember, member)
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
