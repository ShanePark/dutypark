package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.common.controller.ViewController
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping

@Controller
class MemberViewController(
    val memberService: MemberService
) : ViewController() {

    @GetMapping("/")
    fun dashboard(
        @Login(required = false) loginMember: LoginMember?,
        model: Model
    ): String {
        model.addAttribute("member", loginMember)
        return layout(model, "dashboard")
    }

    @GetMapping("/member")
    fun memberPage(@Login loginMember: LoginMember, model: Model): String {
        val member = memberService.findById(loginMember.id)
        model.addAttribute("member", member)
        return layout(model, "member/member")
    }

    @GetMapping("/team")
    fun myTeamPage(model: Model): String {
        return layout(menu = "team/myteam", model = model)
    }

}
