package com.tistory.shanepark.dutypark.duty.batch.service

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
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
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
    private val teamRepository: TeamRepository,
    private val dutyRepository: DutyRepository,
    private val dutyTypeRepository: DutyTypeRepository
) : DutyBatchService {
    override fun batchUploadMember(file: MultipartFile, memberId: Long, yearMonth: YearMonth): DutyBatchResult {
        DutyBatchTemplate.SUNGSIM_CAKE.checkSupportedFile(file)

        file.inputStream.use { input ->
            val batchParseResult = sungsimCakeParser.parseDayOff(yearMonth, input)
            val member = memberRepository.findById(memberId).orElseThrow()
            val team =
                member.team ?: throw IllegalArgumentException("Member has no team: id=$memberId")

            val validName = batchParseResult.findValidNames(member.name)
            if (validName.isEmpty())
                throw NameNotFoundException()
            if (validName.size > 1)
                throw MultipleNameFoundException(validName)

            val nameOnXlsx = validName.first()
            val dutyType = findOnlyDutyType(team)
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

    override fun batchUploadTeam(
        file: MultipartFile,
        teamId: Long,
        yearMonth: YearMonth
    ): DutyBatchTeamResult {
        DutyBatchTemplate.SUNGSIM_CAKE.checkSupportedFile(file)
        val team = teamRepository.findById(teamId).orElseThrow()
        val dutyType = findOnlyDutyType(team)

        file.inputStream.use { input ->
            return batchUploadTeam(
                input = input,
                yearMonth = yearMonth,
                team = team,
                dutyType = dutyType
            )
        }
    }

    private fun batchUploadTeam(
        input: InputStream,
        yearMonth: YearMonth,
        team: Team,
        dutyType: DutyType
    ): DutyBatchTeamResult {
        val batchParseResult = sungsimCakeParser.parseDayOff(yearMonth, input)
        findNonMembersAndCreate(batchParseResult, team)

        val dutyBatchResults: MutableList<Pair<String, DutyBatchResult>> = mutableListOf()
        team.members.forEach {
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

    private fun findNonMembersAndCreate(batchParseResult: BatchParseResult, team: Team) {
        val namesOnXlsx = batchParseResult.getNames().toMutableSet()
        team.members.map { batchParseResult.findValidNames(it.name) }.flatten().forEach { name ->
            namesOnXlsx.remove(name)
        }

        namesOnXlsx.forEach {
            val member = Member(name = it)
            team.addMember(member)
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

    private fun findOnlyDutyType(team: Team): DutyType {
        val dutyTypes = dutyTypeRepository.findAllByTeam(team)
        if (dutyTypes.size != 1) {
            throw DutyTypeNotSingleException(dutyTypes)
        }
        val dutyType = dutyTypes.first()
        return dutyType
    }

}
