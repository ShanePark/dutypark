package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyBatchUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.OtherDutyResponse
import com.tistory.shanepark.dutypark.duty.service.DutyService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/duty")
class DutyController(
    private val dutyService: DutyService,
) {

    @GetMapping
    fun getDuties(
        @Login(required = false) loginMember: LoginMember?,
        @RequestParam year: Int,
        @RequestParam month: Int,
        @RequestParam memberId: Long,
    ): List<DutyDto> {
        return dutyService.getDutiesAndInitLazyIfNeeded(
            loginMember = loginMember,
            memberId = memberId,
            year = year,
            month = month
        )
    }

    @GetMapping("/others")
    fun getOthersDuties(
        @Login loginMember: LoginMember,
        @RequestParam year: Int,
        @RequestParam month: Int,
        @RequestParam memberIds: List<Long>,
    ): List<OtherDutyResponse> {
        return dutyService.getOtherDuties(
            loginMember = loginMember,
            memberIds = memberIds,
            year = year,
            month = month
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

    @PutMapping("batch")
    fun batchUpdateDuty(
        @RequestBody dutyBatchUpdateDto: DutyBatchUpdateDto,
        @Login loginMember: LoginMember
    ): ResponseEntity<Boolean> {
        checkAuthentication(loginMember, dutyBatchUpdateDto.memberId)
        dutyService.update(dutyBatchUpdateDto)
        return ResponseEntity.ok(true)
    }

    private fun checkAuthentication(
        loginMember: LoginMember, dutyMemberId: Long
    ) {
        if (!dutyService.canEdit(loginMember, dutyMemberId)) {
            throw AuthException("login member doesn't have permission to edit duty")
        }
    }

}
