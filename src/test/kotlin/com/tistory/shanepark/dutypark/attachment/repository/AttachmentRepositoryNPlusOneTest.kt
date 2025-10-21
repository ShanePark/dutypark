package com.tistory.shanepark.dutypark.attachment.repository

import com.tistory.shanepark.dutypark.attachment.domain.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.AttachmentContextType
import org.assertj.core.api.Assertions.assertThat
import org.hibernate.SessionFactory
import org.hibernate.stat.Statistics
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager
import java.util.UUID

@DataJpaTest
class AttachmentRepositoryNPlusOneTest {

    @Autowired
    private lateinit var repository: AttachmentRepository

    @Autowired
    private lateinit var entityManager: TestEntityManager

    private lateinit var statistics: Statistics

    @BeforeEach
    fun setUp() {
        val sessionFactory = entityManager.entityManager.entityManagerFactory.unwrap(SessionFactory::class.java)
        statistics = sessionFactory.statistics
        statistics.isStatisticsEnabled = true
        statistics.clear()

        val scheduleIds = (1..10).map { UUID.randomUUID().toString() }

        scheduleIds.forEach { scheduleId ->
            repeat(3) { index ->
                val attachment = Attachment(
                    contextType = AttachmentContextType.SCHEDULE,
                    contextId = scheduleId,
                    originalFilename = "file-$scheduleId-$index.png",
                    storedFilename = "${UUID.randomUUID()}.png",
                    contentType = "image/png",
                    size = 1000L * (index + 1),
                    storagePath = "storage/SCHEDULE/$scheduleId/",
                    orderIndex = index,
                    createdBy = 1L
                )
                repository.save(attachment)
            }
        }

        entityManager.flush()
        entityManager.clear()
        statistics.clear()
    }

    @Test
    fun `should fetch attachments for multiple contexts in single query without N+1`() {
        val scheduleIds = repository.findAll()
            .map { it.contextId!! }
            .distinct()
            .take(5)

        statistics.clear()

        val attachments = repository.findAllByContextTypeAndContextIdIn(
            AttachmentContextType.SCHEDULE,
            scheduleIds
        )

        val queryCount = statistics.queryExecutionCount

        assertThat(attachments).hasSizeGreaterThanOrEqualTo(15)
        assertThat(queryCount).isEqualTo(1)

        val groupedByContext = attachments.groupBy { it.contextId }
        assertThat(groupedByContext).hasSize(5)
        groupedByContext.values.forEach { contextAttachments ->
            assertThat(contextAttachments).hasSize(3)
        }
    }

    @Test
    fun `should avoid N+1 when accessing attachment properties`() {
        val scheduleIds = repository.findAll()
            .map { it.contextId!! }
            .distinct()
            .take(3)

        statistics.clear()

        val attachments = repository.findAllByContextTypeAndContextIdIn(
            AttachmentContextType.SCHEDULE,
            scheduleIds
        )

        val initialQueryCount = statistics.queryExecutionCount

        attachments.forEach {
            it.originalFilename
            it.contentType
            it.size
            it.orderIndex
        }

        val finalQueryCount = statistics.queryExecutionCount

        assertThat(initialQueryCount).isEqualTo(1)
        assertThat(finalQueryCount).isEqualTo(1)
    }
}
