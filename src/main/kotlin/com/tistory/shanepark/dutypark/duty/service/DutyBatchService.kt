package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.batch.SungsimCakeParser
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.multipart.MultipartFile
import java.time.YearMonth

@Service
@Transactional
class DutyBatchService(
    private val sungsimCakeParser: SungsimCakeParser,
    private val memberRepository: MemberRepository,
    private val dutyRepository: DutyRepository,
    private val dutyTypeRepository: DutyTypeRepository
) {

    /**
     * TODO: Check authority before calling this method
     */
    fun sungsimDutyBatch(file: MultipartFile, memberId: Long, yearMonth: YearMonth) {
        if (file.originalFilename?.lowercase()?.endsWith(".xlsx") != true)
            throw IllegalArgumentException("Only xlsx file is supported")

        file.inputStream.use { input ->
            val batchResult = sungsimCakeParser.parseDayOff(yearMonth, input)
            val member = memberRepository.findById(memberId)
                .orElseThrow { IllegalArgumentException("Member not found: id=$memberId") }
            val department = member.department
                ?: throw IllegalArgumentException("Member has no department: id=$memberId")

            val validName = batchResult.getNames()
                .filter { member.name == it || member.name.endsWith(it) }
                .toList()
            if (validName.isEmpty() || validName.size > 1)
                throw IllegalArgumentException("Member name not found or multiple names found: name=${member.name}, validNames=$validName")
            val nameOnXlsx = validName.first()

            val dutyType = dutyTypeRepository.findAllByDepartment(department)
                .singleOrNull()
                ?: throw IllegalArgumentException("Department has no duty type or multiple duty types: $department")

            dutyRepository.deleteDutiesByMemberAndDutyDateBetween(member, batchResult.startDate, batchResult.endDate)
            val duties = batchResult.getWorkDays(nameOnXlsx).map {
                Duty(dutyDate = it, dutyType = dutyType, member = member)
            }
            dutyRepository.saveAll(duties)
        }
    }

}
