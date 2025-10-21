package com.tistory.shanepark.dutypark.attachment.repository

import com.tistory.shanepark.dutypark.attachment.domain.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.domain.AttachmentUploadSession
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager
import java.time.Instant
import java.time.temporal.ChronoUnit

@DataJpaTest
class AttachmentUploadSessionRepositoryTest {

    @Autowired
    private lateinit var repository: AttachmentUploadSessionRepository

    @Autowired
    private lateinit var entityManager: TestEntityManager

    @BeforeEach
    fun setUp() {
        val now = Instant.now()

        val expiredSession1 = AttachmentUploadSession(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = null,
            ownerId = 1L,
            expiresAt = now.minus(2, ChronoUnit.HOURS)
        )

        val expiredSession2 = AttachmentUploadSession(
            contextType = AttachmentContextType.TODO,
            targetContextId = "todo-123",
            ownerId = 2L,
            expiresAt = now.minus(1, ChronoUnit.HOURS)
        )

        val activeSession = AttachmentUploadSession(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = null,
            ownerId = 3L,
            expiresAt = now.plus(24, ChronoUnit.HOURS)
        )

        repository.saveAll(listOf(expiredSession1, expiredSession2, activeSession))
        entityManager.flush()
        entityManager.clear()
    }

    @Test
    fun `should find expired sessions`() {
        val now = Instant.now()
        val expiredSessions = repository.findAllByExpiresAtBefore(now)

        assertThat(expiredSessions).hasSize(2)
        assertThat(expiredSessions.all { it.expiresAt.isBefore(now) }).isTrue()
    }

    @Test
    fun `should not find active sessions when querying expired`() {
        val now = Instant.now()
        val expiredSessions = repository.findAllByExpiresAtBefore(now)

        assertThat(expiredSessions.none { it.expiresAt.isAfter(now) }).isTrue()
    }

    @Test
    fun `should find no sessions when all are active`() {
        repository.deleteAll()
        entityManager.flush()

        val futureSession = AttachmentUploadSession(
            contextType = AttachmentContextType.PROFILE,
            targetContextId = null,
            ownerId = 1L,
            expiresAt = Instant.now().plus(1, ChronoUnit.DAYS)
        )
        repository.save(futureSession)
        entityManager.flush()
        entityManager.clear()

        val expiredSessions = repository.findAllByExpiresAtBefore(Instant.now())

        assertThat(expiredSessions).isEmpty()
    }
}
