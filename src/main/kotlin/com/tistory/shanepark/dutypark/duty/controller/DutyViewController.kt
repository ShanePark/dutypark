package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.common.controller.ViewController
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.slf4j.Logger
import org.slf4j.LoggerFactory
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
    val log: Logger = LoggerFactory.getLogger(this.javaClass)

    @GetMapping("/duty/{id}")
    fun retrieveMemberDuty(
        @Login(required = false) loginMember: LoginMember?,
        model: Model, @PathVariable id: Long,
        @RequestParam(required = false) year: Int?,
        @RequestParam(required = false) month: Int?,
        @RequestParam(required = false) day: Int?,
    ): String {
        val member = memberService.findById(id)

        model.addAttribute("visible", friendService.isVisible(loginMember, id))
        model.addAttribute("member", member)
        model.addAttribute("year", year ?: LocalDate.now().year)
        model.addAttribute("month", month ?: LocalDate.now().monthValue)
        model.addAttribute("day", day)

        return layout(model, "duty/duty")
    }

}
