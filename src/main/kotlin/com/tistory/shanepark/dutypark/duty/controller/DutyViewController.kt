package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeDto
import com.tistory.shanepark.dutypark.duty.service.DutyService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.servlet.http.HttpServletRequest
import org.slf4j.Logger
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestParam
import java.time.LocalDateTime
import java.time.YearMonth

@Controller
class DutyViewController(
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
        @Login loginMember: LoginMember
    ): String {
        val member = memberService.findMemberByName(name)
        if (loginMember.id != member.id) {
            val message =
                "login member and request duty member does not match: login:$loginMember.id, dutyMemberId:${member.id}"
            log.warn(message)
            throw DutyparkAuthException(message)
        }
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
        val yearValue = year ?: now.year
        val monthValue = month ?: now.monthValue
        val member = memberService.findMemberByName(name)

        addDutyData(member, yearValue, monthValue, model)
        addYearMonthData(yearValue, monthValue, model)
        return "duty/duty"
    }

    private fun addDutyData(
        member: Member,
        year: Int,
        month: Int,
        model: Model
    ) {
        val department: Department = member.department?.let {
            it
        } ?: return

        model.addAttribute("member", MemberDto(member))
        model.addAttribute("offColor", department.offColor.name)

        dutyService.findDutyByMemberAndYearAndMonth(member, year, month).let {
            model.addAttribute("duties", it)
        }

        val dutyTypes = department.dutyTypes
            .map { DutyTypeDto(it) }
            .sortedBy { it.position }
            .toMutableList()
        dutyTypes.add(0, DutyTypeDto(name = "OFF", position = -1, color = department.offColor.toString()))
        model.addAttribute("dutyTypes", dutyTypes)
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
