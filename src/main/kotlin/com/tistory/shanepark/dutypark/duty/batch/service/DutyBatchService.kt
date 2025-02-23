package com.tistory.shanepark.dutypark.duty.batch.service

import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTeamResult
import org.springframework.web.multipart.MultipartFile
import java.time.YearMonth

interface DutyBatchService {
    fun batchUploadMember(file: MultipartFile, memberId: Long, yearMonth: YearMonth): DutyBatchResult
    fun batchUploadDepartment(file: MultipartFile, departmentId: Long, yearMonth: YearMonth): DutyBatchTeamResult
}
