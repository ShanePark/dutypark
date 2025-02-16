package com.tistory.shanepark.dutypark.duty.batch.service

import com.tistory.shanepark.dutypark.duty.batch.SungsimCakeParser
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchResult
import com.tistory.shanepark.dutypark.duty.batch.exceptions.DutyTypeNotSingleException
import com.tistory.shanepark.dutypark.duty.batch.exceptions.MultipleNameFoundException
import com.tistory.shanepark.dutypark.duty.batch.exceptions.NameNotFoundException
import com.tistory.shanepark.dutypark.duty.batch.exceptions.NotSupportedFileException
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
class DutyBatchSungsimService(
    private val sungsimCakeParser: SungsimCakeParser,
    private val memberRepository: MemberRepository,
    private val dutyRepository: DutyRepository,
    private val dutyTypeRepository: DutyTypeRepository
) : DutyBatchService {

    override fun batchUpload(file: MultipartFile, memberId: Long, yearMonth: YearMonth): DutyBatchResult {
        if (file.originalFilename?.lowercase()?.endsWith(".xlsx") != true)
            throw NotSupportedFileException("xlsx");

        file.inputStream.use { input ->
            val batchResult = sungsimCakeParser.parseDayOff(yearMonth, input)
            val member = memberRepository.findById(memberId).orElseThrow()
            val department =
                member.department ?: throw IllegalArgumentException("Member has no department: id=$memberId")

            val validName = batchResult.getNames()
                .filter { member.name == it || member.name.endsWith(it) }
                .toList()
            if (validName.isEmpty())
                throw NameNotFoundException()
            if (validName.size > 1)
                throw MultipleNameFoundException(validName)

            val nameOnXlsx = validName.first()

            val dutyTypes = dutyTypeRepository.findAllByDepartment(department)
            if (dutyTypes.size != 1) {
                throw DutyTypeNotSingleException(dutyTypes)
            }
            val dutyType = dutyTypes.first()

            dutyRepository.deleteDutiesByMemberAndDutyDateBetween(
                member,
                batchResult.startDate,
                batchResult.endDate
            )
            val workingDays = batchResult.getWorkDays(nameOnXlsx)
            val duties = workingDays.map {
                Duty(dutyDate = it, dutyType = dutyType, member = member)
            }
            val offDays = batchResult.getOffDays(nameOnXlsx)
            dutyRepository.saveAll(duties)
            return DutyBatchResult.success(workingDays.size, offDays.size)
        }
    }

}
