package com.tistory.shanepark.dutypark.admin.controller

import com.tistory.shanepark.dutypark.common.controller.ViewController
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping

@Controller
@RequestMapping("/admin")
class AdminViewController : ViewController() {

    @GetMapping
    fun admin(model: Model): String {
        return layout(model, "admin/admin-home")
    }

    @GetMapping("/team")
    fun team(model: Model): String {
        return layout(model, "admin/team/team-list")
    }

    @GetMapping("/team/{id}")
    fun teamDetail(model: Model, @PathVariable id: Long): String {
        model.addAttribute("teamId", id)
        return layout(model, "admin/team/team-detail")
    }

}
