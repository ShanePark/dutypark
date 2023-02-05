package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.DDayCreateDto
import com.tistory.shanepark.dutypark.member.service.DDayService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
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
    fun create(
        @Login member: LoginMember,
        @RequestBody dDayCreateDto: DDayCreateDto
    ): ResponseEntity<Any> {
        val createDDay = dDayService.createDDay(member, dDayCreateDto)

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

    @DeleteMapping
    @RequestMapping("/{id}")
    fun deleteDDay(
        @Login member: LoginMember,
        @PathVariable id: Long
    ): ResponseEntity<Any> {
        dDayService.deleteDDay(member, id)

        return ResponseEntity
            .status(HttpStatus.NO_CONTENT)
            .build()
    }

    @PatchMapping
    @RequestMapping(params = ["prefix", "ids"])
    fun rearrangeOrders(
        @Login member: LoginMember,
        @RequestParam prefix: Long,
        @RequestParam ids: List<Long>
    ): ResponseEntity<Any> {
        dDayService.rearrangeOrders(member, prefix, ids)

        return ResponseEntity
            .status(HttpStatus.NO_CONTENT)
            .build()
    }

}
