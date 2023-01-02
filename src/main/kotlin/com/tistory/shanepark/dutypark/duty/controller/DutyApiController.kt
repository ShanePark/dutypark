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
        @RequestAttribute loginMember: LoginMember?
    ): ResponseEntity<Boolean> {
        loginMember?.let {
            it.id?.let { memberId ->
                if (memberId == dutyUpdateDto.memberId) {
                    dutyService.update(dutyUpdateDto)
                    return ResponseEntity.ok(true)
                }
                log.warn("login member and request duty member does not match: $memberId, ${dutyUpdateDto.memberId}")
                throw AuthenticationException("login member and request duty member does not match")
            }
        } ?: throw AuthenticationException("login is required")
    }

    @PutMapping("memo")
    @SlackNotification
    fun updateMemo(
        @RequestBody memoDto: MemoDto,
        @RequestAttribute loginMember: LoginMember?
    ): ResponseEntity<Boolean> {
        // TODO: there will be a lot of duplicated code to use loginMember. need to refactor
        dutyService.updateMemo(memoDto)
        return ResponseEntity.ok(true)
    }

}
