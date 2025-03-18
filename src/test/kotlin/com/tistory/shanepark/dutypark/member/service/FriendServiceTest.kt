package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.data.domain.Pageable

class FriendServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var friendService: FriendService

    @Autowired
    lateinit var friendRequestRepository: FriendRequestRepository

    /*************************************************
     * Friend Requests
     ***********************************************/

    @Test
    fun `send friend request success`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        assertThat(friendService.isFriend(member1, member2)).isFalse

        // When
        friendService.sendFriendRequest(loginMember(member1), member2.id!!)

        // Then
        assertThat(friendRequestRepository.findAllByToMemberAndStatus(member2, FriendRequestStatus.PENDING)).hasSize(1)
        assertThat(
            friendRequestRepository.findAllByFromMemberAndStatus(
                member1,
                FriendRequestStatus.PENDING
            )
        ).hasSize(1)
        assertThat(
            friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(
                member1,
                member2,
                FriendRequestStatus.PENDING
            )
        ).isNotNull
        assertThat(friendService.isFriend(member1, member2)).isFalse
    }

    @Test
    fun `cannot send friend request to friend`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendRelationRepository.save(FriendRelation(member1, member2))

        // Then
        assertThrows<IllegalArgumentException> {
            friendService.sendFriendRequest(loginMember(member1), member2.id!!)
        }
    }

    @Test
    fun `can't send friend request to self`() {
        // Given
        val self = TestData.member

        // Then
        assertThrows<IllegalArgumentException> {
            friendService.sendFriendRequest(loginMember(self), self.id!!)
        }
    }

    @Test
    fun `cannot send friend request to friend twice`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendRequestRepository.save(FriendRequest(member1, member2))

        // Then
        assertThrows<IllegalArgumentException> {
            friendService.sendFriendRequest(loginMember(member1), member2.id!!)
        }
    }

    @Test
    fun `Cancel friend request test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendRequestRepository.save(FriendRequest(member1, member2))

        assertThat(getPendingRequestsTo(member2)).hasSize(1)
        assertThat(getPendingRequestsFrom(member1)).hasSize(1)

        // When
        friendService.cancelFriendRequest(loginMember(member1), member2.id!!)

        // Then
        assertThat(getPendingRequestsTo(member2)).isEmpty()
        assertThat(getPendingRequestsFrom(member1)).isEmpty()
    }

    @Test
    fun `Can't cancel friend request if there is no pending request`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendRequestRepository.save(FriendRequest(member1, member2).apply { accepted() })

        // Then
        assertThrows<IllegalArgumentException> { friendService.cancelFriendRequest(loginMember(member1), member2.id!!) }
    }

    @Test
    fun `Reject friend request test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendRequestRepository.save(FriendRequest(member1, member2))

        assertThat(getPendingRequestsTo(member2)).hasSize(1)
        assertThat(getPendingRequestsFrom(member1)).hasSize(1)

        // When
        friendService.rejectFriendRequest(loginMember(member2), member1.id!!)

        // Then
        assertThat(getPendingRequestsTo(member2)).isEmpty()
        assertThat(getPendingRequestsFrom(member1)).isEmpty()
    }

    @Test
    fun `Accept friend request test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendRequestRepository.save(FriendRequest(fromMember = member2, toMember = member1))

        assertThat(friendService.isFriend(member1, member2)).isFalse

        // When
        friendService.acceptFriendRequest(loginMember(member1), member2.id!!)

        // Then
        assertThat(friendService.isFriend(member1, member2)).isTrue
    }

    @Test
    fun `Can't accept friend request if there is no pending request`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendRequestRepository.save(FriendRequest(fromMember = member1, toMember = member2))

        // Then
        assertThrows<IllegalArgumentException> { friendService.acceptFriendRequest(loginMember(member1), member2.id!!) }
    }

    @Test
    fun `if there were vice versa request when accept friend request, delete it`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendRequestRepository.save(FriendRequest(fromMember = member2, toMember = member1))
        friendRequestRepository.save(FriendRequest(fromMember = member1, toMember = member2))

        assertThat(friendService.isFriend(member1, member2)).isFalse

        // When
        friendService.acceptFriendRequest(loginMember(member1), member2.id!!)

        // Then
        assertThat(friendService.isFriend(member1, member2)).isTrue
        assertThat(getPendingRequestsTo(member1)).isEmpty()
        assertThat(getPendingRequestsTo(member2)).isEmpty()
    }

    @Test
    fun `findFriendRequests test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        assertThat(getPendingRequestsTo(member1)).isEmpty()
        assertThat(getPendingRequestsTo(member2)).isEmpty()

        friendRequestRepository.save(FriendRequest(member2, member1))

        // When
        val friendRequests = getPendingRequestsTo(member1)

        // Then
        assertThat(friendRequests).hasSize(1)
        assertThat(friendRequests[0].fromMember.id).isEqualTo(member2.id)
        assertThat(getPendingRequestsTo(member2)).isEmpty()
        assertThat(getPendingRequestsFrom(member2)).hasSize(1)
    }

    @Test
    fun `getPendingFriendRequest does not include accepted requests`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        assertThat(getPendingRequestsTo(member1)).isEmpty()
        assertThat(getPendingRequestsTo(member2)).isEmpty()

        friendRequestRepository.save(FriendRequest(member2, member1).apply { accepted() })

        // When
        val friendRequests = getPendingRequestsTo(member1)

        // Then
        assertThat(friendRequests).isEmpty()
        assertThat(getPendingRequestsTo(member2)).isEmpty()
        assertThat(getPendingRequestsFrom(member2)).isEmpty()
    }

    /*************************************************
     * Friendship
     ***********************************************/

    @Test
    fun `find All Friends test`() {
        // Given
        val member1 = loginMember(TestData.member)
        val member2 = loginMember(TestData.member2)
        assertThat(friendService.findAllFriends(member1)).isEmpty()
        assertThat(friendService.findAllFriends(member2)).isEmpty()

        setFriend(TestData.member, TestData.member2)
        em.flush()
        em.clear()

        // When
        val friends = friendService.findAllFriends(member1)

        // Then
        assertThat(friends).hasSize(1)
        assertThat(friends[0].id).isEqualTo(member2.id)
        assertThat(friendService.findAllFriends(member2)).hasSize(1)
    }

    @Test
    fun `Unfriend test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        setFriend(member1, member2)

        assertThat(friendService.isFriend(member1, member2)).isTrue

        // When
        friendService.unfriend(loginMember(member1), member2.id!!)

        // Then
        assertThat(friendService.isFriend(member1, member2)).isFalse
    }

    @Test
    fun `Can't unfriend if not friend`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2

        assertThat(friendService.isFriend(member1, member2)).isFalse

        // Then
        assertThrows<IllegalArgumentException> { friendService.unfriend(loginMember(member1), member2.id!!) }
    }

    @Test
    fun `isFriend test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        assertThat(friendService.isFriend(member1, member2)).isFalse

        setFriend(member1, member2)

        // When
        val isFriend = friendService.isFriend(member1, member2)

        // Then
        assertThat(isFriend).isTrue
    }

    @Test
    fun `search Possible friends test - must not include self`() {
        val loginMember = loginMember(TestData.member)

        val page = Pageable.ofSize(5)
        val searchResult = friendService.searchPossibleFriends(loginMember, "", page)

        assertThat(searchResult.content).noneMatch { it.id == loginMember.id }
    }

    @Test
    fun `search Possible friends test - must not include friends`() {
        val loginMember = loginMember(TestData.member)
        val friend = TestData.member2
        setFriend(TestData.member, friend)

        val page = Pageable.ofSize(5)
        val searchResult = friendService.searchPossibleFriends(loginMember, "", page)

        assertThat(searchResult.content).noneMatch { it.id == friend.id }
    }

    @Test
    fun `search Possible friends test - must not include pending requests`() {
        val loginMember = loginMember(TestData.member)
        val taget = TestData.member2
        friendRequestRepository.save(FriendRequest(fromMember = TestData.member, toMember = taget))

        val page = Pageable.ofSize(5)
        val searchResult = friendService.searchPossibleFriends(loginMember, "", page)

        assertThat(searchResult).isNotEmpty
        assertThat(searchResult.content).noneMatch { it.id == taget.id }
    }

    @Test
    fun `check visibility can't pass if the setting is private and login is not his manager and they are not in same team`() {
        val loginMember = loginMember(TestData.member)
        val targetMember = TestData.member2
        targetMember.calendarVisibility = Visibility.PRIVATE

        TestData.member.team = TestData.team
        targetMember.team = TestData.team2
        memberRepository.save(TestData.member)
        memberRepository.save(targetMember)

        assertThrows<DutyparkAuthException> {
            friendService.checkVisibility(loginMember, targetMember)
        }
    }

    @Test
    fun `check visibility pass even if the setting is private, when login is his manager`() {
        // Given
        val viewer = TestData.member
        val loginMember = loginMember(viewer)
        val targetMember = TestData.member2

        // When
        TestData.team.admin = viewer
        teamRepository.save(TestData.team)
        targetMember.team = TestData.team
        memberRepository.save(targetMember)

        // Then no exception
        friendService.checkVisibility(login = loginMember, target = targetMember)
    }

    private fun setFriend(
        member1: Member,
        member2: Member
    ) {
        friendRelationRepository.save(FriendRelation(member1, member2))
        friendRelationRepository.save(FriendRelation(member2, member1))
    }

    private fun getPendingRequestsTo(member: Member): List<FriendRequest> {
        return friendRequestRepository.findAllByToMemberAndStatus(member, FriendRequestStatus.PENDING)
    }

    private fun getPendingRequestsFrom(member: Member): List<FriendRequest> {
        return friendRequestRepository.findAllByFromMemberAndStatus(member, FriendRequestStatus.PENDING)
    }

}


