package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired

class FriendServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var friendService: FriendService

    @Autowired
    lateinit var friendRelationRepository: FriendRelationRepository

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
        friendService.sendFriendRequest(member1, member2)

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
        assertThrows<IllegalArgumentException> { friendService.sendFriendRequest(member1, member2) }
    }

    @Test
    fun `can't send friend request to self`() {
        // Given
        val self = TestData.member

        // Then
        assertThrows<IllegalArgumentException> { friendService.sendFriendRequest(self, self) }
    }

    @Test
    fun `cannot send friend request to friend twice`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendRequestRepository.save(FriendRequest(member1, member2))

        // Then
        assertThrows<IllegalArgumentException> { friendService.sendFriendRequest(member1, member2) }
    }

    @Test
    fun `Cancel friend request test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendRequestRepository.save(FriendRequest(member1, member2))

        assertThat(friendService.getPendingRequestsTo(member2)).hasSize(1)
        assertThat(friendService.getPendingRequestsFrom(member1)).hasSize(1)

        // When
        friendService.cancelFriendRequest(member1, member2)

        // Then
        assertThat(friendService.getPendingRequestsTo(member2)).isEmpty()
        assertThat(friendService.getPendingRequestsFrom(member1)).isEmpty()
    }

    @Test
    fun `Can't cancle friend request if not pending`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendRequestRepository.save(FriendRequest(member1, member2).apply { accepted() })

        // Then
        assertThrows<IllegalArgumentException> { friendService.cancelFriendRequest(member1, member2) }
    }

    @Test
    fun `Reject friend request test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendRequestRepository.save(FriendRequest(member1, member2))

        assertThat(friendService.getPendingRequestsTo(member2)).hasSize(1)
        assertThat(friendService.getPendingRequestsFrom(member1)).hasSize(1)

        // When
        friendService.rejectFriendRequest(member1, member2)

        // Then
        assertThat(friendService.getPendingRequestsTo(member2)).isEmpty()
        assertThat(friendService.getPendingRequestsFrom(member1)).isEmpty()
    }

    @Test
    fun `Accept friend request test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendRequestRepository.save(FriendRequest(member2, member1))

        assertThat(friendService.isFriend(member1, member2)).isFalse

        // When
        friendService.acceptFriendRequest(member2, member1)

        // Then
        assertThat(friendService.isFriend(member1, member2)).isTrue
    }

    @Test
    fun `findFriendRequests test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        assertThat(friendService.getPendingRequestsTo(member1)).isEmpty()
        assertThat(friendService.getPendingRequestsTo(member2)).isEmpty()

        friendRequestRepository.save(FriendRequest(member2, member1))

        // When
        val friendRequests = friendService.getPendingRequestsTo(member1)

        // Then
        assertThat(friendRequests).hasSize(1)
        assertThat(friendRequests[0].fromMember.id).isEqualTo(member2.id)
        assertThat(friendService.getPendingRequestsTo(member2)).isEmpty()
        assertThat(friendService.getPendingRequestsFrom(member2)).hasSize(1)
    }

    @Test
    fun `getPendingFriendRequest does not include accepted requests`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        assertThat(friendService.getPendingRequestsTo(member1)).isEmpty()
        assertThat(friendService.getPendingRequestsTo(member2)).isEmpty()

        friendRequestRepository.save(FriendRequest(member2, member1).apply { accepted() })

        // When
        val friendRequests = friendService.getPendingRequestsTo(member1)

        // Then
        assertThat(friendRequests).isEmpty()
        assertThat(friendService.getPendingRequestsTo(member2)).isEmpty()
        assertThat(friendService.getPendingRequestsFrom(member2)).isEmpty()
    }

    /*************************************************
     * Friendship
     ***********************************************/

    @Test
    fun `find All Friends test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        assertThat(friendService.findAllFriends(member1)).isEmpty()
        assertThat(friendService.findAllFriends(member2)).isEmpty()

        setFriend(member1, member2)

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
        friendService.unfriend(member1, member2)

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
        assertThrows<IllegalArgumentException> { friendService.unfriend(member1, member2) }
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

    private fun setFriend(
        member1: Member,
        member2: Member
    ) {
        friendRelationRepository.save(FriendRelation(member1, member2))
        friendRelationRepository.save(FriendRelation(member2, member1))
    }


}


