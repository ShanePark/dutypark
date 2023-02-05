package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping

@Controller
class MemberViewController(
    val memberService: MemberService
) {

    @GetMapping("/")
    fun index(model: Model): String {
        model.addAttribute("members", memberService.findAll())
        return "index"
    }

    @GetMapping("/member")
    fun memberPage(@Login loginMember: LoginMember, model: Model): String {
        model.addAttribute("member", loginMember)
        return "member/member"
    }

    @GetMapping("/member/d-day")
    fun dDayPage(@Login loginMember: LoginMember, model: Model): String {
        model.addAttribute("member", loginMember)
        return "member/d-day"
    }

}
