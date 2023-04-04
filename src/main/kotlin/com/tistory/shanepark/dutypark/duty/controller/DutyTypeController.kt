package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.duty.service.DutyTypeService
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/admin/api/duty-types")
class DutyTypeController(
    private val dutyTypeService: DutyTypeService,
    private val dutyTypeRepository: DutyTypeRepository,
) {

    @DeleteMapping("/{id}")
    fun delete(@PathVariable id: Long) {
        val dutType = dutyTypeRepository.findById(id).orElseThrow()
        dutyTypeService.delete(dutType)
    }

}
