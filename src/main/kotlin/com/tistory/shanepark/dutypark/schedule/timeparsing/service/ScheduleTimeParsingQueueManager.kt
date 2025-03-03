package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus.WAIT
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingTask
import jakarta.annotation.PostConstruct
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import java.time.LocalDateTime
import java.util.*
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

@Component
class ScheduleTimeParsingQueueManager(
    private val worker: ScheduleTimeParsingWorker,
    private val scheduleRepository: ScheduleRepository,
) {
    private val log = LoggerFactory.getLogger(ScheduleTimeParsingQueueManager::class.java)
    private val executorService = Executors.newSingleThreadExecutor()
    private val queue = ConcurrentLinkedQueue<ScheduleTimeParsingTask>()
    private val isRunning = AtomicBoolean(false)

    private val completedTasks: Queue<LocalDateTime> = ConcurrentLinkedQueue()
    private val completedDailyTasks: Queue<LocalDateTime> = ConcurrentLinkedQueue()

    private val rpmLimit = 30
    private val rpdLimit = 1500

    @PostConstruct
    fun init() {
        val allWaitJobs = scheduleRepository.findAllByParsingTimeStatus(WAIT)
        allWaitJobs.forEach { schedule -> addTask(schedule) }
        log.info("${allWaitJobs.size} schedules are added to the queue.")
    }

    fun addTask(schedule: Schedule) {
        if (schedule.parsingTimeStatus != WAIT)
            return
        queue.add(ScheduleTimeParsingTask(schedule.id))
        startWorkIfNeeded()
    }

    private fun startWorkIfNeeded() {
        if (queue.isEmpty() || !isRunning.compareAndSet(false, true)) return

        executorService.execute {
            try {
                // wait enough til schedule transaction is committed
                TimeUnit.SECONDS.sleep(10)
                run()
            } finally {
                isRunning.set(false)
            }
        }
    }

    private fun run() {
        while (queue.isNotEmpty()) {
            while (shouldWait()) {
                log.info("Waiting for API rate limit...")
                TimeUnit.MINUTES.sleep(1)
            }

            val task = queue.poll() ?: continue
            worker.run(task)
            recordCompletion()
        }
    }

    private fun shouldWait(): Boolean {
        val now = LocalDateTime.now()

        completedTasks.peek()?.let {
            if (completedTasks.size >= rpmLimit && it.isAfter(now.minusMinutes(1))) {
                return true
            }
        }

        completedDailyTasks.peek()?.let {
            if (completedDailyTasks.size >= rpdLimit && it.isAfter(now.minusDays(1))) {
                return true
            }
        }

        return false
    }

    private fun recordCompletion() {
        val now = LocalDateTime.now()

        completedTasks.add(now)
        while (completedTasks.size > rpmLimit) {
            completedTasks.poll()
        }

        completedDailyTasks.add(now)
        while (completedDailyTasks.size > rpdLimit) {
            completedDailyTasks.poll()
        }
    }

}
