package com.tistory.shanepark.dutypark.admin.controller

import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping

@Controller
@RequestMapping("/admin")
class AdminViewController {

    @GetMapping
    fun admin(model: Model): String {
        return "admin/index"
    }

}
