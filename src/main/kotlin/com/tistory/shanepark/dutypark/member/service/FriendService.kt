package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.dto.FriendDto
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus.PENDING
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus.REJECTED
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestType
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.event.FamilyRequestAcceptedEvent
import com.tistory.shanepark.dutypark.notification.event.FamilyRequestSentEvent
import com.tistory.shanepark.dutypark.notification.event.FriendRequestAcceptedEvent
import com.tistory.shanepark.dutypark.notification.event.FriendRequestSentEvent
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.context.ApplicationEventPublisher
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class FriendService(
    private val friendRelationRepository: FriendRelationRepository,
    private val friendRequestRepository: FriendRequestRepository,
    private val memberService: MemberService,
    private val memberRepository: MemberRepository,
    private val eventPublisher: ApplicationEventPublisher,
) {

    @Transactional(readOnly = true)
    fun findAllFriends(loginMember: LoginMember): List<FriendDto> {
        val member = loginMemberToMember(loginMember)
        val relations = friendRelationRepository.findAllByMember(member)
        return relations
            .sortedWith(compareBy({ it.pinOrder ?: Long.MAX_VALUE }, { it.friend.name }))
            .map { FriendDto.of(it.friend) }
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

        val savedRequest = friendRequestRepository.save(FriendRequest(fromMember, toMember))
        eventPublisher.publishEvent(
            FriendRequestSentEvent(
                requestId = savedRequest.id!!,
                fromMemberId = fromMember.id!!,
                toMemberId = toMember.id!!
            )
        )
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

        val savedRequest = friendRequestRepository.save(
            FriendRequest(
                fromMember = fromMember,
                toMember = toMember,
                requestType = FriendRequestType.FAMILY_REQUEST
            )
        )
        eventPublisher.publishEvent(
            FamilyRequestSentEvent(
                requestId = savedRequest.id!!,
                fromMemberId = fromMember.id!!,
                toMemberId = toMember.id!!
            )
        )
    }

    fun cancelFriendRequest(loginMember: LoginMember, targetId: Long) {
        val fromMember = loginMemberToMember(loginMember)
        val targetMember = memberRepository.findById(targetId).orElseThrow()

        val friendRequest = findPendingFriendRequestOrThrow(fromMember, targetMember)
        friendRequestRepository.delete(friendRequest)
    }

    fun rejectFriendRequest(loginMember: LoginMember, toMemberId: Long) {
        val fromMember = memberRepository.findById(toMemberId).orElseThrow()
        val member = loginMemberToMember(loginMember)

        val friendRequest = findPendingFriendRequestOrThrow(fromMember, member)
        friendRequest.status = REJECTED
    }

    fun acceptFriendRequest(loginMember: LoginMember, friendId: Long) {
        val member = loginMemberToMember(loginMember)
        val friend = memberRepository.findById(friendId).orElseThrow()

        val friendRequest = findPendingFriendRequestOrThrow(friend, member)
        deleteViceVersaRequestIfPresent(member, friend)
        friendRequest.accepted()

        when (friendRequest.requestType) {
            FriendRequestType.FRIEND_REQUEST -> {
                setFriend(member, friend)
                eventPublisher.publishEvent(
                    FriendRequestAcceptedEvent(
                        requestId = friendRequest.id!!,
                        fromMemberId = friend.id!!,
                        toMemberId = member.id!!
                    )
                )
            }
            FriendRequestType.FAMILY_REQUEST -> {
                setFamily(member, friend)
                eventPublisher.publishEvent(
                    FamilyRequestAcceptedEvent(
                        requestId = friendRequest.id!!,
                        fromMemberId = friend.id!!,
                        toMemberId = member.id!!
                    )
                )
            }
        }
    }

    private fun setFriend(loginMember: Member, friend: Member) {
        friendRelationRepository.save(FriendRelation(loginMember, friend))
        friendRelationRepository.save(FriendRelation(friend, loginMember))
    }

    private fun setFamily(member1: Member, member2: Member) {
        updateFamilyStatus(member1, member2)
        updateFamilyStatus(member2, member1)
    }

    private fun updateFamilyStatus(member: Member, friend: Member) {
        friendRelationRepository.findByMemberAndFriend(member, friend)?.let {
            it.isFamily = true
        } ?: throw IllegalArgumentException("Not friend")
    }

    fun demoteFromFamily(loginMember: LoginMember, toMemberId: Long) {
        val member = loginMemberToMember(loginMember)
        val friend = memberRepository.findById(toMemberId).orElseThrow()

        if (!isFamily(member, friend)) {
            throw IllegalStateException("Not family")
        }

        removeFamilyStatus(member, friend)
        removeFamilyStatus(friend, member)
    }

    private fun removeFamilyStatus(member: Member, friend: Member) {
        friendRelationRepository.findByMemberAndFriend(member, friend)?.let {
            it.isFamily = false
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
    fun searchPossibleFriends(login: LoginMember, keyword: String, page: Pageable): Page<FriendDto> {
        val result = memberRepository.searchPossibleFriends(keyword, login.id, page)
        return result.map { FriendDto.of(it) }
    }

    private fun loginMemberToMember(login: LoginMember): Member {
        return memberRepository.findById(login.id).orElseThrow()
    }

    @Transactional(readOnly = true)
    fun checkVisibility(login: LoginMember?, target: Member, scheduleVisibilityCheck: Boolean = false) {
        if (!isVisible(login, target.id, scheduleVisibilityCheck = scheduleVisibilityCheck))
            throw AuthException("${target.name} Calendar is not visible to ${login?.name}")
    }

    @Transactional(readOnly = true)
    fun checkVisibility(login: LoginMember?, targetId: Long, scheduleVisibilityCheck: Boolean = false) {
        val target = memberRepository.findById(targetId).orElseThrow()
        checkVisibility(login, target, scheduleVisibilityCheck)
    }

    @Transactional(readOnly = true)
    fun isVisible(login: LoginMember?, targetId: Long?, scheduleVisibilityCheck: Boolean = false): Boolean {
        val targetMember = memberRepository.findById(targetId!!).orElseThrow()
        login ?: return targetMember.calendarVisibility == Visibility.PUBLIC

        val loginMember = memberRepository.findById(login.id).orElseThrow()
        if (login.id == targetMember.id)
            return true
        if (!scheduleVisibilityCheck && isSameTeam(loginMember, targetMember))
            return true
        if (memberService.isManager(login, targetMember))
            return true
        return when (targetMember.calendarVisibility) {
            Visibility.PUBLIC -> true
            Visibility.FRIENDS -> isFriend(loginMember, targetMember)
            Visibility.FAMILY -> isFamily(member1 = loginMember, member2 = targetMember)
            Visibility.PRIVATE -> false
        }
    }

    private fun isSameTeam(
        loginMember: Member,
        targetMember: Member
    ): Boolean {
        return loginMember.team == targetMember.team
    }

    @Transactional(readOnly = true)
    fun availableScheduleVisibilities(loginMember: LoginMember?, member: Member): Set<Visibility> {
        if (loginMember == null)
            return Visibility.publicOnly()
        if (loginMember.id == member.id || memberService.isManager(loginMember, member)) {
            return Visibility.all()
        }
        val login = loginMemberToMember(loginMember)
        if (isFamily(member1 = login, member2 = member)) {
            return Visibility.family()
        }
        if (isFriend(login, member)) {
            return Visibility.friends()
        }
        return Visibility.publicOnly()
    }

    @Transactional(readOnly = true)
    fun buildScheduleVisibilityMap(
        loginMember: LoginMember,
        friendRelations: List<FriendRelation>
    ): Map<Long, Set<Visibility>> {
        if (friendRelations.isEmpty()) {
            return emptyMap()
        }

        val managedMemberIds = memberService.findManagedMemberIds(loginMember)

        return friendRelations.associate { relation ->
            val friendId = relation.friend.id ?: throw IllegalStateException("Friend id is null")
            val visibilities = when {
                friendId == loginMember.id -> Visibility.all()
                managedMemberIds.contains(friendId) -> Visibility.all()
                relation.isFamily -> Visibility.family()
                else -> Visibility.friends()
            }
            friendId to visibilities
        }
    }

    fun pinFriend(loginMember: LoginMember, friendId: Long) {
        val login = loginMemberToMember(loginMember)
        val friend = memberRepository.findById(friendId).orElseThrow()
        friendRelationRepository.findByMemberAndFriend(member = login, friend = friend)?.let {
            it.pinOrder = System.currentTimeMillis()
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

    @Transactional(readOnly = true)
    fun findAllFamilyMembers(id: Long): List<FriendDto> {
        val member = memberRepository.findById(id).orElseThrow()
        val familyRelations = friendRelationRepository.findAllByMember(member).filter { it.isFamily }
        return familyRelations
            .map { FriendDto.of(it.friend) }
            .sortedBy { it.name }
    }

}
