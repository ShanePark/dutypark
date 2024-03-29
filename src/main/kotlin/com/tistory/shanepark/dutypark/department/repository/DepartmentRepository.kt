package com.tistory.shanepark.dutypark.department.repository

import com.tistory.shanepark.dutypark.department.domain.dto.SimpleDepartmentDto
import com.tistory.shanepark.dutypark.department.domain.entity.Department
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.util.*

interface DepartmentRepository : JpaRepository<Department, Long> {

    override fun findById(id: Long): Optional<Department>

    @Query("select new com.tistory.shanepark.dutypark.department.domain.dto.SimpleDepartmentDto(d.id, d.name, d.description, count(m)) from Department d left join d.members m group by d")
    fun findAllWithMemberCount(pageable: Pageable): Page<SimpleDepartmentDto>

    fun findByName(name: String): Department?

    @Query("select d from Department d left join fetch d.dutyTypes where d.id = :departmentId")
    fun findByIdWithDutyTypes(departmentId: Long): Optional<Department>

    @Query("select d from Department d left join fetch d.members where d.id = :departmentId")
    fun findByIdWithMembers(departmentId: Long): Optional<Department>

}
