package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.domain.DutyAbbreviation
import com.tistory.shanepark.dutypark.duty.domain.DutyColorPalette
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditChangeAfterCommit
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.publiccontent.service.PublicContentService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

@Service
@Transactional
class DutyTypeService(
    private val dutyTypeRepository: DutyTypeRepository,
    private val teamRepository: TeamRepository,
    private val dutyRepository: DutyRepository,
    private val clock: Clock,
    private val publicContentService: PublicContentService,
) {
    private val log = logger()

    fun findById(id: Long): DutyTypeDto {
        val dutyType = dutyTypeRepository.findById(id).orElseThrow()
        return DutyTypeDto(dutyType)
    }

    @Transactional(timeout = 20)
    fun updateVisibility(dutyTypeId: Long, hidden: Boolean, actor: LoginMember? = null): DutyType {
        val teamId = dutyTypeRepository.findTeamIdById(dutyTypeId) ?: throw NoSuchElementException()
        val team = teamRepository.findByIdForUpdate(teamId).orElseThrow()
        val dutyType = team.dutyTypes.firstOrNull { it.id == dutyTypeId } ?: throw NoSuchElementException()
        if (dutyType.hidden == hidden) return dutyType
        val before = mapOf("hidden" to dutyType.hidden)
        dutyType.hidden = hidden
        if (hidden) {
            dutyRepository.deleteAutomaticByDutyTypeAndDutyDateGreaterThanEqual(
                dutyType,
                LocalDate.now(clock.withZone(SEOUL)),
            )
        }
        log.auditChangeAfterCommit(
            event = "duty_type.visibility_changed",
            actor = actor?.toAuditActor(),
            target = dutyTypeAuditTarget(teamId = team.id, teamName = team.name, dutyType = dutyType),
            before = before,
            after = mapOf("hidden" to dutyType.hidden),
        )
        return dutyType
    }

    @Transactional(timeout = 20)
    fun addDutyType(dutyTypeCreateDto: DutyTypeCreateDto, actor: LoginMember? = null): DutyType {
        val team = teamRepository.findByIdForUpdate(dutyTypeCreateDto.teamId).orElseThrow()
        publicContentService.validateContent(dutyTypeCreateDto.name)
        val abbreviation = DutyAbbreviation.normalizeAndValidate(dutyTypeCreateDto.abbreviation)
        abbreviation?.let(publicContentService::validateContent)
        if (team.dutyTypes.any { it.name == dutyTypeCreateDto.name }) {
            throw IllegalArgumentException("DutyType already exists")
        }
        DutyColorPalette.validate(dutyTypeCreateDto.color)
        return team.addDutyType(dutyTypeCreateDto.name, dutyTypeCreateDto.color).also {
            it.abbreviation = abbreviation
            log.auditEventAfterCommit(
                event = "duty_type.created",
                actor = actor?.toAuditActor(),
                target = mapOf(
                    "type" to "DutyType",
                    "teamId" to team.id,
                    "teamName" to team.name,
                    "dutyTypeName" to it.name,
                ),
                details = mapOf(
                    "color" to it.color,
                    "abbreviation" to it.abbreviation,
                    "position" to it.position,
                    "hidden" to it.hidden,
                ),
            )
        }
    }

    fun update(dutyTypeUpdateDto: DutyTypeUpdateDto, actor: LoginMember? = null): DutyType {
        val dutyType = dutyTypeRepository.findById(dutyTypeUpdateDto.id).orElseThrow()
        val teamId = dutyType.team.id ?: throw IllegalArgumentException("DutyType has no team")
        val team = teamRepository.findByIdWithDutyTypes(teamId).orElseThrow()
        publicContentService.validateContent(dutyTypeUpdateDto.name)
        val abbreviation = DutyAbbreviation.normalizeAndValidate(dutyTypeUpdateDto.abbreviation)
        abbreviation?.let(publicContentService::validateContent)
        val before = mapOf(
            "name" to dutyType.name,
            "color" to dutyType.color,
            "abbreviation" to dutyType.abbreviation,
        )

        team.dutyTypes
            .filter { it.id != dutyType.id }
            .forEach {
                if (it.name == dutyTypeUpdateDto.name) {
                    throw IllegalArgumentException("dutyType.name.duplicate")
                }
            }

        DutyColorPalette.validate(dutyTypeUpdateDto.color, dutyType.color)
        dutyType.name = dutyTypeUpdateDto.name
        dutyType.color = dutyTypeUpdateDto.color
        if (dutyTypeUpdateDto.abbreviationSpecified) {
            dutyType.abbreviation = abbreviation
        }
        log.auditChangeAfterCommit(
            event = "duty_type.updated",
            actor = actor?.toAuditActor(),
            target = dutyTypeAuditTarget(teamId = team.id, teamName = team.name, dutyType = dutyType),
            before = before,
            after = mapOf(
                "name" to dutyType.name,
                "color" to dutyType.color,
                "abbreviation" to dutyType.abbreviation,
            ),
        )
        return dutyType
    }

    fun swapDutyTypePosition(dutyTypeId1: Long, dutyTypeId2: Long, actor: LoginMember? = null) {
        if (dutyTypeId1 == dutyTypeId2)
            throw IllegalArgumentException("Same duty types can't be swapped")

        val dutyType1 = dutyTypeRepository.findById(dutyTypeId1).orElseThrow()
        val dutyType2 = dutyTypeRepository.findById(dutyTypeId2).orElseThrow()

        val before = mapOf(
            "firstPosition" to dutyType1.position,
            "secondPosition" to dutyType2.position,
        )
        dutyType1.position = dutyType2.position.also { dutyType2.position = dutyType1.position }
        log.auditChangeAfterCommit(
            event = "duty_type.positions_swapped",
            actor = actor?.toAuditActor(),
            target = mapOf(
                "type" to "DutyTypePositionSwap",
                "teamId" to dutyType1.team.id,
                "firstDutyTypeId" to dutyType1.id,
                "firstDutyTypeName" to dutyType1.name,
                "secondDutyTypeId" to dutyType2.id,
                "secondDutyTypeName" to dutyType2.name,
            ),
            before = before,
            after = mapOf(
                "firstPosition" to dutyType1.position,
                "secondPosition" to dutyType2.position,
            ),
        )
    }

    private fun dutyTypeAuditTarget(teamId: Long?, teamName: String, dutyType: DutyType) = mapOf(
        "type" to "DutyType",
        "teamId" to teamId,
        "teamName" to teamName,
        "id" to dutyType.id,
        "dutyTypeName" to dutyType.name,
    )

    companion object {
        private val SEOUL: ZoneId = ZoneId.of("Asia/Seoul")
    }
}
