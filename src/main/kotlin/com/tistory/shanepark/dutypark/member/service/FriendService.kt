package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus.PENDING
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus.REJECTED
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.enums.FriendRequestType
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
            .sortedWith(compareBy({ it.friend.department?.name }, { it.friend.name }))
            .map { it.friend }
            .map { MemberDto.of(it) }
    }

    fun getPendingRequestsTo(member: Member): List<FriendRequest> {
        return friendRequestRepository.findAllByToMemberAndStatus(member, PENDING)
    }

    fun getPendingRequestsFrom(member: Member): List<FriendRequest> {
        return friendRequestRepository.findAllByFromMemberAndStatus(member, PENDING)
    }

    fun sendFriendRequest(loginMember: LoginMember, toMemberId: Long) {
        val fromMember = loginMemberToMember(loginMember)
        val toMember = memberRepository.findById(toMemberId).orElseThrow()

        if (fromMember == toMember)
            throw IllegalArgumentException("Cannot send friend request to self")

        if (isFriend(fromMember, toMember))
            throw IllegalArgumentException("Already friend")

        val pending =
            friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(fromMember, toMember, PENDING)

        if (pending.isNotEmpty())
            throw IllegalArgumentException("Already requested")

        friendRequestRepository.save(FriendRequest(fromMember, toMember))
    }


    fun sendFamilyRequest(loginMember: LoginMember, toMemberId: Long) {
        val fromMember = loginMemberToMember(loginMember)
        val toMember = memberRepository.findById(toMemberId).orElseThrow()

        if (!isFriend(fromMember, toMember)) {
            throw IllegalStateException("Not friend")
        }

        if (isFamily(fromMember, toMember)) {
            throw IllegalStateException("Already family")
        }

        val pending = friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(fromMember, toMember, PENDING)
        if (pending.isNotEmpty())
            throw IllegalArgumentException("Already requested")

        friendRequestRepository.save(
            FriendRequest(
                fromMember = fromMember,
                toMember = toMember,
                requestType = FriendRequestType.FAMILY_REQUEST
            )
        )
    }

    fun cancelFriendRequest(login: LoginMember, targetId: Long) {
        val fromMember = loginMemberToMember(login)
        val targetMember = memberRepository.findById(targetId).orElseThrow()

        val friendRequest = findPendingFriendRequestOrThrow(fromMember, targetMember)
        friendRequestRepository.delete(friendRequest)
    }

    fun rejectFriendRequest(login: LoginMember, toMemberId: Long) {
        val fromMember = memberRepository.findById(toMemberId).orElseThrow()
        val loginMember = loginMemberToMember(login)

        val friendRequest = findPendingFriendRequestOrThrow(fromMember, loginMember)
        friendRequest.status = REJECTED
    }


    fun acceptFriendRequest(login: LoginMember, friendId: Long) {
        val loginMember = loginMemberToMember(login)
        val friend = memberRepository.findById(friendId).orElseThrow()

        val friendRequest = findPendingFriendRequestOrThrow(friend, loginMember)
        deleteViceVersaRequestIfPresent(loginMember, friend)
        friendRequest.accepted()

        when (friendRequest.requestType) {
            FriendRequestType.FRIEND_REQUEST -> setFriend(loginMember, friend)
            FriendRequestType.FAMILY_REQUEST -> setFamily(loginMember, friend)
        }
    }

    private fun setFriend(loginMember: Member, friend: Member) {
        friendRelationRepository.save(FriendRelation(loginMember, friend))
        friendRelationRepository.save(FriendRelation(friend, loginMember))
    }

    private fun setFamily(member1: Member, member2: Member) {
        friendRelationRepository.findByMemberAndFriend(member1, member2)?.let {
            it.isFamily = true
        } ?: throw IllegalArgumentException("Not friend")
        friendRelationRepository.findByMemberAndFriend(member2, member1)?.let {
            it.isFamily = true
        } ?: throw IllegalArgumentException("Not friend")
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

    @Transactional(readOnly = true)
    fun isFamily(member1: Member, member2: Member): Boolean {
        friendRelationRepository.findByMemberAndFriend(member2, member1)?.let {
            return it.isFamily
        }
        return false
    }

    private fun findPendingFriendRequestOrThrow(from: Member, to: Member): FriendRequest {
        return friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(
            from, to, PENDING
        ).firstOrNull() ?: throw IllegalArgumentException("No pending request")
    }

    @Transactional(readOnly = true)
    fun searchPossibleFriends(login: LoginMember, keyword: String, page: Pageable): Page<MemberDto> {
        val member = loginMemberToMember(login)

        val friends = findAllFriends(login).map { it.id }
        val pendingRequestsFrom = getPendingRequestsFrom(member).map { it.toMember.id }
        val excludeIds = friends + pendingRequestsFrom + member.id

        return memberRepository.findMembersByNameContainingIgnoreCaseAndIdNotIn(keyword, excludeIds, page)
            .map { MemberDto.of(it) }
    }

    private fun loginMemberToMember(login: LoginMember): Member {
        return memberRepository.findById(login.id).orElseThrow()
    }

    fun checkVisibility(login: LoginMember?, target: Member, scheduleVisibilityCheck: Boolean = false) {
        if (!isVisible(login, target.id, scheduleVisibilityCheck = scheduleVisibilityCheck))
            throw DutyparkAuthException("${target.name} Calendar is not visible to ${login?.name}")
    }

    fun isVisible(login: LoginMember?, targetId: Long?, scheduleVisibilityCheck: Boolean = false): Boolean {
        val targetMember = memberRepository.findById(targetId!!).orElseThrow()
        login ?: return targetMember.calendarVisibility == Visibility.PUBLIC

        val loginMember = memberRepository.findById(login.id).orElseThrow()
        if (login.id == targetMember.id)
            return true
        if (!scheduleVisibilityCheck && (login.departmentId == targetMember.department?.id))
            return true
        if (targetMember.department?.manager?.id == login.id)
            return true
        return when (targetMember.calendarVisibility) {
            Visibility.PUBLIC -> true
            Visibility.FRIENDS -> isFriend(loginMember, targetMember)
            Visibility.FAMILY -> isFamily(member1 = loginMember, member2 = targetMember);
            Visibility.PRIVATE -> false
        }
    }

    @Transactional(readOnly = true)
    fun availableScheduleVisibilities(loginMember: LoginMember?, member: Member): Set<Visibility> {
        if (loginMember == null)
            return setOf(Visibility.PUBLIC)
        if (loginMember.id == member.id) {
            return Visibility.entries.toSet()
        }
        val login = loginMemberToMember(loginMember)
        if (isFamily(member1 = login, member2 = member)) {
            return setOf(Visibility.PUBLIC, Visibility.FRIENDS, Visibility.FAMILY)
        }
        if (isFriend(login, member)) {
            return setOf(Visibility.PUBLIC, Visibility.FRIENDS)
        }
        return setOf(Visibility.PUBLIC)
    }

    fun pinFriend(loginMember: LoginMember, friendId: Long) {
        val login = loginMemberToMember(loginMember)
        val friend = memberRepository.findById(friendId).orElseThrow()
        friendRelationRepository.findByMemberAndFriend(member = login, friend = friend)?.let {
            it.pinOrder = -System.currentTimeMillis()
        } ?: throw IllegalArgumentException("Not friend")
    }

    fun unpinFriend(loginMember: LoginMember, friendId: Long) {
        val login = loginMemberToMember(loginMember)
        val friend = memberRepository.findById(friendId).orElseThrow()
        friendRelationRepository.findByMemberAndFriend(member = login, friend = friend)?.let {
            it.pinOrder = null
        } ?: throw IllegalArgumentException("Not friend")
    }

    fun updateFriendsPin(loginMember: LoginMember, friendIds: List<Long>) {
        val login = loginMemberToMember(loginMember)
        val friends = memberRepository.findAllById(friendIds)
        val friendMap = friendRelationRepository.findAllByMemberAndFriendIn(login, friends)
            .filter { it.pinOrder != null }
            .associateBy { it.friend.id }
        friendIds.forEachIndexed { index, friendId ->
            friendMap[friendId]?.let {
                it.pinOrder = index.toLong() + 1
            }
        }
    }

}
