package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.team.domain.dto.SimpleTeamDto
import com.tistory.shanepark.dutypark.team.domain.dto.TeamCreateDto
import com.tistory.shanepark.dutypark.team.domain.dto.TeamDto
import com.tistory.shanepark.dutypark.team.domain.enums.TeamNameCheckResult
import com.tistory.shanepark.dutypark.team.domain.enums.TeamNameCheckResult.*
import com.tistory.shanepark.dutypark.team.service.TeamService
import jakarta.validation.Valid
import org.springframework.data.domain.Pageable
import org.springframework.data.web.PageableDefault
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/admin/api/teams")
class TeamAdminController(
    val teamService: TeamService,
) {

    private val log = logger()

    @GetMapping
    fun findAll(
        @PageableDefault(page = 0, size = 10) page: Pageable,
        @RequestParam(required = false, defaultValue = "") keyword: String,
    ): PageResponse<SimpleTeamDto> {
        val result = teamService.findAllWithMemberCount(pageable = page, keyword = keyword)
        return PageResponse(result)
    }

    @PostMapping
    fun create(@RequestBody @Valid teamCreateDto: TeamCreateDto): TeamDto {
        return teamService.create(teamCreateDto)
    }

    @PostMapping("/check")
    fun nameCheck(@RequestBody payload: Map<String, String>): TeamNameCheckResult {
        val name = payload["name"] ?: ""
        if (name.length < 2)
            return TOO_SHORT
        if (name.length > 20)
            return TOO_LONG
        if (teamService.isDuplicated(name))
            return DUPLICATED
        return OK
    }

    @DeleteMapping("/{id}")
    fun delete(@PathVariable id: Long) {
        teamService.delete(id)
    }

}
