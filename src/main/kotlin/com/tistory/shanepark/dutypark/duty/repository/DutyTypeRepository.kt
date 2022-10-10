package com.tistory.shanepark.dutypark.duty.repository

import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.member.domain.entity.Department
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface DutyTypeRepository : JpaRepository<DutyType, Long> {
    fun findAllByDepartmentOrderByPositionAsc(department: Department): List<DutyType>
}
