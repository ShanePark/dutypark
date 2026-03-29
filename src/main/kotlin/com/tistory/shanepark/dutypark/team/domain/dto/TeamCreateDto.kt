package com.tistory.shanepark.dutypark.team.domain.dto

import jakarta.validation.constraints.NotEmpty
import jakarta.validation.constraints.Size

data class TeamCreateDto(
    @field:Size(min = 2, max = 20, message = "{team.name.length}")
    @field:NotEmpty(message = "{team.name.required}")
    val name: String,
    @field:Size(min = 0, max = 50, message = "{team.description.length}")
    val description: String,
)
