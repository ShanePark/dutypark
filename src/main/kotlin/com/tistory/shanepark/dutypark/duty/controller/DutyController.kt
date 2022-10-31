package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.duty.service.DutyService
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.service.MemberService
import org.slf4j.Logger
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestParam
import java.time.LocalDateTime
import java.time.YearMonth
import javax.servlet.http.HttpServletRequest

@Controller
class DutyController(
    val memberService: MemberService,
    val dutyService: DutyService,
) {

    val log: Logger = org.slf4j.LoggerFactory.getLogger(this.javaClass)

    @GetMapping("/duty/edit/{name}")
    fun editDuty(
        @PathVariable name: String,
        model: Model,
        year: Int,
        month: Int,
    ): String {
        val member = memberService.findMemberByName(name)
        addDutyData(member, year, month, model)
        addYearMonthData(year, month, model)

        return "duty/duty-edit"
    }

    @GetMapping("/duty/{name}")
    fun retrieveMemberDuty(
        model: Model,
        @PathVariable name: String,
        @RequestParam(required = false) year: Int?,
        @RequestParam(required = false) month: Int?,
        request: HttpServletRequest,
    ): String {

        log.info("request: $name, $year-$month, ip: ${request.remoteAddr}")

        val now = LocalDateTime.now()
        val year = year ?: now.year
        val month = month ?: now.monthValue
        val member = memberService.findMemberByName(name)

        addDutyData(member, year, month, model)
        addYearMonthData(year, month, model)
        return "duty/duty"
    }

    private fun addDutyData(
        member: Member,
        year: Int,
        month: Int,
        model: Model
    ) {
        model.addAttribute("member", MemberDto(member))
        model.addAttribute("offColor", member.department.offColor.name)

        dutyService.findDutyByMemberAndYearAndMonth(member, year, month).let {
            model.addAttribute("duties", it)
        }
        dutyService.findAllDutyTypes(member.department).let {
            model.addAttribute("dutyTypes", it)
        }
    }

    private fun addYearMonthData(year: Int, month: Int, model: Model) {
        YearMonth.of(year, month).let {
            model.addAttribute("year", year)
            model.addAttribute("month", month)
            model.addAttribute("prevMonth", it.minusMonths(1))
            model.addAttribute("nextMonth", it.plusMonths(1))
            model.addAttribute("offset", it.atDay(1).dayOfWeek.value)
            model.addAttribute("lastDay", it.lengthOfMonth())
        }
    }

}
