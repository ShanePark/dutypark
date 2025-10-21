package com.tistory.shanepark.dutypark.common.config

import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.util.unit.DataSize
import jakarta.validation.constraints.NotEmpty
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Positive

@ConfigurationProperties(prefix = "dutypark.storage")
data class StorageProperties(
    @field:NotEmpty
    val root: String,

    @field:NotNull
    val maxFileSize: DataSize,

    @field:NotEmpty
    val blacklistExt: List<String>,

    val thumbnail: ThumbnailProperties,

    @field:Positive
    val sessionExpirationHours: Long
) {
    data class ThumbnailProperties(
        @field:Positive
        val maxSide: Int
    )
}
