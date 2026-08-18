package com.tistory.shanepark.dutypark.member.block.domain.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.Index
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import jakarta.persistence.UniqueConstraint
import org.hibernate.annotations.OnDelete
import org.hibernate.annotations.OnDeleteAction

@Entity
@Table(
    name = "member_block",
    uniqueConstraints = [UniqueConstraint(name = "uk_member_block_pair", columnNames = ["blocker_id", "blocked_id"])],
    indexes = [Index(name = "idx_member_block_blocked", columnList = "blocked_id")],
)
class MemberBlock(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "blocker_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    @field:JsonIgnore
    val blocker: Member,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "blocked_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    @field:JsonIgnore
    val blocked: Member,
) : EntityBase()
