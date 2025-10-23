package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.common.config.StorageProperties
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.nio.file.Files
import java.time.LocalDateTime

class ScheduleAttachmentDeletionIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var scheduleService: ScheduleService

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Autowired
    lateinit var attachmentRepository: AttachmentRepository

    @Autowired
    lateinit var pathResolver: StoragePathResolver

    @Test
    fun `deleting schedule should cascade delete attachments from DB and disk`() {
        val member = TestData.member
        val loginMember = loginMember(member)

        val schedule = scheduleRepository.save(
            Schedule(
                member = member,
                content = "Schedule with attachments",
                description = "Test schedule",
                startDateTime = LocalDateTime.of(2025, 10, 22, 10, 0),
                endDateTime = LocalDateTime.of(2025, 10, 22, 11, 0),
                position = 0
            )
        )
        em.flush()

        val contextId = schedule.id.toString()
        val contextDir = pathResolver.resolveContextDirectory(AttachmentContextType.SCHEDULE, contextId)
        Files.createDirectories(contextDir)

        val attachment1 = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = contextId,
                uploadSessionId = null,
                originalFilename = "test1.png",
                storedFilename = "stored1.png",
                contentType = "image/png",
                size = 1024,
                storagePath = contextDir.toString(),
                createdBy = member.id!!,
                orderIndex = 0
            )
        )

        val attachment2 = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = contextId,
                uploadSessionId = null,
                originalFilename = "test2.jpg",
                storedFilename = "stored2.jpg",
                contentType = "image/jpeg",
                size = 2048,
                storagePath = contextDir.toString(),
                createdBy = member.id!!,
                orderIndex = 1,
                thumbnailFilename = "thumb-stored2.png",
                thumbnailContentType = "image/png",
                thumbnailSize = 512
            )
        )

        val file1Path = contextDir.resolve(attachment1.storedFilename)
        val file2Path = contextDir.resolve(attachment2.storedFilename)
        val thumbnail2Path = contextDir.resolve(attachment2.thumbnailFilename!!)

        Files.writeString(file1Path, "file1 content")
        Files.writeString(file2Path, "file2 content")
        Files.writeString(thumbnail2Path, "thumbnail content")

        em.flush()
        em.clear()

        assertThat(Files.exists(file1Path)).isTrue
        assertThat(Files.exists(file2Path)).isTrue
        assertThat(Files.exists(thumbnail2Path)).isTrue
        assertThat(attachmentRepository.findById(attachment1.id)).isPresent
        assertThat(attachmentRepository.findById(attachment2.id)).isPresent

        scheduleService.deleteSchedule(loginMember, schedule.id)
        em.flush()
        em.clear()

        assertThat(scheduleRepository.findById(schedule.id)).isEmpty
        assertThat(attachmentRepository.findById(attachment1.id)).isEmpty
        assertThat(attachmentRepository.findById(attachment2.id)).isEmpty

        assertThat(Files.exists(file1Path)).isFalse
        assertThat(Files.exists(file2Path)).isFalse
        assertThat(Files.exists(thumbnail2Path)).isFalse
        assertThat(Files.exists(contextDir)).isFalse
    }

    @Test
    fun `deleting schedule without attachments should complete successfully`() {
        val member = TestData.member
        val loginMember = loginMember(member)

        val schedule = scheduleRepository.save(
            Schedule(
                member = member,
                content = "Schedule without attachments",
                description = "Test schedule",
                startDateTime = LocalDateTime.of(2025, 10, 22, 14, 0),
                endDateTime = LocalDateTime.of(2025, 10, 22, 15, 0),
                position = 0
            )
        )
        em.flush()
        em.clear()

        scheduleService.deleteSchedule(loginMember, schedule.id)
        em.flush()
        em.clear()

        assertThat(scheduleRepository.findById(schedule.id)).isEmpty
    }
}
