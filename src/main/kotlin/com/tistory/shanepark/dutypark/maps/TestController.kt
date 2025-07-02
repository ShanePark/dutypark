package com.tistory.shanepark.dutypark.maps

import org.springframework.stereotype.Controller
import org.springframework.web.bind.annotation.GetMapping

@Controller
class TestController {

    @GetMapping("test")
    fun test(): String {
        return "test";
    }
}
