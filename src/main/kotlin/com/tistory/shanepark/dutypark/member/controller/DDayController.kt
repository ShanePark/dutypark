package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
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
    private val log: org.slf4j.Logger = org.slf4j.LoggerFactory.getLogger(this.javaClass)

    @PostMapping
    @SlackNotification
    fun createDDay(
        @Login member: LoginMember,
        @Valid @RequestBody dDaySaveDto: DDaySaveDto
    ): ResponseEntity<Any> {
        val createDDay = dDayService.createDDay(member, dDaySaveDto)

        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(createDDay)
    }

    @GetMapping
    fun findDDays(
        @Login member: LoginMember
    ): ResponseEntity<Any> {
        val findDDays = dDayService.findDDays(member, member.id)

        return ResponseEntity
            .status(HttpStatus.OK)
            .body(findDDays)
    }

    @GetMapping("/{id}")
    fun findDDaysByMemberId(
        @Login(required = false) member: LoginMember?,
        @PathVariable id: Long
    ): ResponseEntity<Any> {
        val findDDay = dDayService.findDDays(member, id)

        return ResponseEntity
            .status(HttpStatus.OK)
            .body(findDDay)
    }


    @DeleteMapping("/{id}")
    @SlackNotification
    fun deleteDDay(
        @Login member: LoginMember,
        @PathVariable id: Long
    ): ResponseEntity<Any> {
        dDayService.deleteDDay(member, id)

        return ResponseEntity
            .status(HttpStatus.NO_CONTENT)
            .build()
    }

    @PutMapping("/{id}")
    @SlackNotification
    fun updateDDay(
        @Login member: LoginMember,
        @PathVariable id: Long,
        @Valid @RequestBody dDaySaveDto: DDaySaveDto
    ): ResponseEntity<Any> {
        val updateDDay = dDayService.updateDDay(
            loginMember = member,
            id = id,
            title = dDaySaveDto.title,
            date = dDaySaveDto.date,
            isPrivate = dDaySaveDto.isPrivate
        )
        return ResponseEntity
            .status(HttpStatus.OK)
            .body(updateDDay)
    }

}
