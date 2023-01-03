package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.common.exceptions.AuthenticationException
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.MemoDto
import com.tistory.shanepark.dutypark.duty.service.DutyService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.slf4j.Logger
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/duty")
class DutyApiController(
    private val dutyService: DutyService
) {

    val log: Logger = org.slf4j.LoggerFactory.getLogger(DutyApiController::class.java)

    @PutMapping("update")
    @SlackNotification
    fun updateDuty(
        @RequestBody dutyUpdateDto: DutyUpdateDto,
        loginMember: LoginMember
    ): ResponseEntity<Boolean> {
        checkAuthentication(loginMember, dutyUpdateDto.memberId)
        dutyService.update(dutyUpdateDto)
        return ResponseEntity.ok(true)
    }

    @PutMapping("memo")
    @SlackNotification
    fun updateMemo(
        @RequestBody memoDto: MemoDto,
        loginMember: LoginMember
    ): ResponseEntity<Boolean> {
        checkAuthentication(loginMember, memoDto.memberId)
        dutyService.updateMemo(memoDto)
        return ResponseEntity.ok(true)
    }

    private fun checkAuthentication(
        loginMember: LoginMember, dutyMemberId: Long
    ) {
        if (loginMember.id != dutyMemberId) {
            log.warn("login member and request duty member does not match: login:$loginMember.id, dutyMemberId:${dutyMemberId}")
            throw AuthenticationException("login member and request dutyMemberId does not match")
        }
    }

}
