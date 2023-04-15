package com.tistory.shanepark.dutypark.duty.repository

import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import org.springframework.data.jpa.repository.JpaRepository

interface DutyTypeRepository : JpaRepository<DutyType, Long> {
}
