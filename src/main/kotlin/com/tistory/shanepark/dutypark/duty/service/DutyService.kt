package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.MemoDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.service.MemberService
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional(readOnly = true)
class DutyService(
    val dutyRepository: DutyRepository,
    val dutyTypeRepository: DutyTypeRepository,
    val memberService: MemberService
) {
    fun findDutyByMemberAndYearAndMonth(member: Member, year: Int, month: Int): Map<Int, DutyDto?> {
        return dutyRepository.findAllByMemberAndDutyYearAndDutyMonth(member, year, month)
            .associate { it.dutyDay to DutyDto(it) }
    }

    @Transactional
    fun update(dutyUpdateDto: DutyUpdateDto) {
        val member = memberService.findById(dutyUpdateDto.memberId)

        val duty: Duty? = dutyRepository.findByMemberAndDutyYearAndDutyMonthAndDutyDay(
            member = member,
            year = dutyUpdateDto.year,
            month = dutyUpdateDto.month,
            day = dutyUpdateDto.day
        )

        val dutyType: DutyType? = dutyUpdateDto.dutyTypeId?.let {
            dutyTypeRepository.findById(it).orElseThrow()
        }

        if (duty != null && dutyType == null) {
            dutyRepository.delete(duty)
        } else if (duty == null && dutyType != null) {
            save(
                Duty(
                    member = member,
                    dutyYear = dutyUpdateDto.year,
                    dutyMonth = dutyUpdateDto.month,
                    dutyDay = dutyUpdateDto.day,
                    dutyType = dutyType
                )
            )
        } else if (duty != null && dutyType != null) {
            duty.dutyType = dutyType
        }
    }

    @Transactional
    fun save(duty: Duty) {
        dutyRepository.save(duty)
    }

    @Transactional
    fun updateMemo(memoDto: MemoDto) {
        val member = memberService.findById(memoDto.memberId)

        val duty: Duty? = dutyRepository.findByMemberAndDutyYearAndDutyMonthAndDutyDay(
            member = member,
            year = memoDto.year,
            month = memoDto.month,
            day = memoDto.day
        )

        if (duty != null) {
            duty.memo = memoDto.memo
        } else {
            save(
                Duty(
                    member = member,
                    dutyYear = memoDto.year,
                    dutyMonth = memoDto.month,
                    dutyDay = memoDto.day,
                    memo = memoDto.memo,
                    dutyType = null
                )
            )
        }

    }
}
