package com.tistory.shanepark.dutypark.member.block.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.AuditActor
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
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
    private val log = logger()

    fun block(loginMemberId: Long, targetMemberId: Long, actor: AuditActor? = null) {
        if (loginMemberId == targetMemberId)
            throw BadRequestException("block.self")

        // A stable pair order prevents reciprocal blocks from acquiring the member rows in opposite orders.
        val lockedMembers = listOf(loginMemberId, targetMemberId)
            .sorted()
            .associateWith { memberRepository.findMemberWithTeamForUpdate(it).orElseThrow() }
        val blocker = lockedMembers.getValue(loginMemberId)
        val blocked = lockedMembers.getValue(targetMemberId)

        val created = !memberBlockRepository.existsByBlockerIdAndBlockedId(loginMemberId, targetMemberId)
        if (created) {
            memberBlockRepository.save(MemberBlock(blocker = blocker, blocked = blocked))
        }

        unfriendBothWays(blocker, blocked)
        val pendingCount = deletePendingRequestsBothWays(blocker, blocked)
        val (scheduleTagCount, todoTagCount) = deleteTagsBothWays(loginMemberId, targetMemberId)
        if (created || pendingCount > 0 || scheduleTagCount > 0 || todoTagCount > 0) {
            log.auditEventAfterCommit(if (created) "member.blocked" else "member.block_cleanup", actor ?: blocker.toAuditActor(),
                target = mapOf("blockerMemberId" to loginMemberId, "blockedMemberId" to targetMemberId),
                details = mapOf("pendingRequestCount" to pendingCount, "scheduleTagCount" to scheduleTagCount, "todoTagCount" to todoTagCount))
        }
    }

    fun unblock(loginMemberId: Long, targetMemberId: Long, actor: AuditActor? = null) {
        val deletedCount = memberBlockRepository.deleteByBlockerIdAndBlockedId(loginMemberId, targetMemberId)
        if (deletedCount > 0) {
            log.auditEventAfterCommit("member.unblocked", actor ?: AuditActor(loginMemberId, ""),
                target = mapOf("blockerMemberId" to loginMemberId, "blockedMemberId" to targetMemberId),
                details = mapOf("deletedCount" to deletedCount))
        }
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
    private fun deleteTagsBothWays(memberId1: Long, memberId2: Long): Pair<Int, Int> {
        val scheduleCount = scheduleRepository.deleteTagsBetweenMembers(memberId1, memberId2)
        val todoCount = todoRepository.deleteTagsBetweenMembers(memberId1, memberId2)
        return scheduleCount to todoCount
    }

    private fun deletePendingRequestsBothWays(member1: Member, member2: Member): Int {
        val pending = friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member1, member2, PENDING) +
            friendRequestRepository.findAllByFromMemberAndToMemberAndStatus(member2, member1, PENDING)
        friendRequestRepository.deleteAll(pending)
        return pending.size
    }

}
