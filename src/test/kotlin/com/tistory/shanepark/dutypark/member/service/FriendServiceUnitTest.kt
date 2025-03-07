package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.whenever
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

    private lateinit var friendService: FriendService

    @BeforeEach
    fun setUp() {
        friendService = FriendService(
            friendRelationRepository = friendRelationRepository,
            friendRequestRepository = friendRequestRepository,
            memberRepository = memberRepository,
            memberService = memberService,
        )
    }

    @Test
    fun updateFriendsPin() {
        // Given
        val member = Member(name = "test")
        member.id = 0L

        val friendIds = listOf(1L, 2L, 3L)
        val dummyFriends = friendIds.map { id ->
            Member(name = "friend$id").let {
                it.id = id
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
            Assertions.assertThat(relation.pinOrder).isEqualTo(index + 1L)
        }
    }

    @Test
    fun `update friends pin does not update NullPinOrder`() {
        // Given
        val member = Member(name = "test")
        member.id = 0L

        val friendIds = listOf(1L, 2L, 3L)
        val dummyFriends = friendIds.map { id ->
            Member(name = "friend$id").let {
                it.id = id
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
                Assertions.assertThat(relation.pinOrder).isEqualTo(index + 1L)
            } else {
                Assertions.assertThat(relation.pinOrder).isNull()
            }
        }
    }


}
