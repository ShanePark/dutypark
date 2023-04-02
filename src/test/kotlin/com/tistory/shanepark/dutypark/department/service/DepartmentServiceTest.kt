package com.tistory.shanepark.dutypark.department.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.TestData
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.data.domain.Pageable

class DepartmentServiceTest : DutyparkIntegrationTest() {

    @Autowired
    private lateinit var departmentService: DepartmentService

    @Test
    fun findAll() {
        val initial = departmentService.findAll(Pageable.ofSize(10))
        val dept1 = DepartmentDto.of(TestData.department)
        val dept2 = DepartmentDto.of(TestData.department2)
        assertThat(initial.content).containsExactly(dept1, dept2)
    }

    @Test
    fun findById() {
        val findOne = departmentService.findById(TestData.department.id!!)
        assertThat(findOne.id).isEqualTo(TestData.department.id)
        assertThat(findOne.name).isEqualTo(TestData.department.name)
    }

}
