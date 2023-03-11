package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.MemoDto
import com.tistory.shanepark.dutypark.duty.service.DutyService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.slf4j.Logger
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/duty")
class DutyController(
    private val dutyService: DutyService
) {

    val log: Logger = org.slf4j.LoggerFactory.getLogger(DutyController::class.java)

    @PutMapping("update")
    @SlackNotification
    fun updateDuty(
        @RequestBody dutyUpdateDto: DutyUpdateDto,
        @Login loginMember: LoginMember
    ): ResponseEntity<Boolean> {
        checkAuthentication(loginMember, dutyUpdateDto.memberId)
        dutyService.update(dutyUpdateDto)
        return ResponseEntity.ok(true)
    }

    @PutMapping("memo")
    @SlackNotification
    fun updateMemo(
        @RequestBody memoDto: MemoDto,
        @Login loginMember: LoginMember
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
            throw DutyparkAuthException("login member and request dutyMemberId does not match")
        }
    }

}
