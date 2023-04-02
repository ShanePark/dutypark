package com.tistory.shanepark.dutypark.department.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.data.domain.Pageable

class DepartmentServiceTest : DutyparkIntegrationTest() {

    @Autowired
    private lateinit var departmentService: DepartmentService

    @Test
    fun findAll() {
        departmentService.findAll(Pageable.ofSize(10))

    }

    @Test
    fun findById() {
        departmentService.findById(1L)
    }

}
