package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.never
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.context.ApplicationEventPublisher
import org.springframework.test.util.ReflectionTestUtils
import java.util.*

@ExtendWith(MockitoExtension::class)
class FriendServiceUnitTest {

    @Mock
    private lateinit var friendRelationRepository: FriendRelationRepository

    @Mock
    private lateinit var friendRequestRepository: FriendRequestRepository

    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var memberService: MemberService

    @Mock
    private lateinit var eventPublisher: ApplicationEventPublisher

    private lateinit var friendService: FriendService

    @BeforeEach
    fun setUp() {
        friendService = FriendService(
            friendRelationRepository = friendRelationRepository,
            friendRequestRepository = friendRequestRepository,
            memberRepository = memberRepository,
            memberService = memberService,
            eventPublisher = eventPublisher,
        )
    }

    @Test
    fun updateFriendsPin() {
        // Given
        val member = Member(name = "test")
        ReflectionTestUtils.setField(member, "id", 0L)

        val friendIds = listOf(1L, 2L, 3L)
        val dummyFriends = friendIds.map { id ->
            Member(name = "friend$id").let {
                ReflectionTestUtils.setField(it, "id", id)
                it
            }
        }.toList()

        val dummyFriendRelations = dummyFriends.map { friend ->
            FriendRelation(
                member = member,
                friend = friend
            ).apply { pinOrder = 0L }
        }.toList()

        // When
        whenever(memberRepository.findAllById(friendIds)).thenReturn(dummyFriends)
        whenever(memberRepository.findById(member.id!!)).thenReturn(Optional.of(member))
        whenever(friendRelationRepository.findAllByMemberAndFriendIn(member, dummyFriends))
            .thenReturn(dummyFriendRelations)

        friendService.updateFriendsPin(
            loginMember = LoginMember(id = member.id!!, name = member.name),
            friendIds = friendIds
        )

        // Then
        dummyFriendRelations.forEachIndexed { index, relation ->
            assertThat(relation.pinOrder).isEqualTo(index + 1L)
        }
    }

    @Test
    fun `update friends pin does not update NullPinOrder`() {
        // Given
        val member = Member(name = "test")
        ReflectionTestUtils.setField(member, "id", 0L)

        val friendIds = listOf(1L, 2L, 3L)
        val dummyFriends = friendIds.map { id ->
            Member(name = "friend$id").let {
                ReflectionTestUtils.setField(it, "id", id)
                it
            }
        }.toList()

        val pinOrderNullFriendId = friendIds[1]
        val dummyFriendRelations = dummyFriends.mapIndexed { _, friend ->
            FriendRelation(
                member = member,
                friend = friend
            ).apply { pinOrder = if (friend.id == pinOrderNullFriendId) null else 0L }
        }.toList()

        // When
        whenever(memberRepository.findAllById(friendIds)).thenReturn(dummyFriends)
        whenever(memberRepository.findById(member.id!!)).thenReturn(Optional.of(member))
        whenever(friendRelationRepository.findAllByMemberAndFriendIn(member, dummyFriends))
            .thenReturn(dummyFriendRelations)

        friendService.updateFriendsPin(
            loginMember = LoginMember(id = member.id!!, name = member.name),
            friendIds = friendIds
        )

        // Then
        dummyFriendRelations.forEachIndexed { index, relation ->
            if (relation.friend.id != pinOrderNullFriendId) {
                assertThat(relation.pinOrder).isEqualTo(index + 1L)
            } else {
                assertThat(relation.pinOrder).isNull()
            }
        }
    }

    /*************************************************
     * Friend Requests
     ***********************************************/

    @Test
    fun `send friend request success`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")
        val savedRequest = FriendRequest(member1, member2).apply {
            ReflectionTestUtils.setField(this, "id", 1L)
        }

        whenever(memberRepository.findById(member1.id!!)).thenReturn(Optional.of(member1))
        whenever(memberRepository.findById(member2.id!!)).thenReturn(Optional.of(member2))
        whenever(friendRelationRepository.findByMemberAndFriend(member1, member2)).thenReturn(null)
        whenever(friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member1, member2, FriendRequestStatus.PENDING))
            .thenReturn(emptyList())
        whenever(friendRequestRepository.save(any<FriendRequest>())).thenReturn(savedRequest)

        // When
        friendService.sendFriendRequest(loginMember(member1), member2.id!!)

        // Then
        verify(friendRequestRepository).save(any<FriendRequest>())
        verify(eventPublisher).publishEvent(any<Any>())
    }

    @Test
    fun `cannot send friend request to friend`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")
        val friendRelation = FriendRelation(member1, member2)

        whenever(memberRepository.findById(member1.id!!)).thenReturn(Optional.of(member1))
        whenever(memberRepository.findById(member2.id!!)).thenReturn(Optional.of(member2))
        whenever(friendRelationRepository.findByMemberAndFriend(member1, member2)).thenReturn(friendRelation)

        // Then
        assertThrows<IllegalArgumentException> {
            friendService.sendFriendRequest(loginMember(member1), member2.id!!)
        }
        verify(friendRequestRepository, never()).save(any<FriendRequest>())
    }

    @Test
    fun `can't send friend request to self`() {
        // Given
        val self = createMember(1L, "self")

        whenever(memberRepository.findById(self.id!!)).thenReturn(Optional.of(self))

        // Then
        assertThrows<IllegalArgumentException> {
            friendService.sendFriendRequest(loginMember(self), self.id!!)
        }
        verify(friendRequestRepository, never()).save(any<FriendRequest>())
    }

    @Test
    fun `cannot send friend request to friend twice`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")
        val pendingRequest = FriendRequest(member1, member2)

        whenever(memberRepository.findById(member1.id!!)).thenReturn(Optional.of(member1))
        whenever(memberRepository.findById(member2.id!!)).thenReturn(Optional.of(member2))
        whenever(friendRelationRepository.findByMemberAndFriend(member1, member2)).thenReturn(null)
        whenever(friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member1, member2, FriendRequestStatus.PENDING))
            .thenReturn(listOf(pendingRequest))

        // Then
        assertThrows<IllegalArgumentException> {
            friendService.sendFriendRequest(loginMember(member1), member2.id!!)
        }
    }

    @Test
    fun `Cancel friend request test`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")
        val pendingRequest = FriendRequest(member1, member2)

        whenever(memberRepository.findById(member1.id!!)).thenReturn(Optional.of(member1))
        whenever(memberRepository.findById(member2.id!!)).thenReturn(Optional.of(member2))
        whenever(friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member1, member2, FriendRequestStatus.PENDING))
            .thenReturn(listOf(pendingRequest))

        // When
        friendService.cancelFriendRequest(loginMember(member1), member2.id!!)

        // Then
        verify(friendRequestRepository).delete(pendingRequest)
    }

    @Test
    fun `Can't cancel friend request if there is no pending request`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")

        whenever(memberRepository.findById(member1.id!!)).thenReturn(Optional.of(member1))
        whenever(memberRepository.findById(member2.id!!)).thenReturn(Optional.of(member2))
        whenever(friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member1, member2, FriendRequestStatus.PENDING))
            .thenReturn(emptyList())

        // Then
        assertThrows<IllegalArgumentException> {
            friendService.cancelFriendRequest(loginMember(member1), member2.id!!)
        }
        verify(friendRequestRepository, never()).delete(any<FriendRequest>())
    }

    @Test
    fun `Reject friend request test`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")
        val pendingRequest = FriendRequest(member1, member2)

        whenever(memberRepository.findById(member1.id!!)).thenReturn(Optional.of(member1))
        whenever(memberRepository.findById(member2.id!!)).thenReturn(Optional.of(member2))
        whenever(friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member1, member2, FriendRequestStatus.PENDING))
            .thenReturn(listOf(pendingRequest))

        // When
        friendService.rejectFriendRequest(loginMember(member2), member1.id!!)

        // Then
        assertThat(pendingRequest.status).isEqualTo(FriendRequestStatus.REJECTED)
    }

    @Test
    fun `Accept friend request test`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")
        val pendingRequest = FriendRequest(fromMember = member2, toMember = member1).apply {
            ReflectionTestUtils.setField(this, "id", 1L)
        }

        whenever(memberRepository.findById(member1.id!!)).thenReturn(Optional.of(member1))
        whenever(memberRepository.findById(member2.id!!)).thenReturn(Optional.of(member2))
        whenever(friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member2, member1, FriendRequestStatus.PENDING))
            .thenReturn(listOf(pendingRequest))
        whenever(friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member1, member2, FriendRequestStatus.PENDING))
            .thenReturn(emptyList())

        // When
        friendService.acceptFriendRequest(loginMember(member1), member2.id!!)

        // Then
        assertThat(pendingRequest.status).isEqualTo(FriendRequestStatus.ACCEPTED)
        verify(friendRelationRepository, times(2)).save(any<FriendRelation>())
        verify(eventPublisher).publishEvent(any<Any>())
    }

    @Test
    fun `Can't accept friend request if there is no pending request`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")

        whenever(memberRepository.findById(member1.id!!)).thenReturn(Optional.of(member1))
        whenever(memberRepository.findById(member2.id!!)).thenReturn(Optional.of(member2))
        whenever(friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member2, member1, FriendRequestStatus.PENDING))
            .thenReturn(emptyList())

        // Then
        assertThrows<IllegalArgumentException> {
            friendService.acceptFriendRequest(loginMember(member1), member2.id!!)
        }
        verify(friendRelationRepository, never()).save(any<FriendRelation>())
    }

    @Test
    fun `if there were vice versa request when accept friend request, delete it`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")
        val incomingRequest = FriendRequest(fromMember = member2, toMember = member1).apply {
            ReflectionTestUtils.setField(this, "id", 1L)
        }
        val outgoingRequest = FriendRequest(fromMember = member1, toMember = member2).apply {
            ReflectionTestUtils.setField(this, "id", 2L)
        }

        whenever(memberRepository.findById(member1.id!!)).thenReturn(Optional.of(member1))
        whenever(memberRepository.findById(member2.id!!)).thenReturn(Optional.of(member2))
        whenever(friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member2, member1, FriendRequestStatus.PENDING))
            .thenReturn(listOf(incomingRequest))
        whenever(friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member1, member2, FriendRequestStatus.PENDING))
            .thenReturn(listOf(outgoingRequest))

        // When
        friendService.acceptFriendRequest(loginMember(member1), member2.id!!)

        // Then
        verify(friendRequestRepository).delete(outgoingRequest)
    }

    @Test
    fun `findFriendRequests test - getPendingRequestsTo`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")
        val pendingRequest = FriendRequest(member2, member1)

        whenever(friendRequestRepository.findAllByToMemberAndStatus(member1, FriendRequestStatus.PENDING))
            .thenReturn(listOf(pendingRequest))

        // When
        val friendRequests = friendService.getPendingRequestsTo(member1)

        // Then
        assertThat(friendRequests).hasSize(1)
        assertThat(friendRequests[0].fromMember.id).isEqualTo(member2.id)
    }

    @Test
    fun `getPendingFriendRequest does not include accepted requests`() {
        // Given
        val member1 = createMember(1L, "member1")

        whenever(friendRequestRepository.findAllByToMemberAndStatus(member1, FriendRequestStatus.PENDING))
            .thenReturn(emptyList())

        // When
        val friendRequests = friendService.getPendingRequestsTo(member1)

        // Then
        assertThat(friendRequests).isEmpty()
    }

    /*************************************************
     * Friendship
     ***********************************************/

    @Test
    fun `Unfriend test`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")
        val friendRelation = FriendRelation(member1, member2)

        whenever(memberRepository.findById(member1.id!!)).thenReturn(Optional.of(member1))
        whenever(memberRepository.findById(member2.id!!)).thenReturn(Optional.of(member2))
        whenever(friendRelationRepository.findByMemberAndFriend(member1, member2)).thenReturn(friendRelation)

        // When
        friendService.unfriend(loginMember(member1), member2.id!!)

        // Then
        verify(friendRelationRepository).deleteByMemberAndFriend(member1, member2)
        verify(friendRelationRepository).deleteByMemberAndFriend(member2, member1)
    }

    @Test
    fun `Can't unfriend if not friend`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")

        whenever(memberRepository.findById(member1.id!!)).thenReturn(Optional.of(member1))
        whenever(memberRepository.findById(member2.id!!)).thenReturn(Optional.of(member2))
        whenever(friendRelationRepository.findByMemberAndFriend(member1, member2)).thenReturn(null)

        // Then
        assertThrows<IllegalArgumentException> {
            friendService.unfriend(loginMember(member1), member2.id!!)
        }
        verify(friendRelationRepository, never()).deleteByMemberAndFriend(any(), any())
    }

    @Test
    fun `isFriend test - returns true when friend relation exists`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")
        val friendRelation = FriendRelation(member1, member2)

        whenever(friendRelationRepository.findByMemberAndFriend(member1, member2)).thenReturn(friendRelation)

        // When
        val isFriend = friendService.isFriend(member1, member2)

        // Then
        assertThat(isFriend).isTrue()
    }

    @Test
    fun `isFriend test - returns false when no friend relation`() {
        // Given
        val member1 = createMember(1L, "member1")
        val member2 = createMember(2L, "member2")

        whenever(friendRelationRepository.findByMemberAndFriend(member1, member2)).thenReturn(null)

        // When
        val isFriend = friendService.isFriend(member1, member2)

        // Then
        assertThat(isFriend).isFalse()
    }

    private fun createMember(id: Long, name: String): Member {
        return Member(name = name).apply {
            ReflectionTestUtils.setField(this, "id", id)
        }
    }

    private fun loginMember(member: Member): LoginMember {
        return LoginMember(id = member.id!!, name = member.name)
    }

}
