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
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
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
        val member = loginMemberToMember(loginMember)
        return friendRelationRepository.findAllByMember(member)
            .map { it.friend }
            .map { MemberDto(it) }
    }

    @Transactional(readOnly = true)
    fun getMyFriendInfo(loginMember: LoginMember): FriendsInfoDto {
        val member = loginMemberToMember(loginMember)
        val friends = findAllFriends(loginMember)
        val pendingRequestsTo = getPendingRequestsTo(member).map { FriendRequestDto(it) }
        val pendingRequestsFrom = getPendingRequestsFrom(member).map { FriendRequestDto(it) }
        return FriendsInfoDto(friends, pendingRequestsTo, pendingRequestsFrom)
    }

    private fun getPendingRequestsTo(member: Member): List<FriendRequest> {
        return friendRequestRepository.findAllByToMemberAndStatus(member, PENDING)
    }

    private fun getPendingRequestsFrom(member: Member): List<FriendRequest> {
        return friendRequestRepository.findAllByFromMemberAndStatus(member, PENDING)
    }

    fun sendFriendRequest(loginMember: LoginMember, toMemberId: Long) {
        val fromMember = loginMemberToMember(loginMember)
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
        val fromMember = loginMemberToMember(login)
        val targetMember = memberRepository.findById(targetId).orElseThrow()

        val friendRequest = findPendingOrThrow(fromMember, targetMember)

        if (friendRequest.status != PENDING)
            throw IllegalArgumentException("Already accepted or rejected")
        friendRequestRepository.delete(friendRequest)
    }

    fun rejectFriendRequest(login: LoginMember, toMemberId: Long) {
        val fromMember = memberRepository.findById(toMemberId).orElseThrow()
        val loginMember = loginMemberToMember(login)

        val friendRequest = findPendingOrThrow(fromMember, loginMember)
        friendRequest.status = REJECTED
    }


    fun acceptFriendRequest(login: LoginMember, friendId: Long) {
        val loginMember = loginMemberToMember(login)
        val friend = memberRepository.findById(friendId).orElseThrow()

        val friendRequest = findPendingOrThrow(friend, loginMember)
        deleteViceVersaRequestIfPresent(loginMember, friend)

        friendRequest.accepted()

        friendRelationRepository.save(FriendRelation(loginMember, friend))
        friendRelationRepository.save(FriendRelation(friend, loginMember))
    }

    private fun deleteViceVersaRequestIfPresent(loginMember: Member, friend: Member) {
        friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(
            fromMember = loginMember, toMember = friend, PENDING
        ).firstOrNull()?.let {
            friendRequestRepository.delete(it)
        }
    }

    fun unfriend(login: LoginMember, target: Long) {
        val loginMember = loginMemberToMember(login)
        val targetMember = memberRepository.findById(target).orElseThrow()

        val isFriend = isFriend(loginMember, targetMember)
        if (!isFriend)
            throw IllegalArgumentException("Not friend")

        friendRelationRepository.deleteByMemberAndFriend(loginMember, targetMember)
        friendRelationRepository.deleteByMemberAndFriend(targetMember, loginMember)
    }

    @Transactional(readOnly = true)
    fun isFriend(member1: Member, member2: Member): Boolean {
        return friendRelationRepository.findByMemberAndFriend(member1, member2) != null
    }

    private fun findPendingOrThrow(from: Member, to: Member): FriendRequest {
        return friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(
            from, to, PENDING
        ).firstOrNull()
            ?: throw IllegalArgumentException("No pending request")
    }

    @Transactional(readOnly = true)
    fun searchPossibleFriends(login: LoginMember, keyword: String, page: Pageable): Page<MemberDto> {
        val member = loginMemberToMember(login)

        val friends = findAllFriends(login).map { it.id }
        val pendingRequestsFrom = getPendingRequestsFrom(member).map { it.toMember.id }
        val excludeIds = friends + pendingRequestsFrom + member.id

        return memberRepository.findMembersByNameContainingIgnoreCaseAndIdNotIn(keyword, excludeIds, page)
            .map { MemberDto(it) }
    }

    private fun loginMemberToMember(login: LoginMember): Member {
        return memberRepository.findById(login.id).orElseThrow()
    }
}
