package com.tistory.shanepark.dutypark.push.apns.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.Index
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table

@Entity
@Table(
    name = "apns_installation",
    indexes = [Index(name = "idx_apns_installation_member", columnList = "member_id")],
)
class ApnsInstallation(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    var member: Member,

    @Column(name = "device_token", nullable = false, unique = true, length = 512)
    val deviceToken: String,

    @Column(name = "sandbox", nullable = false)
    var sandbox: Boolean = false,
) : EntityBase()
