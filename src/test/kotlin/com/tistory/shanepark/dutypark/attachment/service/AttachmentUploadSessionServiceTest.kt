package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentUploadSessionRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import java.time.Clock
import java.time.Instant
import java.time.ZoneId
import java.util.*

class AttachmentUploadSessionServiceTest {

    private lateinit var service: AttachmentUploadSessionService
    private lateinit var sessionRepository: FakeAttachmentUploadSessionRepository
    private lateinit var permissionEvaluator: AttachmentPermissionEvaluator
    private lateinit var clock: Clock
    private val loginMember = LoginMember(id = 42L, name = "testuser")

    @BeforeEach
    fun setUp() {
        sessionRepository = FakeAttachmentUploadSessionRepository()
        permissionEvaluator = mock()
        clock = Clock.fixed(Instant.parse("2025-03-10T12:00:00Z"), ZoneId.of("UTC"))
        service = AttachmentUploadSessionService(sessionRepository, permissionEvaluator, clock)
    }

    @Test
    fun `createSession should create new session with 24 hour expiration`() {
        val contextType = AttachmentContextType.SCHEDULE
        val expectedExpiration = Instant.parse("2025-03-11T12:00:00Z")

        val result = service.createSession(loginMember, contextType, null)

        assertThat(result.id).isNotNull
        assertThat(result.contextType).isEqualTo(contextType)
        assertThat(result.ownerId).isEqualTo(loginMember.id)
        assertThat(result.targetContextId).isNull()
        assertThat(result.expiresAt).isEqualTo(expectedExpiration)
        assertThat(sessionRepository.savedSessions).hasSize(1)
    }

    @Test
    fun `createSession should preserve targetContextId when provided`() {
        val contextType = AttachmentContextType.SCHEDULE
        val targetContextId = "schedule-123"

        val result = service.createSession(loginMember, contextType, targetContextId)

        assertThat(result.targetContextId).isEqualTo(targetContextId)
    }

    @Test
    fun `findById should return session when exists`() {
        val session = service.createSession(loginMember, AttachmentContextType.SCHEDULE, null)

        val result = service.findById(session.id!!)

        assertThat(result).isNotNull
        assertThat(result?.id).isEqualTo(session.id)
    }

    @Test
    fun `findById should return null when session does not exist`() {
        val sessionId = UUID.randomUUID()

        val result = service.findById(sessionId)

        assertThat(result).isNull()
    }

    @Test
    fun `deleteSession should delete session by id`() {
        val session = service.createSession(loginMember, AttachmentContextType.SCHEDULE, null)
        val sessionId = session.id!!

        service.deleteSession(sessionId)

        assertThat(sessionRepository.sessions).doesNotContainKey(sessionId)
    }

    class FakeAttachmentUploadSessionRepository : AttachmentUploadSessionRepository {
        val sessions = mutableMapOf<UUID, AttachmentUploadSession>()
        val savedSessions = mutableListOf<AttachmentUploadSession>()

        override fun <S : AttachmentUploadSession> save(entity: S): S {
            val sessionId = entity.id ?: UUID.randomUUID()
            val field = AttachmentUploadSession::class.java.superclass.getDeclaredField("id")
            field.isAccessible = true
            if (entity.id == null) {
                field.set(entity, sessionId)
            }
            sessions[sessionId] = entity
            savedSessions.add(entity)
            return entity
        }

        override fun findById(id: UUID): Optional<AttachmentUploadSession> {
            return Optional.ofNullable(sessions[id])
        }

        override fun deleteById(id: UUID) {
            sessions.remove(id)
        }

        override fun findAllByExpiresAtBefore(instant: Instant): List<AttachmentUploadSession> {
            return sessions.values.filter { it.expiresAt.isBefore(instant) }
        }

        override fun <S : AttachmentUploadSession> saveAll(entities: MutableIterable<S>): MutableList<S> {
            throw UnsupportedOperationException()
        }

        override fun findAll(): MutableList<AttachmentUploadSession> {
            return sessions.values.toMutableList()
        }

        override fun findAllById(ids: MutableIterable<UUID>): MutableList<AttachmentUploadSession> {
            throw UnsupportedOperationException()
        }

        override fun count(): Long {
            return sessions.size.toLong()
        }

        override fun delete(entity: AttachmentUploadSession) {
            sessions.remove(entity.id)
        }

        override fun deleteAllById(ids: MutableIterable<UUID>) {
            throw UnsupportedOperationException()
        }

        override fun deleteAll(entities: MutableIterable<AttachmentUploadSession>) {
            throw UnsupportedOperationException()
        }

        override fun deleteAll() {
            sessions.clear()
        }

        override fun existsById(id: UUID): Boolean {
            return sessions.containsKey(id)
        }

        override fun flush() {}

        override fun <S : AttachmentUploadSession> saveAndFlush(entity: S): S {
            throw UnsupportedOperationException()
        }

        override fun <S : AttachmentUploadSession> saveAllAndFlush(entities: MutableIterable<S>): MutableList<S> {
            throw UnsupportedOperationException()
        }

        override fun deleteAllInBatch(entities: MutableIterable<AttachmentUploadSession>) {
            throw UnsupportedOperationException()
        }

        override fun deleteAllByIdInBatch(ids: MutableIterable<UUID>) {
            throw UnsupportedOperationException()
        }

        override fun deleteAllInBatch() {
            throw UnsupportedOperationException()
        }

        override fun getOne(id: UUID): AttachmentUploadSession {
            throw UnsupportedOperationException()
        }

        override fun getById(id: UUID): AttachmentUploadSession {
            throw UnsupportedOperationException()
        }

        override fun getReferenceById(id: UUID): AttachmentUploadSession {
            throw UnsupportedOperationException()
        }

        override fun <S : AttachmentUploadSession> findAll(example: org.springframework.data.domain.Example<S>): MutableList<S> {
            throw UnsupportedOperationException()
        }

        override fun <S : AttachmentUploadSession> findAll(
            example: org.springframework.data.domain.Example<S>,
            sort: org.springframework.data.domain.Sort
        ): MutableList<S> {
            throw UnsupportedOperationException()
        }

        override fun <S : AttachmentUploadSession> findAll(
            example: org.springframework.data.domain.Example<S>,
            pageable: org.springframework.data.domain.Pageable
        ): org.springframework.data.domain.Page<S> {
            throw UnsupportedOperationException()
        }

        override fun <S : AttachmentUploadSession> count(example: org.springframework.data.domain.Example<S>): Long {
            throw UnsupportedOperationException()
        }

        override fun <S : AttachmentUploadSession> exists(example: org.springframework.data.domain.Example<S>): Boolean {
            throw UnsupportedOperationException()
        }

        override fun <S : AttachmentUploadSession, R : Any?> findBy(
            example: org.springframework.data.domain.Example<S>,
            queryFunction: java.util.function.Function<org.springframework.data.repository.query.FluentQuery.FetchableFluentQuery<S>, R>
        ): R {
            throw UnsupportedOperationException()
        }

        override fun findAll(sort: org.springframework.data.domain.Sort): MutableList<AttachmentUploadSession> {
            throw UnsupportedOperationException()
        }

        override fun findAll(pageable: org.springframework.data.domain.Pageable): org.springframework.data.domain.Page<AttachmentUploadSession> {
            throw UnsupportedOperationException()
        }

        override fun <S : AttachmentUploadSession> findOne(example: org.springframework.data.domain.Example<S>): Optional<S> {
            throw UnsupportedOperationException()
        }
    }
}
