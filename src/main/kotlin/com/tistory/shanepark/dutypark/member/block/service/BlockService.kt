package com.tistory.shanepark.dutypark.member.block.service

import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.member.block.domain.dto.BlockedMemberDto
import com.tistory.shanepark.dutypark.member.block.domain.dto.toBlockedMemberDto
import com.tistory.shanepark.dutypark.member.block.domain.entity.MemberBlock
import com.tistory.shanepark.dutypark.member.block.repository.MemberBlockRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus.PENDING
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class BlockService(
    private val memberBlockRepository: MemberBlockRepository,
    private val memberRepository: MemberRepository,
    private val friendRelationRepository: FriendRelationRepository,
    private val friendRequestRepository: FriendRequestRepository,
    private val scheduleRepository: ScheduleRepository,
    private val todoRepository: TodoRepository,
) {

    fun block(loginMemberId: Long, targetMemberId: Long) {
        if (loginMemberId == targetMemberId)
            throw BadRequestException("block.self")

        val blocker = memberRepository.findById(loginMemberId).orElseThrow()
        val blocked = memberRepository.findById(targetMemberId).orElseThrow()

        if (!memberBlockRepository.existsByBlockerIdAndBlockedId(loginMemberId, targetMemberId)) {
            memberBlockRepository.save(MemberBlock(blocker = blocker, blocked = blocked))
        }

        unfriendBothWays(blocker, blocked)
        deletePendingRequestsBothWays(blocker, blocked)
        deleteTagsBothWays(loginMemberId, targetMemberId)
    }

    fun unblock(loginMemberId: Long, targetMemberId: Long) {
        memberBlockRepository.deleteByBlockerIdAndBlockedId(loginMemberId, targetMemberId)
    }

    @Transactional(readOnly = true)
    fun findBlockedMembers(loginMemberId: Long): List<BlockedMemberDto> {
        return memberBlockRepository.findAllByBlockerIdOrderByCreatedDateDesc(loginMemberId)
            .map { it.toBlockedMemberDto() }
    }

    @Transactional(readOnly = true)
    fun isBlockedEitherWay(memberId1: Long, memberId2: Long): Boolean {
        return memberBlockRepository.existsBetween(memberId1, memberId2)
    }

    private fun unfriendBothWays(member1: Member, member2: Member) {
        friendRelationRepository.deleteByMemberAndFriend(member1, member2)
        friendRelationRepository.deleteByMemberAndFriend(member2, member1)
    }

    /**
     * A tag that predates the block would otherwise survive it, keeping the other member's
     * schedule on the calendar and letting them change the owner's todo status. Runs last
     * because the bulk deletes clear the persistence context.
     */
    private fun deleteTagsBothWays(memberId1: Long, memberId2: Long) {
        scheduleRepository.deleteTagsBetweenMembers(memberId1, memberId2)
        todoRepository.deleteTagsBetweenMembers(memberId1, memberId2)
    }

    private fun deletePendingRequestsBothWays(member1: Member, member2: Member) {
        val pending = friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member1, member2, PENDING) +
            friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member2, member1, PENDING)
        friendRequestRepository.deleteAll(pending)
    }

}
