package com.tistory.shanepark.dutypark.security.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.domain.entity.LoginSession
import org.springframework.data.jpa.repository.JpaRepository

interface LoginSessionRepository : JpaRepository<LoginSession, Long> {
    fun findByMember(member: Member): List<LoginSession>
}
