package com.tistory.shanepark.dutypark.common.time

import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.concurrent.atomic.AtomicReference

class AdjustableTestClock private constructor(
    private val currentInstant: AtomicReference<Instant>,
    private val clockZone: ZoneId,
) : Clock() {

    constructor() : this(AtomicReference(Instant.EPOCH), ZoneOffset.UTC)

    override fun getZone(): ZoneId = clockZone

    override fun withZone(zone: ZoneId): Clock = AdjustableTestClock(currentInstant, zone)

    override fun instant(): Instant = currentInstant.get()

    fun setDate(date: LocalDate, zone: ZoneId) {
        currentInstant.set(date.atStartOfDay(zone).toInstant())
    }
}
