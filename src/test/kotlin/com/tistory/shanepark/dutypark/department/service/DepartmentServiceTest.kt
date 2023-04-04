package com.tistory.shanepark.dutypark.department.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.TestData
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentCreateDto
import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import jakarta.persistence.EntityManager
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

    @Autowired
    private lateinit var dutyTypeRepository: DutyTypeRepository

    @Autowired
    private lateinit var entityManager: EntityManager

    @Test
    fun findAllWithMemberCount() {
        val initial = respository.findAllWithMemberCount(Pageable.ofSize(10))
        assertThat(initial.content.map { d -> d.id }).containsExactly(TestData.department.id, TestData.department2.id)
    }

    @Test
    fun findById() {
        val findOne = service.findById(TestData.department.id!!)
        assertThat(findOne.id).isEqualTo(TestData.department.id)
        assertThat(findOne.name).isEqualTo(TestData.department.name)
    }

    @Test
    fun `create department`() {
        val totalBefore = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        val departmentCreateDto = DepartmentCreateDto("deptName", "deptDesc")
        val create = service.create(departmentCreateDto)
        assertThat(create.id).isNotNull
        assertThat(create.name).isEqualTo(departmentCreateDto.name)
        assertThat(create.description).isEqualTo(departmentCreateDto.description)
        val totalAfter = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore + 1)
    }

    @Test
    fun `delete Department success`() {
        // Given
        val totalBefore = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        val created = service.create(DepartmentCreateDto("deptName", "deptDesc"))
        val totalAfter = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore + 1)

        // When
        service.delete(created.id!!)

        // Then
        val totalAfterDelete = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        assertThat(totalAfterDelete).isEqualTo(totalBefore)
    }

    @Test
    fun `can not delete invalid department id`() {
        // Given
        val totalBefore = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements

        // When
        assertThrows<NoSuchElementException> {
            service.delete(9999)
        }

        // Then
        val totalAfter = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore)
    }

    @Test
    fun `can't delete department containing member`() {
        // Given
        val totalBefore = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        val created = service.create(DepartmentCreateDto("deptName", "deptDesc"))
        val totalAfter = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore + 1)
        val department = respository.findById(created.id!!).orElseThrow()

        TestData.member.changeDepartment(department)
        TestData.member2.changeDepartment(department)

        // When
        assertThrows<IllegalStateException> {
            service.delete(created.id!!)
        }
    }

    @Test
    fun `When delete department containing duty types, all associated dutyTypes will be removed as well`() {
        // Given
        val totalBefore = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        val created = service.create(DepartmentCreateDto("deptName", "deptDesc"))
        val totalAfter = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore + 1)
        val department = respository.findById(created.id!!).orElseThrow()

        val dutyType1 = department.addDutyType("오전")
        val dutyType2 = department.addDutyType("오후")
        val dutyType3 = department.addDutyType("야간")
        entityManager.flush()

        assertThat(dutyType1.id).isNotNull
        assertThat(dutyType2.id).isNotNull
        assertThat(dutyType3.id).isNotNull

        assertThat(department.dutyTypes).hasSize(3)

        // When
        service.delete(created.id!!)

        // Then
        assertThat(dutyTypeRepository.findById(dutyType1.id!!)).isEmpty
        assertThat(dutyTypeRepository.findById(dutyType2.id!!)).isEmpty
        assertThat(dutyTypeRepository.findById(dutyType3.id!!)).isEmpty
        assertThat(respository.findById(department.id!!)).isEmpty
    }

}
