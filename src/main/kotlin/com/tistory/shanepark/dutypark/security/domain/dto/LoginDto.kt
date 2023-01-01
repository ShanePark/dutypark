package com.tistory.shanepark.dutypark.security.domain.dto

import jakarta.validation.constraints.NotBlank
import org.hibernate.validator.constraints.Length

data class LoginDto(

    @field:NotBlank
    val email: String,

    @field:NotBlank
    @field:Length(max = 20)
    val password: String,

)
