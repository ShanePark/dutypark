package com.tistory.shanepark.dutypark.admin.controller

import com.tistory.shanepark.dutypark.common.controller.ViewController
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping

@Controller
@RequestMapping("/admin")
class AdminViewController : ViewController() {

    @GetMapping
    fun admin(model: Model): String {
        return layout(model, "admin/admin-home")
    }

    @GetMapping("/department")
    fun department(model: Model): String {
        return layout(model, "admin/department/department-list")
    }

    @GetMapping("/department/{id}")
    fun departmentDetail(model: Model): String {
        return layout(model, "admin/department/department-detail")
    }


}
