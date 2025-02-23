package com.tistory.shanepark.dutypark.duty.batch.domain

import com.tistory.shanepark.dutypark.duty.batch.exceptions.NotSupportedFileException
import com.tistory.shanepark.dutypark.duty.batch.service.DutyBatchService
import com.tistory.shanepark.dutypark.duty.batch.service.DutyBatchSungsimService
import org.springframework.web.multipart.MultipartFile

enum class DutyBatchTemplate(
    val label: String,
    val batchServiceClass: Class<out DutyBatchService>,
    val supportedFileExtensions: List<String>
) {
    SUNGSIM_CAKE("성심당 케익부띠끄", DutyBatchSungsimService::class.java, listOf(".xls", ".xlsx")),
    ;

    fun checkSupportedFile(file: MultipartFile) {
        val extension = file.originalFilename
            ?.substringAfterLast(".", "")
            ?.lowercase()
            ?.let { ".$it" }
            ?: throw IllegalArgumentException("파일에 확장자가 없습니다.")

        require(extension in supportedFileExtensions) {
            throw NotSupportedFileException("지원하지 않는 파일 형식입니다: ${extension},  지원하는 파일 형식: $supportedFileExtensions")
        }
    }

}
