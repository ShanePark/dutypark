package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.member.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.member.service.MemberService
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.ResponseBody

@Controller
class MemberController(
    val memberService: MemberService
) {

    @GetMapping("/")
    fun index(model: Model): String {
        model.addAttribute("members", memberService.findAll())
        return "index"
    }

    @PostMapping("/member/authenticate")
    @ResponseBody
    fun authenticate(
        @RequestBody login: LoginDto,
    ): ResponseEntity<Boolean> {
        return if (memberService.authenticate(login)) {
            ResponseEntity.ok(true)
        } else {
            ResponseEntity.status(401).body(false)
        }
    }
}
