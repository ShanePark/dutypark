package com.tistory.shanepark.dutypark.duty.batch.domain

import com.tistory.shanepark.dutypark.duty.batch.service.DutyBatchService
import com.tistory.shanepark.dutypark.duty.batch.service.DutyBatchSungsimService

enum class DutyBatchTemplate(val label: String, val batchServiceClass: Class<out DutyBatchService>) {
    SUNGSIM_CAKE("성심당 케익부띠끄", DutyBatchSungsimService::class.java),

}
