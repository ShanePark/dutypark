package com.tistory.shanepark.dutypark.duty.repository

import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import org.springframework.data.jpa.repository.JpaRepository

interface DutyTypeRepository : JpaRepository<DutyType, Long> {

    fun findAllByDepartment(department: Department): List<DutyType>
}
