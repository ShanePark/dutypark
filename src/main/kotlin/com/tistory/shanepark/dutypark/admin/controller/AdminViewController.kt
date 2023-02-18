package com.tistory.shanepark.dutypark.admin.controller

import com.tistory.shanepark.dutypark.security.domain.dto.RefreshTokenDto
import com.tistory.shanepark.dutypark.security.service.AuthService
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping

@Controller
@RequestMapping("/admin")
class AdminViewController(
    private val authService: AuthService,
) {

    @GetMapping
    fun admin(model: Model): String {
        val refreshTokens = authService.findAllRefreshTokens()
            .sortedWith(compareBy<RefreshTokenDto> { it.memberId }
                .thenByDescending { it.lastUsed })

        model.addAttribute("refreshTokens", refreshTokens)
        return "admin/index"
    }

}
