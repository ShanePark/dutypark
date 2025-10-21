package com.tistory.shanepark.dutypark.attachment.repository

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager
import java.util.UUID

@DataJpaTest
class AttachmentRepositoryTest {

    @Autowired
    private lateinit var repository: AttachmentRepository

    @Autowired
    private lateinit var entityManager: TestEntityManager

    private lateinit var scheduleId1: String
    private lateinit var scheduleId2: String
    private lateinit var scheduleId3: String

    @BeforeEach
    fun setUp() {
        scheduleId1 = UUID.randomUUID().toString()
        scheduleId2 = UUID.randomUUID().toString()
        scheduleId3 = UUID.randomUUID().toString()

        val attachment1 = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = scheduleId1,
            originalFilename = "file1.png",
            storedFilename = "${UUID.randomUUID()}.png",
            contentType = "image/png",
            size = 1000L,
            storagePath = "storage/SCHEDULE/$scheduleId1/",
            orderIndex = 0,
            createdBy = 1L
        )

        val attachment2 = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = scheduleId1,
            originalFilename = "file2.png",
            storedFilename = "${UUID.randomUUID()}.png",
            contentType = "image/png",
            size = 2000L,
            storagePath = "storage/SCHEDULE/$scheduleId1/",
            orderIndex = 1,
            createdBy = 1L
        )

        val attachment3 = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = scheduleId2,
            originalFilename = "file3.pdf",
            storedFilename = "${UUID.randomUUID()}.pdf",
            contentType = "application/pdf",
            size = 3000L,
            storagePath = "storage/SCHEDULE/$scheduleId2/",
            orderIndex = 0,
            createdBy = 2L
        )

        val attachment4 = Attachment(
            contextType = AttachmentContextType.TODO,
            contextId = scheduleId3,
            originalFilename = "file4.jpg",
            storedFilename = "${UUID.randomUUID()}.jpg",
            contentType = "image/jpeg",
            size = 4000L,
            storagePath = "storage/TODO/$scheduleId3/",
            orderIndex = 0,
            createdBy = 3L
        )

        repository.saveAll(listOf(attachment1, attachment2, attachment3, attachment4))
        entityManager.flush()
        entityManager.clear()
    }

    @Test
    fun `should find attachments by contextType and contextId ordered by orderIndex`() {
        val result = repository.findAllByContextTypeAndContextIdOrderByOrderIndexAsc(
            AttachmentContextType.SCHEDULE,
            scheduleId1
        )

        assertThat(result).hasSize(2)
        assertThat(result[0].originalFilename).isEqualTo("file1.png")
        assertThat(result[0].orderIndex).isEqualTo(0)
        assertThat(result[1].originalFilename).isEqualTo("file2.png")
        assertThat(result[1].orderIndex).isEqualTo(1)
    }

    @Test
    fun `should find attachments by contextType and multiple contextIds in single query`() {
        val result = repository.findAllByContextTypeAndContextIdIn(
            AttachmentContextType.SCHEDULE,
            listOf(scheduleId1, scheduleId2)
        )

        assertThat(result).hasSize(3)
        assertThat(result.map { it.originalFilename })
            .containsExactlyInAnyOrder("file1.png", "file2.png", "file3.pdf")
    }

    @Test
    fun `should not find attachments with different contextType`() {
        val result = repository.findAllByContextTypeAndContextIdIn(
            AttachmentContextType.TODO,
            listOf(scheduleId1, scheduleId2)
        )

        assertThat(result).isEmpty()
    }

    @Test
    fun `should find attachments by uploadSessionId`() {
        val sessionId = UUID.randomUUID()
        val attachment = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = null,
            originalFilename = "temp.png",
            storedFilename = "${UUID.randomUUID()}.png",
            contentType = "image/png",
            size = 5000L,
            storagePath = "storage/_tmp/$sessionId/",
            orderIndex = 0,
            createdBy = 1L
        )
        attachment.uploadSessionId = sessionId
        repository.save(attachment)
        entityManager.flush()
        entityManager.clear()

        val result = repository.findAllByUploadSessionId(sessionId)

        assertThat(result).hasSize(1)
        assertThat(result[0].originalFilename).isEqualTo("temp.png")
        assertThat(result[0].contextId).isNull()
    }
}
