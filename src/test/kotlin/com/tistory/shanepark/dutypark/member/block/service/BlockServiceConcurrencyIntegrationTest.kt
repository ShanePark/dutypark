package com.tistory.shanepark.dutypark.member.block.service

import com.tistory.shanepark.dutypark.member.block.repository.MemberBlockRepository
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.RepeatedTest
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.transaction.support.TransactionTemplate
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@SpringBootTest
class BlockServiceConcurrencyIntegrationTest {

    @Autowired lateinit var blockService: BlockService
    @Autowired lateinit var memberBlockRepository: MemberBlockRepository
    @Autowired lateinit var memberRepository: MemberRepository
    @Autowired lateinit var friendRelationRepository: FriendRelationRepository
    @Autowired lateinit var transactionTemplate: TransactionTemplate

    @RepeatedTest(5)
    fun `concurrent duplicate blocks both succeed and complete side effects`() {
        val suffix = System.nanoTime().toString().takeLast(12)
        val (blockerId, blockedId) = transactionTemplate.execute {
            val blocker = memberRepository.saveAndFlush(Member("blocker", "blocker-$suffix@duty.park", "pass"))
            val blocked = memberRepository.saveAndFlush(Member("blocked", "blocked-$suffix@duty.park", "pass"))
            friendRelationRepository.saveAllAndFlush(
                listOf(
                    FriendRelation(blocker, blocked),
                    FriendRelation(blocked, blocker),
                )
            )
            requireNotNull(blocker.id) to requireNotNull(blocked.id)
        }!!

        try {
            val start = CountDownLatch(1)
            val executor = Executors.newFixedThreadPool(2)
            val futures = List(2) {
                executor.submit {
                    start.await()
                    blockService.block(blockerId, blockedId)
                }
            }

            try {
                start.countDown()
                futures.forEach { it.get(10, TimeUnit.SECONDS) }
            } finally {
                futures.filterNot { it.isDone }.forEach { it.cancel(true) }
                executor.shutdownNow()
                executor.awaitTermination(5, TimeUnit.SECONDS)
            }

            assertThat(
                memberBlockRepository.findAll().filter {
                    it.blocker.id == blockerId && it.blocked.id == blockedId
                }
            ).hasSize(1)
            assertThat(friendRelationRepository.findAll().filter {
                (it.member.id == blockerId && it.friend.id == blockedId) ||
                    (it.member.id == blockedId && it.friend.id == blockerId)
            }).isEmpty()
        } finally {
            transactionTemplate.execute {
                memberBlockRepository.deleteByBlockerIdAndBlockedId(blockerId, blockedId)
                friendRelationRepository.deleteAll(friendRelationRepository.findAll().filter {
                    it.member.id in listOf(blockerId, blockedId) || it.friend.id in listOf(blockerId, blockedId)
                })
                memberRepository.deleteAllById(listOf(blockerId, blockedId))
                memberRepository.flush()
            }
        }
    }
}
