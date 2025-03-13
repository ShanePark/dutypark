package com.tistory.shanepark.dutypark.department.controller

import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.department.domain.dto.MyTeamSummary
import com.tistory.shanepark.dutypark.department.service.DepartmentService
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyByShift
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.web.bind.annotation.*
import java.time.LocalDate
import java.time.YearMonth

@RestController
@RequestMapping("/api/departments")
class DepartmentController(
    private val departmentService: DepartmentService,
) {

    @GetMapping("/{id}")
    fun findById(@PathVariable id: Long): DepartmentDto {
        return departmentService.findByIdWithDutyTypes(id)
    }

    @GetMapping("/my")
    fun getMyTeamInfo(
        @Login loginMember: LoginMember,
        @RequestParam year: Int,
        @RequestParam month: Int,
    ): MyTeamSummary {
        return departmentService.myTeamSummary(
            loginMember = loginMember,
            yearMonth = YearMonth.of(year, month),
        )
    }

    @GetMapping("/shift")
    fun shift(
        @Login loginMember: LoginMember,
        @RequestParam year: Int,
        @RequestParam month: Int,
        @RequestParam day: Int,
    ): List<DutyByShift> {
        return departmentService.loadShift(loginMember = loginMember, localDate = LocalDate.of(year, month, day))
    }

}
