package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus.WAIT
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingTask
import jakarta.annotation.PostConstruct
import jakarta.annotation.PreDestroy
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import org.springframework.transaction.support.TransactionSynchronization
import org.springframework.transaction.support.TransactionSynchronizationManager
import java.time.LocalDateTime
import java.util.*
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

@Component
class ScheduleTimeParsingQueueManager(
    private val worker: ScheduleTimeParsingWorker,
    private val scheduleRepository: ScheduleRepository,
    @param:Value("\${spring.ai.openai.api-key}") private val geminiApiKey: String,
    @param:Value("\${spring.ai.rate-limit.rpm}") private val rpmLimit: Int,
    @param:Value("\${spring.ai.rate-limit.rpd}") private val rpdLimit: Int,
) {
    private val log = logger()
    private val executorService = Executors.newSingleThreadExecutor()
    private val queue = ConcurrentLinkedQueue<ScheduleTimeParsingTask>()
    private val isRunning = AtomicBoolean(false)
    private val isShuttingDown = AtomicBoolean(false)

    private val completedTasks: Queue<LocalDateTime> = ConcurrentLinkedQueue()
    private val completedDailyTasks: Queue<LocalDateTime> = ConcurrentLinkedQueue()

    private var doTask = true

    @PostConstruct
    fun init() {
        val maskedKey = if (geminiApiKey.length > 8)
            "${geminiApiKey.take(4)}...${geminiApiKey.takeLast(4)}"
        else
            "****"
        log.info("GeminiKey: {}", maskedKey)
        if (geminiApiKey.isBlank() || geminiApiKey == "EMPTY") {
            log.info("AI time parsing disabled: Gemini API key is not configured")
            doTask = false
            return
        }

        val allWaitJobs = scheduleRepository.findAllByParsingTimeStatus(WAIT)
        allWaitJobs.forEach { schedule -> addTask(schedule) }
        if (allWaitJobs.isNotEmpty())
            log.info("Pending schedules added to queue: count={}", allWaitJobs.size)

    }

    fun addTask(schedule: Schedule) {
        if (schedule.parsingTimeStatus != WAIT || !doTask || isShuttingDown.get()) return

        val task = ScheduleTimeParsingTask(schedule)
        if (TransactionSynchronizationManager.isSynchronizationActive() &&
            TransactionSynchronizationManager.isActualTransactionActive()
        ) {
            TransactionSynchronizationManager.registerSynchronization(object : TransactionSynchronization {
                override fun afterCommit() {
                    enqueue(task)
                }
            })
            return
        }

        enqueue(task)
    }

    private fun enqueue(task: ScheduleTimeParsingTask) {
        if (isShuttingDown.get()) return
        queue.add(task)
        startWorkIfNeeded()
    }

    private fun startWorkIfNeeded() {
        if (isShuttingDown.get() || queue.isEmpty() || !isRunning.compareAndSet(false, true)) return

        try {
            executorService.execute {
                try {
                    // Briefly batch newly queued tasks before starting the worker.
                    TimeUnit.SECONDS.sleep(10)
                    run()
                } finally {
                    isRunning.set(false)
                    startWorkIfNeeded()
                }
            }
        } catch (e: RejectedExecutionException) {
            isRunning.set(false)
            if (!isShuttingDown.get()) throw e
        }
    }

    private fun run() {
        while (!isShuttingDown.get() && queue.isNotEmpty()) {
            while (!isShuttingDown.get() && shouldWait()) {
                log.info("Waiting for AI API rate limit (RPM/RPD check)")
                TimeUnit.MINUTES.sleep(1)
            }
            if (isShuttingDown.get()) return

            val task = queue.poll() ?: continue
            try {
                if (worker.run(task)) {
                    recordCompletion()
                }
            } catch (e: Exception) {
                log.error("Unexpected schedule time parsing failure: scheduleId={}", task.scheduleId, e)
                // Count conservatively because the failure may have happened after the external AI request.
                recordCompletion()
                if (!isShuttingDown.get() && task.canRetryAfterUnexpectedFailure()) {
                    queue.add(task)
                }
                return
            }
        }
    }

    @PreDestroy
    fun shutdown() {
        isShuttingDown.set(true)
        executorService.shutdownNow()
        if (!executorService.awaitTermination(5, TimeUnit.SECONDS)) {
            log.warn("Schedule time parsing executor did not stop within 5 seconds")
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

    fun queueSize(): Int {
        return queue.size
    }

}
