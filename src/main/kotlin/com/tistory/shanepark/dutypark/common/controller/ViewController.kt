package com.tistory.shanepark.dutypark.common.controller

import org.springframework.ui.Model

open class ViewController {

    protected fun layout(model: Model, menu: String): String {
        model.addAttribute("content", menu);
        return "layout/layout"
    }

}
