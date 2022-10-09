package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.duty.service.DutyService
import com.tistory.shanepark.dutypark.member.dto.MemberDto
import com.tistory.shanepark.dutypark.member.service.MemberService
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestParam
import java.time.LocalDateTime

@Controller
class DutyController(
    val memberService: MemberService,
    val dutyService: DutyService,
) {

    @GetMapping("duty/{name}")
    fun memberByName(
        model: Model,
        @PathVariable name: String,
        @RequestParam(required = false) year: Int?,
        @RequestParam(required = false) month: Int?,
    ): String {
        val now = LocalDateTime.now()
        val year = year ?: now.year
        val month = month ?: now.monthValue
        val member = memberService.findMemberByName(name)

        dutyService.findDutyByMemberAndYearAndMonth(member, year, month).let {
            model.addAttribute("duties", it)
        }
        dutyService.findAllDutyTypes(member.department).let {
            model.addAttribute("dutyTypes", it)
        }

        model.addAttribute("member", MemberDto(member))
        model.addAttribute("year", year)
        model.addAttribute("month", month)

        return "duty/duty"
    }

}
