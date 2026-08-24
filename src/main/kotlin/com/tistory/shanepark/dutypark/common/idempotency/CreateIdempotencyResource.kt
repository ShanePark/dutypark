package com.tistory.shanepark.dutypark.common.idempotency

/** Resources whose create endpoints accept an idempotency key. */
enum class CreateIdempotencyResource {
    SCHEDULE,
    TODO,
}
