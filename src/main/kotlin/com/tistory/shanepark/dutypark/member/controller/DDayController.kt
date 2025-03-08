package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.DDayDto
import com.tistory.shanepark.dutypark.member.domain.dto.DDaySaveDto
import com.tistory.shanepark.dutypark.member.service.DDayService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/dday")
class DDayController(
    private val dDayService: DDayService
) {

    @PostMapping
    @SlackNotification
    fun createDDay(
        @Login member: LoginMember,
        @Valid @RequestBody dDaySaveDto: DDaySaveDto
    ): DDayDto {
        return dDayService.createDDay(member, dDaySaveDto)
    }

    @GetMapping
    fun findDDays(@Login login: LoginMember): List<DDayDto> {
        return dDayService.findDDays(login, login.id)
    }

    @GetMapping("/{id}")
    fun findDDaysByMemberId(
        @Login(required = false) member: LoginMember?,
        @PathVariable id: Long
    ): List<DDayDto> {
        return dDayService.findDDays(member, id)
    }


    @DeleteMapping("/{id}")
    fun deleteDDay(
        @Login member: LoginMember,
        @PathVariable id: Long
    ) {
        dDayService.deleteDDay(member, id)
    }

    @PutMapping("/{id}")
    fun updateDDay(
        @Login member: LoginMember,
        @PathVariable id: Long,
        @Valid @RequestBody dDaySaveDto: DDaySaveDto
    ): ResponseEntity<Void> {
        dDayService.updateDDay(
            loginMember = member,
            id = id,
            title = dDaySaveDto.title,
            date = dDaySaveDto.date,
            isPrivate = dDaySaveDto.isPrivate
        )
        return ResponseEntity
            .status(HttpStatus.OK)
            .build()
    }

}
