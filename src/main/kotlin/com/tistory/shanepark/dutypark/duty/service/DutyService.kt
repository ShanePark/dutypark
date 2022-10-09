package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.Department
import com.tistory.shanepark.dutypark.member.domain.Member
import com.tistory.shanepark.dutypark.member.dto.DutyDto
import org.springframework.stereotype.Service

@Service
class DutyService(
    val dutyRepository: DutyRepository,
    val dutyTypeRepository: DutyTypeRepository
) {
    fun findDutyByMemberAndYearAndMonth(member: Member, year: Int, month: Int): Map<Int, DutyDto?> {
        return dutyRepository.findAllByMemberAndDutyYearAndDutyMonth(member, year, month)
            .associate { it.dutyDay to DutyDto(it) }
    }

    fun findAllDutyTypes(department: Department): Any {
        return dutyTypeRepository.findAllByDepartmentOrderByIndexAsc(department)
    }
}
