package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.common.controller.ViewController
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.service.FriendService
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
    val friendService: FriendService,
) : ViewController() {
    val log: Logger = org.slf4j.LoggerFactory.getLogger(this.javaClass)

    @GetMapping("/duty/{name}")
    fun retrieveMemberDuty(
        @Login(required = false) loginMember: LoginMember?,
        model: Model, @PathVariable name: String, request: HttpServletRequest,
        @RequestParam(required = false) year: Int?,
        @RequestParam(required = false) month: Int?,
    ): String {
        val member = memberService.findMemberByName(name)

        val visible = friendService.isVisible(loginMember, member)
        model.addAttribute("visible", visible)

        model.addAttribute("member", MemberDto.of(member))
        model.addAttribute("year", year ?: LocalDate.now().year)
        model.addAttribute("month", month ?: LocalDate.now().monthValue)
        return layout(model, "duty/duty")
    }

}
