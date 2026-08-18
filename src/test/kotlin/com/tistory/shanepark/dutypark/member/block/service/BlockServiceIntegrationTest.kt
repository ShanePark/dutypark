package com.tistory.shanepark.dutypark.member.block.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.member.block.repository.MemberBlockRepository
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus.PENDING
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestType
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired

class BlockServiceIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var blockService: BlockService

    @Autowired
    lateinit var memberBlockRepository: MemberBlockRepository

    @Autowired
    lateinit var friendRequestRepository: FriendRequestRepository

    @Test
    fun `block creates a block record`() {
        val blocker = TestData.member
        val blocked = TestData.member2

        blockService.block(blocker.id!!, blocked.id!!)
        flushAndClear()

        assertThat(memberBlockRepository.findAll()).hasSize(1)
        assertThat(blockService.isBlockedEitherWay(blocker.id!!, blocked.id!!)).isTrue()
    }

    @Test
    fun `block is idempotent`() {
        val blocker = TestData.member
        val blocked = TestData.member2

        blockService.block(blocker.id!!, blocked.id!!)
        flushAndClear()
        blockService.block(blocker.id!!, blocked.id!!)
        flushAndClear()

        assertThat(memberBlockRepository.findAll()).hasSize(1)
    }

    @Test
    fun `block self throws block-self`() {
        val member = TestData.member

        val exception = assertThrows<BadRequestException> {
            blockService.block(member.id!!, member.id!!)
        }

        assertThat(exception.message).isEqualTo("block.self")
    }

    @Test
    fun `block unknown member throws`() {
        assertThrows<NoSuchElementException> {
            blockService.block(TestData.member.id!!, -1L)
        }
    }

    @Test
    fun `block removes friend relation on both sides`() {
        val blocker = TestData.member
        val blocked = TestData.member2
        makeThemFriend(blocker, blocked)
        flushAndClear()

        blockService.block(blocker.id!!, blocked.id!!)
        flushAndClear()

        assertThat(friendRelationRepository.findByMemberAndFriend(reload(blocker), reload(blocked))).isNull()
        assertThat(friendRelationRepository.findByMemberAndFriend(reload(blocked), reload(blocker))).isNull()
    }

    @Test
    fun `block removes family relation on both sides`() {
        val blocker = TestData.member
        val blocked = TestData.member2
        makeThemFriend(blocker, blocked)
        friendRelationRepository.findByMemberAndFriend(blocker, blocked)!!.isFamily = true
        friendRelationRepository.findByMemberAndFriend(blocked, blocker)!!.isFamily = true
        flushAndClear()

        blockService.block(blocker.id!!, blocked.id!!)
        flushAndClear()

        assertThat(friendRelationRepository.findAll()).isEmpty()
    }

    @Test
    fun `block does not throw when they are not friends`() {
        blockService.block(TestData.member.id!!, TestData.member2.id!!)
        flushAndClear()

        assertThat(memberBlockRepository.findAll()).hasSize(1)
    }

    @Test
    fun `block deletes pending friend requests in both directions`() {
        val blocker = TestData.member
        val blocked = TestData.member2
        friendRequestRepository.save(FriendRequest(fromMember = blocker, toMember = blocked))
        friendRequestRepository.save(FriendRequest(fromMember = blocked, toMember = blocker))
        flushAndClear()

        blockService.block(blocker.id!!, blocked.id!!)
        flushAndClear()

        assertThat(friendRequestRepository.findAll()).isEmpty()
    }

    @Test
    fun `block deletes pending family requests too`() {
        val blocker = TestData.member
        val blocked = TestData.member2
        friendRequestRepository.save(
            FriendRequest(
                fromMember = blocked,
                toMember = blocker,
                requestType = FriendRequestType.FAMILY_REQUEST
            )
        )
        flushAndClear()

        blockService.block(blocker.id!!, blocked.id!!)
        flushAndClear()

        assertThat(friendRequestRepository.findAll()).isEmpty()
    }

    @Test
    fun `block keeps non pending friend requests`() {
        val blocker = TestData.member
        val blocked = TestData.member2
        val request = friendRequestRepository.save(FriendRequest(fromMember = blocker, toMember = blocked))
        request.accepted()
        flushAndClear()

        blockService.block(blocker.id!!, blocked.id!!)
        flushAndClear()

        assertThat(friendRequestRepository.findAll()).hasSize(1)
        assertThat(friendRequestRepository.findAll()[0].status).isNotEqualTo(PENDING)
    }

    @Test
    fun `isBlockedEitherWay is true for the blocked member as well`() {
        val blocker = TestData.member
        val blocked = TestData.member2

        blockService.block(blocker.id!!, blocked.id!!)
        flushAndClear()

        assertThat(blockService.isBlockedEitherWay(blocked.id!!, blocker.id!!)).isTrue()
    }

    @Test
    fun `isBlockedEitherWay is false when there is no block`() {
        assertThat(blockService.isBlockedEitherWay(TestData.member.id!!, TestData.member2.id!!)).isFalse()
    }

    @Test
    fun `isBlockedEitherWay does not leak other members blocks`() {
        val other = memberRepository.save(Member("other", "other@duty.park", "pass"))
        blockService.block(TestData.member.id!!, other.id!!)
        flushAndClear()

        assertThat(blockService.isBlockedEitherWay(TestData.member.id!!, TestData.member2.id!!)).isFalse()
    }

    @Test
    fun `unblock removes the block`() {
        val blocker = TestData.member
        val blocked = TestData.member2
        blockService.block(blocker.id!!, blocked.id!!)
        flushAndClear()

        blockService.unblock(blocker.id!!, blocked.id!!)
        flushAndClear()

        assertThat(memberBlockRepository.findAll()).isEmpty()
        assertThat(blockService.isBlockedEitherWay(blocker.id!!, blocked.id!!)).isFalse()
    }

    @Test
    fun `unblock is idempotent`() {
        blockService.unblock(TestData.member.id!!, TestData.member2.id!!)
        flushAndClear()

        assertThat(memberBlockRepository.findAll()).isEmpty()
    }

    @Test
    fun `unblock only removes my own block`() {
        val blocker = TestData.member
        val blocked = TestData.member2
        blockService.block(blocker.id!!, blocked.id!!)
        flushAndClear()

        blockService.unblock(blocked.id!!, blocker.id!!)
        flushAndClear()

        assertThat(memberBlockRepository.findAll()).hasSize(1)
        assertThat(blockService.isBlockedEitherWay(blocker.id!!, blocked.id!!)).isTrue()
    }

    @Test
    fun `findBlockedMembers returns blocked member previews`() {
        val blocker = TestData.member
        val blocked = reload(TestData.member2)
        blocked.profilePhotoPath = "photo.jpg"
        blocked.profilePhotoVersion = 7
        memberRepository.save(blocked)
        blockService.block(blocker.id!!, blocked.id!!)
        flushAndClear()

        val result = blockService.findBlockedMembers(blocker.id!!)

        assertThat(result).hasSize(1)
        assertThat(result[0].id).isEqualTo(blocked.id)
        assertThat(result[0].name).isEqualTo(blocked.name)
        assertThat(result[0].hasProfilePhoto).isTrue()
        assertThat(result[0].profilePhotoVersion).isEqualTo(7)
        assertThat(result[0].blockedAt).isNotNull()
    }

    @Test
    fun `findBlockedMembers does not include members who blocked me`() {
        blockService.block(TestData.member2.id!!, TestData.member.id!!)
        flushAndClear()

        assertThat(blockService.findBlockedMembers(TestData.member.id!!)).isEmpty()
    }

    @Test
    fun `deleting a member cascades to its block rows`() {
        val blocker = memberRepository.save(Member("blocker", "blocker@duty.park", "pass"))
        val blocked = memberRepository.save(Member("blocked", "blocked@duty.park", "pass"))
        blockService.block(blocker.id!!, blocked.id!!)
        flushAndClear()

        em.createNativeQuery("delete from member where id = :id")
            .setParameter("id", blocked.id!!)
            .executeUpdate()
        flushAndClear()

        assertThat(memberBlockRepository.findAll()).isEmpty()
    }

    private fun reload(member: Member): Member = memberRepository.findById(member.id!!).orElseThrow()

    private fun flushAndClear() {
        em.flush()
        em.clear()
    }

}
