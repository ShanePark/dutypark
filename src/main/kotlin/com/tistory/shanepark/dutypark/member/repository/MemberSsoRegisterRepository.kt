package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import org.springframework.data.jpa.repository.JpaRepository
import java.util.*

interface MemberSsoRegisterRepository : JpaRepository<MemberSsoRegister, Long> {

    fun findByUuid(uuid: String): Optional<MemberSsoRegister>
}
