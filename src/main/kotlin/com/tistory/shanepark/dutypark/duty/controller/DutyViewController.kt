package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
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
import org.springframework.web.bind.annotation.RequestParam
import java.time.LocalDate

@Controller
class DutyViewController(
    val memberService: MemberService,
    val dutyService: DutyService,
) {

    val log: Logger = org.slf4j.LoggerFactory.getLogger(this.javaClass)

    @GetMapping("/duty/{name}")
    fun retrieveMemberDuty(
        model: Model, @PathVariable name: String, request: HttpServletRequest,
        @RequestParam(required = false) year: Int?,
        @RequestParam(required = false) month: Int?,
    ): String {
        log.info("request: $name, ip: ${request.remoteAddr}")
        val member = memberService.findMemberByName(name)
        model.addAttribute("member", MemberDto(member))
        model.addAttribute("year", year?.let { it } ?: LocalDate.now().year)
        model.addAttribute("month", month?.let { it } ?: LocalDate.now().monthValue)
        return "duty/duty"
    }

    @GetMapping("/duty/edit")
    fun editDuty(
        @RequestParam memberId: Long,
        @RequestParam year: Int,
        @RequestParam month: Int,
        model: Model,
        @Login loginMember: LoginMember
    ): String {
        val member = memberService.findById(memberId)

        if (!dutyService.canEdit(loginMember, member)) {
            val message =
                "login member and request duty member does not match: login:$loginMember.id, dutyMemberId:${member.id}"
            log.warn(message)
            throw DutyparkAuthException(message)
        }

        model.addAttribute("member", MemberDto(member))
        model.addAttribute("year", year)
        model.addAttribute("month", month)

        return "duty/duty-edit"
    }

}
