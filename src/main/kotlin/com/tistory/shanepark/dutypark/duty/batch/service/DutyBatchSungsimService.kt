package com.tistory.shanepark.dutypark.duty.batch.service

import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.duty.batch.SungsimCakeParser
import com.tistory.shanepark.dutypark.duty.batch.domain.BatchParseResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTeamResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.batch.exceptions.DutyTypeNotSingleException
import com.tistory.shanepark.dutypark.duty.batch.exceptions.MultipleNameFoundException
import com.tistory.shanepark.dutypark.duty.batch.exceptions.NameNotFoundException
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.multipart.MultipartFile
import java.io.InputStream
import java.time.LocalDate
import java.time.YearMonth

@Service
@Transactional
class DutyBatchSungsimService(
    private val sungsimCakeParser: SungsimCakeParser,
    private val memberRepository: MemberRepository,
    private val departmentRepository: DepartmentRepository,
    private val dutyRepository: DutyRepository,
    private val dutyTypeRepository: DutyTypeRepository
) : DutyBatchService {
    override fun batchUploadMember(file: MultipartFile, memberId: Long, yearMonth: YearMonth): DutyBatchResult {
        DutyBatchTemplate.SUNGSIM_CAKE.checkSupportedFile(file)

        file.inputStream.use { input ->
            val batchParseResult = sungsimCakeParser.parseDayOff(yearMonth, input)
            val member = memberRepository.findById(memberId).orElseThrow()
            val department =
                member.department ?: throw IllegalArgumentException("Member has no department: id=$memberId")

            val validName = batchParseResult.findValidNames(member.name)
            if (validName.isEmpty())
                throw NameNotFoundException()
            if (validName.size > 1)
                throw MultipleNameFoundException(validName)

            val nameOnXlsx = validName.first()
            val dutyType = findOnlyDutyType(department)
            val workDays = batchParseResult.getWorkDays(nameOnXlsx)

            saveBatchDuty(
                member = member,
                batchParseResult = batchParseResult,
                workDays = workDays,
                dutyType = dutyType
            )

            return DutyBatchResult.success(
                workingDays = workDays.size,
                offDays = batchParseResult.getOffDays(nameOnXlsx).size,
                batchParseResult.startDate,
                batchParseResult.endDate
            )
        }
    }

    override fun batchUploadDepartment(
        file: MultipartFile,
        departmentId: Long,
        yearMonth: YearMonth
    ): DutyBatchTeamResult {
        DutyBatchTemplate.SUNGSIM_CAKE.checkSupportedFile(file)
        val department = departmentRepository.findById(departmentId).orElseThrow()
        val dutyType = findOnlyDutyType(department)

        file.inputStream.use { input ->
            return batchUploadDepartment(
                input = input,
                yearMonth = yearMonth,
                department = department,
                dutyType = dutyType
            )
        }
    }

    private fun batchUploadDepartment(
        input: InputStream,
        yearMonth: YearMonth,
        department: Department,
        dutyType: DutyType
    ): DutyBatchTeamResult {
        val batchParseResult = sungsimCakeParser.parseDayOff(yearMonth, input)
        findNonMembersAndCreate(batchParseResult, department)

        val dutyBatchResults: MutableList<Pair<String, DutyBatchResult>> = mutableListOf()
        department.members.forEach {
            val validNames = batchParseResult.findValidNames(it.name)
            if (validNames.size > 1) {
                dutyBatchResults.add(
                    Pair(
                        it.name,
                        DutyBatchResult.fail(MultipleNameFoundException::class.simpleName!!)
                    )
                )
                return@forEach
            }

            if (validNames.isEmpty()) {
                dutyBatchResults.add(
                    Pair(
                        it.name,
                        DutyBatchResult.fail(NameNotFoundException::class.simpleName!!)
                    )
                )
                return@forEach
            }

            val nameOnXlsx = validNames.first()
            val workDays = batchParseResult.getWorkDays(nameOnXlsx)

            saveBatchDuty(
                member = it,
                batchParseResult = batchParseResult,
                workDays = workDays,
                dutyType = dutyType
            )

            dutyBatchResults.add(
                Pair(
                    it.name,
                    DutyBatchResult.success(
                        workingDays = workDays.size,
                        offDays = batchParseResult.getOffDays(nameOnXlsx).size,
                        batchParseResult.startDate,
                        batchParseResult.endDate
                    )
                )
            )
        }

        return DutyBatchTeamResult.success(
            startDate = batchParseResult.startDate,
            endDate = batchParseResult.endDate,
            dutyBatchResult = dutyBatchResults
        )
    }

    private fun findNonMembersAndCreate(batchParseResult: BatchParseResult, department: Department) {
        val namesOnXlsx = batchParseResult.getNames().toMutableSet()
        department.members.map { batchParseResult.findValidNames(it.name) }.flatten().forEach { name ->
            namesOnXlsx.remove(name)
        }

        namesOnXlsx.forEach {
            val member = Member(name = it)
            department.addMember(member)
            memberRepository.save(member)
        }
    }

    private fun saveBatchDuty(
        member: Member,
        batchParseResult: BatchParseResult,
        workDays: List<LocalDate>,
        dutyType: DutyType
    ) {
        dutyRepository.deleteDutiesByMemberAndDutyDateBetween(
            member = member,
            start = batchParseResult.startDate,
            end = batchParseResult.endDate
        )
        val duties = workDays.map {
            Duty(dutyDate = it, dutyType = dutyType, member = member)
        }
        dutyRepository.saveAll(duties)
    }

    private fun findOnlyDutyType(department: Department): DutyType {
        val dutyTypes = dutyTypeRepository.findAllByDepartment(department)
        if (dutyTypes.size != 1) {
            throw DutyTypeNotSingleException(dutyTypes)
        }
        val dutyType = dutyTypes.first()
        return dutyType
    }

}
