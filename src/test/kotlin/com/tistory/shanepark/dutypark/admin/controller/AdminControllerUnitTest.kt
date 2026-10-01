package com.tistory.shanepark.dutypark.admin.controller

import com.tistory.shanepark.dutypark.admin.service.AdminService
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify

class AdminControllerUnitTest {

    @Test
    fun `member suspension passes authenticated admin to service`() {
        val adminService = mock<AdminService>()
        val controller = AdminController(
            refreshTokenService = mock<RefreshTokenService>(),
            adminService = adminService,
        )
        val actor = LoginMember(id = 99L, name = "Admin Actor", isAdmin = true)

        controller.suspendMember(actor, 7L)

        verify(adminService).suspendMember(7L, actor)
    }
}
