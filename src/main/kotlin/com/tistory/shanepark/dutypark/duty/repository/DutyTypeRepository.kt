package com.tistory.shanepark.dutypark.duty.repository

import com.tistory.shanepark.dutypark.duty.domain.DutyType
import com.tistory.shanepark.dutypark.member.domain.Department
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface DutyTypeRepository : JpaRepository<DutyType, Long> {
    fun findAllByDepartmentOrderByIndexAsc(department: Department): List<DutyType>
}
