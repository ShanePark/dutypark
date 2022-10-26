package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.MemoDto
import com.tistory.shanepark.dutypark.duty.service.DutyService
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/duty")
class DutyApiController(
    private val dutyService: DutyService
) {

    @PutMapping("update")
    @SlackNotification
    fun updateDuty(@RequestBody dutyUpdateDto: DutyUpdateDto): ResponseEntity<Boolean> {
        dutyService.update(dutyUpdateDto)
        return ResponseEntity.ok(true)
    }

    @PutMapping("memo")
    @SlackNotification
    fun updateMemo(@RequestBody memoDto: MemoDto): ResponseEntity<Boolean> {
        dutyService.updateMemo(memoDto)
        return ResponseEntity.ok(true)
    }

}
