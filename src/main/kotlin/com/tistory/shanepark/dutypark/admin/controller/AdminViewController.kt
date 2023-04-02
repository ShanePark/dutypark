package com.tistory.shanepark.dutypark.admin.controller

import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping

@Controller
@RequestMapping("/admin")
class AdminViewController {

    val adminLayout = "admin/admin-layout"

    @GetMapping
    fun admin(model: Model): String {
        addContent(model, "admin-home")
        return adminLayout
    }

    @GetMapping("/department")
    fun adminMenu(model: Model): String {
        addContent(model, "department/department-list")
        return adminLayout
    }

    private fun addContent(model: Model, menu: String) {
        model.addAttribute("content", "admin/${menu}");
    }

}
