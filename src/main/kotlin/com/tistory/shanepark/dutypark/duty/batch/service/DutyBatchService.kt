package com.tistory.shanepark.dutypark.duty.batch.service

import com.tistory.shanepark.dutypark.duty.batch.domain.BatchParseResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchResult
import org.springframework.web.multipart.MultipartFile
import java.time.YearMonth

interface DutyBatchService {
    fun batchUpload(file: MultipartFile, memberId: Long, yearMonth: YearMonth): DutyBatchResult
}
