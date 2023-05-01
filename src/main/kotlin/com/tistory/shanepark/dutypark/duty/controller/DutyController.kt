package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.service.DutyService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.slf4j.Logger
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import java.time.YearMonth

@RestController
@RequestMapping("/api/duty")
class DutyController(
    private val dutyService: DutyService,
    private val memberRepository: MemberRepository,
) {
    val log: Logger = org.slf4j.LoggerFactory.getLogger(DutyController::class.java)

    @GetMapping
    fun getDuties(
        @RequestParam year: Int,
        @RequestParam month: Int,
        @RequestParam memberId: Long,
    ): List<DutyDto> {
        return dutyService.getDuties(memberId = memberId, YearMonth.of(year, month))
    }

    @PutMapping("change")
    @SlackNotification
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
        val dutyMember = memberRepository.findMemberWithDepartment(dutyMemberId).orElseThrow()
        if (!dutyService.canEdit(loginMember, dutyMember)) {
            log.warn("login member and request duty member does not match: login:$loginMember.id, dutyMemberId:${dutyMemberId}")
            throw DutyparkAuthException("login member and request dutyMemberId does not match")
        }
    }

}
