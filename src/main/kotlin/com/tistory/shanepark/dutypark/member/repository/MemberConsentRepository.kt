package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.MemberConsent
import org.springframework.data.jpa.repository.JpaRepository

interface MemberConsentRepository : JpaRepository<MemberConsent, Long>
