package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.duty.service.DutyTypeService
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/admin/api/duty-types")
class DutyTypeController(
    private val dutyTypeService: DutyTypeService,
) {

    @PostMapping
    fun addDutyType(@RequestBody @Valid dutyTypeCreateDto: DutyTypeCreateDto): ResponseEntity<Any> {
        dutyTypeService.addDutyType(dutyTypeCreateDto)
        return ResponseEntity.status(HttpStatus.CREATED).build()
    }

    @PatchMapping
    fun updateDutyType(@RequestBody @Valid dutyTypeUpdateDto: DutyTypeUpdateDto): ResponseEntity<Any> {
        dutyTypeService.update(dutyTypeUpdateDto)
        return ResponseEntity.status(HttpStatus.OK).build()
    }

    @PatchMapping("/swap-position")
    fun swapDutyTypePosition(@RequestParam id1: Long, @RequestParam id2: Long): ResponseEntity<Any> {
        dutyTypeService.swapDutyTypePosition(id1, id2)
        return ResponseEntity.ok().build()
    }

    @DeleteMapping("/{id}")
    fun delete(@PathVariable id: Long): ResponseEntity<Any> {
        dutyTypeService.delete(id)
        return ResponseEntity.status(HttpStatus.OK).build()
    }

}
