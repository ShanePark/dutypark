package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.duty.service.DutyTypeService
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/admin/api/duty-types")
class DutyTypeController(
    private val dutyTypeService: DutyTypeService,
) {

    @PostMapping
    fun addDutyType(@RequestBody @Valid dutyTypeCreateDto: DutyTypeCreateDto) {
        dutyTypeService.addDutyType(dutyTypeCreateDto)
    }

    @PatchMapping
    fun updateDutyType(@RequestBody @Valid dutyTypeUpdateDto: DutyTypeUpdateDto) {
        dutyTypeService.update(dutyTypeUpdateDto)
    }

    @PatchMapping("/swap-position")
    fun swapDutyTypePosition(@RequestParam id1: Long, @RequestParam id2: Long) {
        dutyTypeService.swapDutyTypePosition(id1, id2)
    }

    @DeleteMapping("/{id}")
    fun delete(@PathVariable id: Long) {
        dutyTypeService.delete(id)
    }

}
