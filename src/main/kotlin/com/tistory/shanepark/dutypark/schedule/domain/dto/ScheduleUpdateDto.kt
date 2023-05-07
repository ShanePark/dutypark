package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.fasterxml.jackson.annotation.JsonIgnore
import com.tistory.shanepark.dutypark.common.domain.dto.constraint.CreateDtoConstraint
import com.tistory.shanepark.dutypark.common.domain.dto.constraint.UpdateDtoConstraint
import jakarta.validation.constraints.AssertTrue
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Null
import org.hibernate.validator.constraints.Length
import java.time.LocalDateTime
import java.util.*

data class ScheduleUpdateDto(
    @field:NotNull(groups = [UpdateDtoConstraint::class])
    @field:Null(groups = [CreateDtoConstraint::class])
    val id: UUID? = null,
    val memberId: Long,
    @field:Length(max = 30, groups = [CreateDtoConstraint::class, UpdateDtoConstraint::class])
    @field:NotBlank(groups = [CreateDtoConstraint::class, UpdateDtoConstraint::class])
    val content: String,
    val startDateTime: LocalDateTime,
    val endDateTime: LocalDateTime,
) {

    @AssertTrue(message = "StartDateTime must be before or equal to EndDateTime")
    @JsonIgnore
    fun isDateRangeValid(): Boolean {
        return !startDateTime.isAfter(endDateTime)
    }

}
