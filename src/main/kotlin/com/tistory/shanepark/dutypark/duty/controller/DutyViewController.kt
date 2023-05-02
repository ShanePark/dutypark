package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeDto
import com.tistory.shanepark.dutypark.duty.service.DutyService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.servlet.http.HttpServletRequest
import org.slf4j.Logger
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import java.time.YearMonth

@Controller
class DutyViewController(
    val memberService: MemberService,
    val dutyService: DutyService,
) {

    val log: Logger = org.slf4j.LoggerFactory.getLogger(this.javaClass)

    @GetMapping("/duty/{name}")
    fun retrieveMemberDuty(model: Model, @PathVariable name: String, request: HttpServletRequest): String {
        val member = memberService.findMemberByName(name)
        model.addAttribute("member", MemberDto(member))
        log.info("request: $name, ip: ${request.remoteAddr}")
        return "duty/duty"
    }

    @GetMapping("/duty/edit/{name}")
    fun editDuty(
        @PathVariable name: String,
        model: Model,
        year: Int,
        month: Int,
        @Login loginMember: LoginMember
    ): String {
        val member = memberService.findMemberByName(name)
        model.addAttribute("member", MemberDto(member))

        if (!dutyService.canEdit(loginMember, member)) {
            val message =
                "login member and request duty member does not match: login:$loginMember.id, dutyMemberId:${member.id}"
            log.warn(message)
            throw DutyparkAuthException(message)
        }
        member.department?.let { department ->
            model.addAttribute("offColor", department.offColor.name)
            dutyService.getDutiesAsMap(member, year, month).let {
                model.addAttribute("duties", it)
            }
            val dutyTypes = department.dutyTypes
                .map { DutyTypeDto(it) }
                .sortedBy { it.position }
                .toMutableList()
            dutyTypes.add(0, DutyTypeDto(name = "OFF", position = -1, color = department.offColor.toString()))
            model.addAttribute("dutyTypes", dutyTypes)
            Unit
        }
        addYearMonthData(year, month, model)

        return "duty/duty-edit"
    }

    private fun addYearMonthData(year: Int, month: Int, model: Model) {
        YearMonth.of(year, month).let {
            model.addAttribute("year", year)
            model.addAttribute("month", month)
            model.addAttribute("prevMonth", it.minusMonths(1))
            model.addAttribute("nextMonth", it.plusMonths(1))
        }
    }

}
