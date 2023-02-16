package com.tistory.shanepark.dutypark.admin.controller

import com.fasterxml.jackson.databind.ObjectMapper
import com.tistory.shanepark.dutypark.security.repository.RefreshTokenRepository
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping

@Controller
@RequestMapping("/admin")
class AdminViewController(
    private val refreshTokenRepository: RefreshTokenRepository,
    private val objectMapper: ObjectMapper
) {

    @GetMapping
    fun admin(model: Model): String {
        val refreshTokens = refreshTokenRepository.findAll()
            .map { objectMapper.writeValueAsString(it) }
            .toList()
        model.addAttribute("refreshTokens", refreshTokens)

        return "admin/index"
    }

}
