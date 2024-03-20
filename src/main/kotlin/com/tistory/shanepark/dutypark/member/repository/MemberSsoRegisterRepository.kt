package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import org.springframework.data.jpa.repository.JpaRepository

interface MemberSsoRegisterRepository : JpaRepository<MemberSsoRegister, Long> {

    fun findByUuid(uuid: String): MemberSsoRegister?
}
