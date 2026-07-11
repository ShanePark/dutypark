package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternUpdateDto
import com.tistory.shanepark.dutypark.duty.service.DutyPatternService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.validation.Valid
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/duty/pattern/me")
class DutyPatternController(
    private val dutyPatternService: DutyPatternService,
) {
    @GetMapping
    fun getMine(@Login loginMember: LoginMember): DutyPatternDto =
        dutyPatternService.getMine(loginMember.id)

    @PutMapping
    fun updateMine(
        @Login loginMember: LoginMember,
        @Valid @RequestBody request: DutyPatternUpdateDto,
    ): DutyPatternDto = dutyPatternService.updateMine(loginMember.id, request)

    @DeleteMapping
    fun deleteMine(@Login loginMember: LoginMember): ResponseEntity<Void> {
        dutyPatternService.deleteMine(loginMember.id)
        return ResponseEntity.noContent().build()
    }
}
