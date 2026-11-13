package com.tistory.shanepark.dutypark.member.domain.annotation

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.validation.Constraint
import jakarta.validation.Payload
import jakarta.validation.ReportAsSingleViolation
import jakarta.validation.constraints.Size
import kotlin.reflect.KClass

/**
 * Member name length policy shared by every endpoint that sets a member's name.
 * The default message reuses the signup error code, which is already translated on web and iOS.
 */
@MustBeDocumented
@Constraint(validatedBy = [])
@ReportAsSingleViolation
@Size(min = 1, max = Member.NAME_MAX_LENGTH)
@Target(AnnotationTarget.FIELD)
@Retention(AnnotationRetention.RUNTIME)
annotation class MemberNameLength(
    val message: String = "sso.username.length",
    val groups: Array<KClass<*>> = [],
    val payload: Array<KClass<out Payload>> = [],
)
