package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.member.service.MemberService
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping

@Controller
class MemberController(
    val memberService: MemberService
) {

    @GetMapping("/")
    fun index(model: Model): String {
        model.addAttribute("members", memberService.findAll())
        return "index"
    }
}
