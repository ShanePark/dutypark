package com.tistory.shanepark.dutypark.member.domain.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.enums.ManagerRole
import jakarta.persistence.*

@Entity
@Table(name = "member_manager")
class MemberManager(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "manager_id", nullable = false)
    @field:JsonIgnore
    val manager: Member,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "managed_id", nullable = false)
    @field:JsonIgnore
    val managed: Member,

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false)
    val role: ManagerRole
) : EntityBase()
