package com.tistory.shanepark.dutypark.department.repository

import com.tistory.shanepark.dutypark.department.domain.entity.Department
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository
import java.util.*

interface DepartmentRepository : JpaRepository<Department, Long> {

    @EntityGraph(attributePaths = ["dutyTypes", "members"])
    override fun findById(id: Long): Optional<Department>

    fun findByName(name: String): Department?

}
