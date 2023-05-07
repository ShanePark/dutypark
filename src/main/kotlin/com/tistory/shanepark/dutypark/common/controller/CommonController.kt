package com.tistory.shanepark.dutypark.common.controller

import org.springframework.stereotype.Controller
import org.springframework.web.bind.annotation.GetMapping

@Controller
class CommonController {

    @GetMapping("/docs")
    fun docs(): String {
        return "forward:/docs/index.html"
    }
}
