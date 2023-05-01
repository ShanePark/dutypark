package com.tistory.shanepark.dutypark.department.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.service.DutyService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.data.domain.Pageable

class DepartmentServiceTest : DutyparkIntegrationTest() {

    @Autowired
    private lateinit var service: DepartmentService

    @Test
    fun findAllWithMemberCount() {
        val initial = departmentRepository.findAllWithMemberCount(Pageable.ofSize(10))
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
        val department = departmentRepository.findById(created.id!!).orElseThrow()

        department.addMember(TestData.member)
        department.addMember(TestData.member2)

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
        val department = departmentRepository.findById(created.id!!).orElseThrow()

        val dutyType1 = department.addDutyType("오전")
        val dutyType2 = department.addDutyType("오후")
        val dutyType3 = department.addDutyType("야간")
        em.flush()

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
        assertThat(departmentRepository.findById(department.id!!)).isEmpty
    }

    @Test
    fun `When Department is deleted, All related duties will have null dutyType`(
        @Autowired dutyService: DutyService,
        @Autowired dutyRepository: DutyRepository
    ) {
        // Given
        val created = service.create(DepartmentCreateDto("deptName", "deptDesc"))
        val department = departmentRepository.findById(created.id!!).orElseThrow()
        val member = TestData.member

        department.addMember(member)
        val dutyType1 = department.addDutyType("오전")
        em.flush()

        val dutyUpdateDto =
            DutyUpdateDto(year = 2023, month = 4, day = 8, dutyTypeId = dutyType1.id!!, memberId = member.id!!)
        dutyService.update(dutyUpdateDto)

        val duties = dutyService.getDutiesAsMap(member, 2023, 4)
        assertThat(duties.size).isEqualTo(1)
        val duty = duties[8]
        assertThat(duty).isNotNull

        // When
        department.removeMember(member)
        em.flush()

        service.delete(department.id!!)

        // Then
        em.flush()
        em.clear()

        assertThat(dutyTypeRepository.findById(dutyType1.id!!)).isEmpty
        assertThat(departmentRepository.findById(department.id!!)).isEmpty

        val theDuty = dutyRepository.findById(duty?.id!!).orElseThrow()
        assertThat(theDuty).isNotNull
        assertThat(theDuty.dutyType).isNull()
    }

    @Test
    fun `can't add same name DutyType on one Department`() {
        // Given
        val department = departmentRepository.findById(TestData.department.id!!).orElseThrow()
        val dutyType1 = department.addDutyType("test1")
        val dutyType2 = department.addDutyType("test2")
        val dutyType3 = department.addDutyType("test3")
        em.flush()

        assertThat(dutyType1.id).isNotNull
        assertThat(dutyType2.id).isNotNull
        assertThat(dutyType3.id).isNotNull

        assertThat(department.dutyTypes).containsAll(listOf(dutyType1, dutyType2, dutyType3))

        // When
        assertThrows<IllegalArgumentException> {
            department.addDutyType("test1")
        }
    }

    @Test
    fun `Delete member from Department Test`() {
        // Given
        val department = departmentRepository.findById(TestData.department.id!!).orElseThrow()
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val member2 = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        assertThat(department.members).hasSize(2)
        assertThat(member.department).isEqualTo(department)
        assertThat(member2.department).isEqualTo(department)

        // When
        service.removeMemberFromDepartment(department, member)
        service.removeMemberFromDepartment(department, member2)

        // Then
        assertThat(department.members).isEmpty()
        assertThat(member.department).isNull()
        assertThat(member2.department).isNull()
    }

    @Test
    fun `can't delete member from department if not member of department`() {
        // Given
        val department = departmentRepository.findById(TestData.department.id!!).orElseThrow()
        val department2 = departmentRepository.findById(TestData.department2.id!!).orElseThrow()
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val member2 = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        assertThat(department2.members).isEmpty()
        assertThat(member.department).isEqualTo(department)
        assertThat(member2.department).isEqualTo(department)

        // When
        assertThrows<IllegalStateException> {
            service.removeMemberFromDepartment(department2, member)
        }
    }

    @Test
    fun `add Member to Department Test`() {
        // Given
        val department = departmentRepository.findById(TestData.department.id!!).orElseThrow()
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val member2 = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        department.removeMember(member)
        department.removeMember(member2)
        assertThat(department.members).hasSize(0)
        assertThat(member.department).isEqualTo(null)
        assertThat(member2.department).isEqualTo(null)

        // When
        service.addMemberToDepartment(department, member)
        service.addMemberToDepartment(department, member2)

        em.flush()
        em.clear()

        // Then
        val department1 = departmentRepository.findById(department.id!!).orElseThrow()
        assertThat(department1.members).hasSize(2)
        assertThat(member.department?.id).isEqualTo(department1.id)
        assertThat(member2.department?.id).isEqualTo(department1.id)
    }

    @Test
    fun `can't add member to department if already member of department`() {
        // Given
        val department = departmentRepository.findById(TestData.department.id!!).orElseThrow()
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val member2 = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        assertThat(department.members).hasSize(2)
        assertThat(member.department).isEqualTo(department)
        assertThat(member2.department).isEqualTo(department)

        // When
        assertThrows(IllegalStateException::class.java) {
            service.addMemberToDepartment(department, member)
        }
        assertThrows(IllegalStateException::class.java) {
            service.addMemberToDepartment(department, member2)
        }

        // Then
        assertThat(department.members).hasSize(2)
        assertThat(member.department).isEqualTo(department)
        assertThat(member2.department).isEqualTo(department)
    }

    @Test
    fun `change department manager`() {
        // Given
        val department = departmentRepository.findById(TestData.department.id!!).orElseThrow()
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val member2 = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        assertThat(department.members).hasSize(2)
        assertThat(member.department).isEqualTo(department)
        assertThat(member2.department).isEqualTo(department)
        assertThat(department.manager).isNull()

        // Then
        service.changeManager(department, member)
        assertThat(department.manager).isEqualTo(member)

        service.changeManager(department, member2)
        assertThat(department.manager).isEqualTo(member2)

        service.changeManager(department, null)
        assertThat(department.manager).isNull()

    }

}
