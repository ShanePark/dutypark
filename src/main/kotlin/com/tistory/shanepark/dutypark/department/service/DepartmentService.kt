package com.tistory.shanepark.dutypark.department.service

import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentCreateDto
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.department.domain.dto.SimpleDepartmentDto
import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class DepartmentService(
    private val repository: DepartmentRepository,
    private val memberRepository: MemberRepository,
) {

    @Transactional(readOnly = true)
    fun findAllWithMemberCount(pageable: Pageable): Page<SimpleDepartmentDto> {
        return repository.findAllWithMemberCount(pageable)
    }

    @Transactional(readOnly = true)
    fun findById(id: Long): DepartmentDto {
        val findById = repository.findById(id).orElseThrow()
        return DepartmentDto.of(findById)
    }

    fun create(departmentCreateDto: DepartmentCreateDto): DepartmentDto {
        Department(departmentCreateDto.name).let {
            it.description = departmentCreateDto.description
            repository.save(it)
            return DepartmentDto.of(it)
        }
    }

    fun delete(id: Long) {
        val department = repository.findById(id).orElseThrow()
        if (department.members.isNotEmpty()) {
            throw IllegalStateException("Department has members")
        }
        repository.deleteById(id)
    }

    fun isDuplicated(name: String): Boolean {
        repository.findByName(name).let {
            return it != null
        }
    }

    fun addMemberToDepartment(department: Department, member: Member) {
        if (member.department != null) {
            throw IllegalStateException("Member already has department")
        }
        department.addMember(member)
    }

    fun removeMemberFromDepartment(department: Department, member: Member) {
        if (member.department != department) {
            throw IllegalStateException("Member does not belong to department")
        }
        department.removeMember(member)
    }

}