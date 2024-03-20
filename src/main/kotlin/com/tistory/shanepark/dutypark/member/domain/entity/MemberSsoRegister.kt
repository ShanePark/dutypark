package com.tistory.shanepark.dutypark.member.domain.entity

import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import jakarta.persistence.*
import java.time.LocalDateTime
import java.util.*

@Entity
@Table(name = "member_sso_register")
class MemberSsoRegister(
    @Enumerated(EnumType.STRING)
    @Column(name = "sso_type")
    val ssoType: SsoType,

    @Column(name = "sso_id")
    val ssoId: String,
) {

    @Id
    @Column(name = "id")
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

    @Column(name = "uuid", unique = true)
    val uuid: String = UUID.randomUUID().toString()


    @Column(name = "created_date")
    val createdDate: LocalDateTime = LocalDateTime.now()

}
