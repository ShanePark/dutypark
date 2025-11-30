package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.DDayDto
import com.tistory.shanepark.dutypark.member.domain.dto.DDaySaveDto
import com.tistory.shanepark.dutypark.member.service.DDayService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/dday")
class DDayController(
    private val dDayService: DDayService
) {

    @PostMapping
    fun saveDday(
        @Login member: LoginMember,
        @Valid @RequestBody dDaySaveDto: DDaySaveDto
    ): DDayDto {
        if (dDaySaveDto.id == null) {
            return dDayService.createDDay(member, dDaySaveDto)
        }
        return dDayService.updateDDay(loginMember = member, dDaySaveDto = dDaySaveDto)
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

}
