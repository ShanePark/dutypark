package com.tistory.shanepark.dutypark.attachment.repository

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager
import java.util.UUID

@DataJpaTest
class AttachmentRepositoryTest {

    @Autowired
    private lateinit var repository: AttachmentRepository

    @Autowired
    private lateinit var entityManager: TestEntityManager

    private lateinit var scheduleId: String

    @BeforeEach
    fun setUp() {
        scheduleId = UUID.randomUUID().toString()

        val attachment1 = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = scheduleId,
            originalFilename = "file1.png",
            storedFilename = "${UUID.randomUUID()}.png",
            contentType = "image/png",
            size = 1000L,
            storagePath = "storage/SCHEDULE/$scheduleId/",
            orderIndex = 0,
            createdBy = 1L
        )

        val attachment2 = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = scheduleId,
            originalFilename = "file2.png",
            storedFilename = "${UUID.randomUUID()}.png",
            contentType = "image/png",
            size = 2000L,
            storagePath = "storage/SCHEDULE/$scheduleId/",
            orderIndex = 1,
            createdBy = 1L
        )

        repository.saveAll(listOf(attachment1, attachment2))
        entityManager.flush()
        entityManager.clear()
    }

    @Test
    fun `should find attachments by contextType and contextId ordered by orderIndex`() {
        val result = repository.findAllByContextTypeAndContextIdOrderByOrderIndexAsc(
            AttachmentContextType.SCHEDULE,
            scheduleId
        )

        assertThat(result).hasSize(2)
        assertThat(result[0].originalFilename).isEqualTo("file1.png")
        assertThat(result[0].orderIndex).isEqualTo(0)
        assertThat(result[1].originalFilename).isEqualTo("file2.png")
        assertThat(result[1].orderIndex).isEqualTo(1)
    }
}
