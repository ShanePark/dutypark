package com.tistory.shanepark.dutypark.push.apns.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.Index
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import org.hibernate.annotations.OnDelete
import org.hibernate.annotations.OnDeleteAction

@Entity
@Table(
    name = "apns_installation",
    indexes = [Index(name = "idx_apns_installation_refresh_token", columnList = "refresh_token_id")],
)
class ApnsInstallation(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "refresh_token_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    var refreshToken: RefreshToken,

    @Column(name = "device_token", nullable = false, unique = true, length = 512)
    val deviceToken: String,

    @Column(name = "sandbox", nullable = false)
    var sandbox: Boolean = false,
) : EntityBase()
