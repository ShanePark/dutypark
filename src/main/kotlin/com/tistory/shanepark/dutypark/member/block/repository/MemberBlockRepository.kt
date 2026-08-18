package com.tistory.shanepark.dutypark.member.block.repository

import com.tistory.shanepark.dutypark.member.block.domain.entity.MemberBlock
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.util.*

interface MemberBlockRepository : JpaRepository<MemberBlock, UUID> {

    fun existsByBlockerIdAndBlockedId(blockerId: Long, blockedId: Long): Boolean

    fun deleteByBlockerIdAndBlockedId(blockerId: Long, blockedId: Long)

    @EntityGraph(attributePaths = ["blocked"])
    fun findAllByBlockerIdOrderByCreatedDateDesc(blockerId: Long): List<MemberBlock>

    @Query(
        """
        SELECT COUNT(b) > 0 FROM MemberBlock b
        WHERE (b.blocker.id = :memberId1 AND b.blocked.id = :memberId2)
           OR (b.blocker.id = :memberId2 AND b.blocked.id = :memberId1)
        """
    )
    fun existsBetween(memberId1: Long, memberId2: Long): Boolean

}
