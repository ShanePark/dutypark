package com.tistory.shanepark.dutypark.duty.batch.domain

class DutyBatchTemplateDto(dutyTypeTemplate: DutyBatchTemplate) {
    val name: String = dutyTypeTemplate.name
    val label: String = dutyTypeTemplate.label
    val fileExtensions: List<String> = dutyTypeTemplate.supportedFileExtensions
}
