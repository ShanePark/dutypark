package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.service.DutyService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.slf4j.Logger
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import java.time.YearMonth

@RestController
@RequestMapping("/api/duty")
class DutyController(
    private val dutyService: DutyService,
) {
    val log: Logger = org.slf4j.LoggerFactory.getLogger(DutyController::class.java)

    @GetMapping
    fun getDuties(
        @Login(required = false) loginMember: LoginMember?,
        @RequestParam year: Int,
        @RequestParam month: Int,
        @RequestParam memberId: Long,
    ): List<DutyDto> {
        return dutyService.getDuties(
            loginMember = loginMember,
            memberId = memberId,
            yearMonth = YearMonth.of(year, month)
        )
    }

    @PutMapping("change")
    fun updateDuty(
        @RequestBody dutyUpdateDto: DutyUpdateDto,
        @Login loginMember: LoginMember
    ): ResponseEntity<Boolean> {
        checkAuthentication(loginMember, dutyUpdateDto.memberId)
        dutyService.update(dutyUpdateDto)
        return ResponseEntity.ok(true)
    }

    private fun checkAuthentication(
        loginMember: LoginMember, dutyMemberId: Long
    ) {
        if (!dutyService.canEdit(loginMember, dutyMemberId)) {
            log.warn("login member and request duty member does not match: login:$loginMember.id, dutyMemberId:${dutyMemberId}")
            throw DutyparkAuthException("login member doesn't have permission to edit duty")
        }
    }

}
