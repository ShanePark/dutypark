package com.tistory.shanepark.dutypark.team.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.schedule.domain.dto.TeamScheduleDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.dto.TeamScheduleSaveDto
import com.tistory.shanepark.dutypark.team.domain.entity.TeamSchedule
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import com.tistory.shanepark.dutypark.team.repository.TeamScheduleRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Service
@Transactional
class TeamScheduleService(
    private val teamScheduleRepository: TeamScheduleRepository,
    private val teamRepository: TeamRepository,
    private val memberRepository: MemberRepository,
    private val teamService: TeamService,
) {
    private val log = logger()

    fun create(login: LoginMember, saveDto: TeamScheduleSaveDto): TeamScheduleDto {
        val author = memberRepository.findById(login.id).orElseThrow()
        val team = teamRepository.findById(saveDto.teamId).orElseThrow()
        val startDate = saveDto.startDateTime.toLocalDate()
        val sameDateStartSchedules = teamScheduleRepository.findTeamSchedulesOfTeamRangeIn(
            team,
            startDate.atStartOfDay(),
            startDate.atTime(23, 59, 59)
        )

        val schedule = TeamSchedule(
            team = team,
            createMember = author,
            content = saveDto.content,
            description = saveDto.description,
            startDateTime = saveDto.startDateTime,
            endDateTime = saveDto.endDateTime,
            position = sameDateStartSchedules.size
        )
        teamScheduleRepository.save(schedule)
        log.auditEventAfterCommit("team_schedule.created", login.toAuditActor(), scheduleAuditTarget(schedule),
            mapOf("startDateTime" to schedule.startDateTime, "endDateTime" to schedule.endDateTime))
        return TeamScheduleDto.ofSimple(schedule)
    }

    @Transactional(readOnly = true)
    fun findTeamSchedules(teamId: Long, calendarView: CalendarView): Array<List<TeamScheduleDto>> {
        val team = teamRepository.findById(teamId).orElseThrow()
        val schedules = teamScheduleRepository.findTeamSchedulesOfTeamRangeIn(
            team = team,
            start = calendarView.rangeFromDateTime,
            end = calendarView.rangeUntilDateTime,
        )
        val array = calendarView.makeCalendarArray<TeamScheduleDto>()
        schedules.map { TeamScheduleDto.of(calendar = calendarView, schedule = it) }
            .flatten()
            .sortedWith(compareBy({ it.position }, { it.startDateTime }))
            .forEach {
                if (!calendarView.isInRange(it.curDate)) {
                    return@forEach
                }
                val dayIndex = calendarView.getIndex(date = it.curDate)
                array[dayIndex] = array[dayIndex] + it
            }
        return array
    }

    @Transactional(readOnly = true)
    fun findById(id: UUID): TeamScheduleDto {
        val schedule = teamScheduleRepository.findById(id).orElseThrow()
        return TeamScheduleDto.ofSimple(schedule)
    }

    fun update(login: LoginMember, saveDto: TeamScheduleSaveDto): TeamScheduleDto {
        val schedule = teamScheduleRepository.findById(saveDto.id!!).orElseThrow()
        val actualTeamId = schedule.team.id ?: throw IllegalStateException("Team ID is null")
        teamService.checkCanManage(login = login, teamId = actualTeamId)
        if (saveDto.teamId != actualTeamId) {
            throw BadRequestException("team.schedule.teamMismatch")
        }

        val previousStart = schedule.startDateTime
        val previousEnd = schedule.endDateTime
        val changedFields = listOfNotNull(
            "content".takeIf { schedule.content != saveDto.content },
            "description".takeIf { schedule.description != saveDto.description },
            "startDateTime".takeIf { schedule.startDateTime != saveDto.startDateTime },
            "endDateTime".takeIf { schedule.endDateTime != saveDto.endDateTime },
        )
        val author = memberRepository.findById(login.id).orElseThrow()
        schedule.update(saveDto = saveDto, updateMember = author)
        if (changedFields.isNotEmpty()) {
            log.auditEventAfterCommit("team_schedule.updated", login.toAuditActor(), scheduleAuditTarget(schedule),
                mapOf("changedFields" to changedFields,
                    "startDateTimeBefore" to previousStart, "startDateTimeAfter" to schedule.startDateTime,
                    "endDateTimeBefore" to previousEnd, "endDateTimeAfter" to schedule.endDateTime))
        }
        return TeamScheduleDto.ofSimple(schedule)
    }

    fun delete(id: UUID, actor: LoginMember? = null) {
        val teamSchedule = teamScheduleRepository.findById(id).orElseThrow()
        teamScheduleRepository.delete(teamSchedule)
        log.auditEventAfterCommit("team_schedule.deleted", actor?.toAuditActor(), scheduleAuditTarget(teamSchedule))
    }

    private fun scheduleAuditTarget(schedule: TeamSchedule) = mapOf(
        "scheduleId" to schedule.id, "teamId" to schedule.team.id,
    )
}
