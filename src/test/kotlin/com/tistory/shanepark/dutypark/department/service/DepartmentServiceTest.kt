package com.tistory.shanepark.dutypark.department.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.TestData
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentCreateDto
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.data.domain.Pageable

class DepartmentServiceTest : DutyparkIntegrationTest() {

    @Autowired
    private lateinit var service: DepartmentService

    @Autowired
    private lateinit var respository: DepartmentRepository

    @Test
    fun findAll() {
        val initial = service.findAll(Pageable.ofSize(10))
        val dept1 = DepartmentDto.of(TestData.department)
        val dept2 = DepartmentDto.of(TestData.department2)
        assertThat(initial.content).containsExactly(dept1, dept2)
    }

    @Test
    fun findById() {
        val findOne = service.findById(TestData.department.id!!)
        assertThat(findOne.id).isEqualTo(TestData.department.id)
        assertThat(findOne.name).isEqualTo(TestData.department.name)
    }

    @Test
    fun `create department`() {
        val totalBefore = service.findAll(Pageable.ofSize(10)).totalElements
        val departmentCreateDto = DepartmentCreateDto("deptName", "deptDesc")
        val create = service.create(departmentCreateDto)
        assertThat(create.id).isNotNull
        assertThat(create.name).isEqualTo(departmentCreateDto.name)
        assertThat(create.description).isEqualTo(departmentCreateDto.description)
        val totalAfter = service.findAll(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore + 1)
    }

    @Test
    fun `delete Department success`() {
        // Given
        val totalBefore = service.findAll(Pageable.ofSize(10)).totalElements
        val created = service.create(DepartmentCreateDto("deptName", "deptDesc"))
        val totalAfter = service.findAll(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore + 1)

        // When
        service.delete(created.id!!)

        // Then
        val totalAfterDelete = service.findAll(Pageable.ofSize(10)).totalElements
        assertThat(totalAfterDelete).isEqualTo(totalBefore)
    }

    @Test
    fun `can not invalid department id`() {
        // Given
        val totalBefore = service.findAll(Pageable.ofSize(10)).totalElements

        // When
        assertThrows<NoSuchElementException> {
            service.delete(9999)
        }

        // Then
        val totalAfter = service.findAll(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore)
    }

    @Test
    fun `can't delete department containing member`() {
        // Given
        val totalBefore = service.findAll(Pageable.ofSize(10)).totalElements
        val created = service.create(DepartmentCreateDto("deptName", "deptDesc"))
        val totalAfter = service.findAll(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore + 1)

        // When
        val department = respository.findById(created.id!!).orElseThrow()
        department.addMember(TestData.member)

    }

}
