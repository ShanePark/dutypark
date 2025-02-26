package com.tistory.shanepark.dutypark.dashboard.controller

import com.tistory.shanepark.dutypark.dashboard.domain.DashboardDepartment
import com.tistory.shanepark.dutypark.dashboard.domain.DashboardFriendInfo
import com.tistory.shanepark.dutypark.dashboard.domain.DashboardMyDetail
import com.tistory.shanepark.dutypark.dashboard.service.DashboardService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("api/dashboard")
class DashboardController(
    private val dashboardService: DashboardService,
) {

    @GetMapping("my")
    fun myDashboard(@Login loginMember: LoginMember): DashboardMyDetail {
        return dashboardService.my(loginMember)
    }

    @GetMapping("friends")
    fun friendDashboard(@Login loginMember: LoginMember): DashboardFriendInfo {
        return dashboardService.friend(loginMember)
    }

    @GetMapping("department")
    fun departmentDashboard(@Login loginMember: LoginMember): DashboardDepartment {
        return dashboardService.department(loginMember)
    }

}
