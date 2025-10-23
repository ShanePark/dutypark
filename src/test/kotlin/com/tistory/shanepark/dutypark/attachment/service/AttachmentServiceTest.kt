package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.domain.enums.ThumbnailStatus
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.context.ApplicationEventPublisher
import org.springframework.mock.web.MockMultipartFile
import java.nio.file.Files
import java.nio.file.Path
import java.time.Clock
import java.time.Instant
import java.time.ZoneId
import java.util.*

class AttachmentServiceTest {

    private lateinit var service: AttachmentService
    private lateinit var attachmentRepository: FakeAttachmentRepository
    private lateinit var validationService: AttachmentValidationService
    private lateinit var pathResolver: StoragePathResolver
    private lateinit var fileSystemService: FileSystemService
    private lateinit var fakeFileSpy: FakeFileSpy
    private lateinit var thumbnailService: ThumbnailService
    private lateinit var fakeThumbnailSpy: FakeThumbnailSpy
    private lateinit var permissionEvaluator: AttachmentPermissionEvaluator
    private lateinit var sessionService: AttachmentUploadSessionService
    private lateinit var tempDir: Path
    private lateinit var storageProperties: com.tistory.shanepark.dutypark.common.config.StorageProperties
    private val loginMember = LoginMember(id = 1L, name = "testuser")
    private val clock = Clock.fixed(Instant.parse("2025-10-22T01:00:00Z"), ZoneId.systemDefault())

    @BeforeEach
    fun setUp() {
        tempDir = Files.createTempDirectory("attachment-test")
        storageProperties = com.tistory.shanepark.dutypark.common.config.StorageProperties(
            root = tempDir.toString(),
            maxFileSize = org.springframework.util.unit.DataSize.ofMegabytes(50),
            blacklistExt = listOf("exe", "sh"),
            thumbnail = com.tistory.shanepark.dutypark.common.config.StorageProperties.ThumbnailProperties(maxSide = 200),
            sessionExpirationHours = 24
        )
        attachmentRepository = FakeAttachmentRepository()
        validationService = AttachmentValidationService(storageProperties)
        pathResolver = StoragePathResolver(storageProperties)
        fakeFileSpy = FakeFileSpy()
        fileSystemService = TestFileSystemService(fakeFileSpy)
        fakeThumbnailSpy = FakeThumbnailSpy()
        thumbnailService = TestThumbnailService(
            fakeThumbnailSpy,
            storageProperties,
            attachmentRepository,
            pathResolver,
            fileSystemService
        )
        permissionEvaluator = org.mockito.kotlin.mock()
        sessionService = org.mockito.kotlin.mock()
        val eventPublisher = org.mockito.kotlin.mock<ApplicationEventPublisher>()
        service = AttachmentService(
            attachmentRepository,
            validationService,
            pathResolver,
            fileSystemService,
            thumbnailService,
            permissionEvaluator,
            sessionService,
            eventPublisher
        )
    }

    @Test
    fun `uploadFile should save attachment with generated filename`() {
        val sessionId = UUID.randomUUID()
        val session = AttachmentUploadSession(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = null,
            ownerId = loginMember.id,
            expiresAt = Instant.now().plusSeconds(3600)
        )
        org.mockito.kotlin.whenever(sessionService.findById(sessionId)).thenReturn(session)

        val file = MockMultipartFile(
            "file",
            "test.png",
            "image/png",
            "test content".toByteArray()
        )

        val result = service.uploadFile(
            loginMember = loginMember,
            sessionId = sessionId,
            file = file
        )

        assertThat(result.id).isNotNull
        assertThat(result.contextType).isEqualTo(AttachmentContextType.SCHEDULE)
        assertThat(result.uploadSessionId).isEqualTo(sessionId)
        assertThat(result.contextId).isNull()
        assertThat(result.originalFilename).isEqualTo("test.png")
        assertThat(result.contentType).isEqualTo("image/png")
        assertThat(result.size).isEqualTo(12L)
        assertThat(result.storedFilename).isNotEqualTo("test.png")
        assertThat(result.storedFilename).endsWith(".png")
        assertThat(result.createdBy).isEqualTo(loginMember.id)
        assertThat(result.orderIndex).isEqualTo(0)
        assertThat(attachmentRepository.savedAttachments).hasSize(1)
        assertThat(fakeFileSpy.writtenFiles).hasSize(1)
    }

    @Test
    fun `uploadFile should set thumbnail status to PENDING for image files`() {
        val sessionId = UUID.randomUUID()
        val session = AttachmentUploadSession(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = null,
            ownerId = loginMember.id,
            expiresAt = Instant.now().plusSeconds(3600)
        )
        org.mockito.kotlin.whenever(sessionService.findById(sessionId)).thenReturn(session)

        val file = MockMultipartFile(
            "file",
            "image.jpg",
            "image/jpeg",
            "image content".toByteArray()
        )

        fakeThumbnailSpy.canGenerateResult = true
        fakeThumbnailSpy.generateResult = true

        val result = service.uploadFile(
            loginMember = loginMember,
            sessionId = sessionId,
            file = file
        )

        assertThat(result.thumbnailStatus).isIn(ThumbnailStatus.PENDING, ThumbnailStatus.COMPLETED)
    }

    @Test
    fun `uploadFile should set thumbnail status to NONE for non-image files`() {
        val sessionId = UUID.randomUUID()
        val session = AttachmentUploadSession(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = null,
            ownerId = loginMember.id,
            expiresAt = Instant.now().plusSeconds(3600)
        )
        org.mockito.kotlin.whenever(sessionService.findById(sessionId)).thenReturn(session)

        val file = MockMultipartFile(
            "file",
            "document.pdf",
            "application/pdf",
            "pdf content".toByteArray()
        )

        fakeThumbnailSpy.canGenerateResult = false

        val result = service.uploadFile(
            loginMember = loginMember,
            sessionId = sessionId,
            file = file
        )

        assertThat(result.thumbnailStatus).isEqualTo(ThumbnailStatus.NONE)
    }

    @Test
    fun `uploadFile should set orderIndex based on existing attachments in session`() {
        val sessionId = UUID.randomUUID()
        val session = AttachmentUploadSession(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = null,
            ownerId = loginMember.id,
            expiresAt = Instant.now().plusSeconds(3600)
        )
        org.mockito.kotlin.whenever(sessionService.findById(sessionId)).thenReturn(session)

        val file1 = MockMultipartFile("file", "file1.txt", "text/plain", "content1".toByteArray())
        val file2 = MockMultipartFile("file", "file2.txt", "text/plain", "content2".toByteArray())
        val file3 = MockMultipartFile("file", "file3.txt", "text/plain", "content3".toByteArray())

        val attachment1 = service.uploadFile(loginMember, sessionId, file1)
        val attachment2 = service.uploadFile(loginMember, sessionId, file2)
        val attachment3 = service.uploadFile(loginMember, sessionId, file3)

        assertThat(attachment1.orderIndex).isEqualTo(0)
        assertThat(attachment2.orderIndex).isEqualTo(1)
        assertThat(attachment3.orderIndex).isEqualTo(2)
    }

    @Test
    fun `finalizeSessionForSchedule should remove attachments missing from ordered ids when session is empty`() {
        val sessionId = UUID.randomUUID()
        val scheduleId = UUID.randomUUID().toString()
        val session = AttachmentUploadSession(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = null,
            ownerId = loginMember.id,
            expiresAt = clock.instant().plusSeconds(3600)
        )
        org.mockito.kotlin.whenever(sessionService.findById(sessionId)).thenReturn(session)

        val storagePath = pathResolver.resolveContextDirectory(AttachmentContextType.SCHEDULE, scheduleId).toString()
        val kept = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = scheduleId,
                uploadSessionId = null,
                originalFilename = "keep.txt",
                storedFilename = "keep.txt",
                contentType = "text/plain",
                size = 10,
                storagePath = storagePath,
                orderIndex = 0,
                createdBy = loginMember.id
            )
        )
        val removed = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = scheduleId,
                uploadSessionId = null,
                originalFilename = "remove.txt",
                storedFilename = "remove.txt",
                contentType = "text/plain",
                size = 10,
                storagePath = storagePath,
                orderIndex = 1,
                createdBy = loginMember.id
            )
        )

        service.finalizeSessionForSchedule(
            loginMember = loginMember,
            sessionId = sessionId,
            scheduleId = scheduleId,
            orderedAttachmentIds = listOf(kept.id)
        )

        assertThat(attachmentRepository.findById(kept.id)).isPresent
        assertThat(attachmentRepository.findById(removed.id)).isEmpty
        org.mockito.kotlin.verify(sessionService).deleteSession(sessionId)
    }

    @Test
    fun `finalizeSessionForSchedule should delete storage directory when all attachments removed`() {
        val sessionId = UUID.randomUUID()
        val scheduleId = UUID.randomUUID().toString()
        val session = AttachmentUploadSession(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = null,
            ownerId = loginMember.id,
            expiresAt = clock.instant().plusSeconds(3600)
        )
        org.mockito.kotlin.whenever(sessionService.findById(sessionId)).thenReturn(session)

        val storageDir = pathResolver.resolveContextDirectory(AttachmentContextType.SCHEDULE, scheduleId)
        Files.createDirectories(storageDir)

        attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = scheduleId,
                uploadSessionId = null,
                originalFilename = "remove.txt",
                storedFilename = "remove.txt",
                contentType = "text/plain",
                size = 10,
                storagePath = storageDir.toString(),
                orderIndex = 0,
                createdBy = loginMember.id
            )
        )

        service.finalizeSessionForSchedule(
            loginMember = loginMember,
            sessionId = sessionId,
            scheduleId = scheduleId,
            orderedAttachmentIds = emptyList()
        )

        assertThat(Files.exists(storageDir)).isFalse()
    }

    @Test
    fun `discardSession should delete all session attachments and temporary directory`() {
        val sessionId = UUID.randomUUID()
        val session = AttachmentUploadSession(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = null,
            ownerId = loginMember.id,
            expiresAt = clock.instant().plusSeconds(3600)
        )
        org.mockito.kotlin.whenever(sessionService.findById(sessionId)).thenReturn(session)

        val tempDir = pathResolver.resolveTemporaryDirectory(sessionId)
        Files.createDirectories(tempDir)

        val attachment1 = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = null,
            uploadSessionId = sessionId,
            originalFilename = "file1.txt",
            storedFilename = "stored1.txt",
            contentType = "text/plain",
            size = 100,
            storagePath = tempDir.toString(),
            orderIndex = 0,
            createdBy = loginMember.id
        )
        val attachment2 = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = null,
            uploadSessionId = sessionId,
            originalFilename = "file2.png",
            storedFilename = "stored2.png",
            contentType = "image/png",
            size = 200,
            storagePath = tempDir.toString(),
            orderIndex = 1,
            createdBy = loginMember.id,
            thumbnailStatus = ThumbnailStatus.COMPLETED,
            thumbnailFilename = "thumb2.png",
            thumbnailContentType = "image/png"
        )

        Files.write(tempDir.resolve("stored1.txt"), "content1".toByteArray())
        Files.write(tempDir.resolve("stored2.png"), "content2".toByteArray())
        Files.write(tempDir.resolve("thumb2.png"), "thumbnail2".toByteArray())

        attachmentRepository.save(attachment1)
        attachmentRepository.save(attachment2)

        assertThat(Files.exists(tempDir)).isTrue()
        assertThat(attachmentRepository.count()).isEqualTo(2)

        service.discardSession(loginMember, sessionId)

        assertThat(attachmentRepository.count()).isEqualTo(0)
        assertThat(Files.exists(tempDir)).isFalse()
        org.mockito.kotlin.verify(sessionService).deleteSession(sessionId)
    }

    class FakeAttachmentRepository : AttachmentRepository {
        val savedAttachments = mutableListOf<Attachment>()
        val attachments = mutableMapOf<UUID, Attachment>()

        override fun <S : Attachment> save(entity: S): S {
            val attachmentId = entity.id
            val field = Attachment::class.java.superclass.getDeclaredField("id")
            field.isAccessible = true
            attachments[attachmentId] = entity
            savedAttachments.add(entity)
            return entity
        }

        override fun findAllByUploadSessionId(uploadSessionId: UUID): List<Attachment> {
            return attachments.values.filter { it.uploadSessionId == uploadSessionId }
        }

        override fun findAllByContextTypeAndContextIdIn(
            contextType: AttachmentContextType,
            contextIds: Collection<String>
        ): List<Attachment> {
            return attachments.values.filter { it.contextType == contextType && it.contextId in contextIds }
        }

        override fun findAllByContextTypeAndContextIdOrderByOrderIndexAsc(
            contextType: AttachmentContextType,
            contextId: String
        ): List<Attachment> {
            return attachments.values
                .filter { it.contextType == contextType && it.contextId == contextId }
                .sortedBy { it.orderIndex }
        }

        override fun findAllByContextTypeAndContextId(
            contextType: AttachmentContextType,
            contextId: String
        ): List<Attachment> {
            return attachments.values.filter { it.contextType == contextType && it.contextId == contextId }
        }

        override fun findById(id: UUID): Optional<Attachment> {
            return Optional.ofNullable(attachments[id])
        }

        override fun <S : Attachment> saveAll(entities: MutableIterable<S>): MutableList<S> {
            val result = mutableListOf<S>()
            entities.forEach { result.add(save(it)) }
            return result
        }

        override fun findAll(): MutableList<Attachment> = attachments.values.toMutableList()
        override fun findAllById(ids: MutableIterable<UUID>): MutableList<Attachment> =
            throw UnsupportedOperationException()

        override fun count(): Long = attachments.size.toLong()
        override fun deleteById(id: UUID) {
            attachments.remove(id)
        }

        override fun delete(entity: Attachment) {
            attachments.remove(entity.id)
        }

        override fun deleteAllById(ids: MutableIterable<UUID>) {
            ids.forEach { attachments.remove(it) }
        }

        override fun deleteAll(entities: MutableIterable<Attachment>) {
            entities.forEach { attachments.remove(it.id) }
        }

        override fun deleteAll() {
            attachments.clear()
        }

        override fun existsById(id: UUID): Boolean = attachments.containsKey(id)
        override fun flush() {}
        override fun <S : Attachment> saveAndFlush(entity: S): S = throw UnsupportedOperationException()
        override fun <S : Attachment> saveAllAndFlush(entities: MutableIterable<S>): MutableList<S> =
            throw UnsupportedOperationException()

        override fun deleteAllInBatch(entities: MutableIterable<Attachment>) = throw UnsupportedOperationException()
        override fun deleteAllByIdInBatch(ids: MutableIterable<UUID>) = throw UnsupportedOperationException()
        override fun deleteAllInBatch() = throw UnsupportedOperationException()
        override fun getOne(id: UUID): Attachment = throw UnsupportedOperationException()
        override fun getById(id: UUID): Attachment = throw UnsupportedOperationException()
        override fun getReferenceById(id: UUID): Attachment = throw UnsupportedOperationException()
        override fun <S : Attachment> findAll(example: org.springframework.data.domain.Example<S>): MutableList<S> =
            throw UnsupportedOperationException()

        override fun <S : Attachment> findAll(
            example: org.springframework.data.domain.Example<S>,
            sort: org.springframework.data.domain.Sort
        ): MutableList<S> = throw UnsupportedOperationException()

        override fun <S : Attachment> findAll(
            example: org.springframework.data.domain.Example<S>,
            pageable: org.springframework.data.domain.Pageable
        ): org.springframework.data.domain.Page<S> = throw UnsupportedOperationException()

        override fun <S : Attachment> count(example: org.springframework.data.domain.Example<S>): Long =
            throw UnsupportedOperationException()

        override fun <S : Attachment> exists(example: org.springframework.data.domain.Example<S>): Boolean =
            throw UnsupportedOperationException()

        override fun <S : Attachment, R : Any?> findBy(
            example: org.springframework.data.domain.Example<S>,
            queryFunction: java.util.function.Function<org.springframework.data.repository.query.FluentQuery.FetchableFluentQuery<S>, R>
        ): R = throw UnsupportedOperationException()

        override fun findAll(sort: org.springframework.data.domain.Sort): MutableList<Attachment> =
            throw UnsupportedOperationException()

        override fun findAll(pageable: org.springframework.data.domain.Pageable): org.springframework.data.domain.Page<Attachment> =
            throw UnsupportedOperationException()

        override fun <S : Attachment> findOne(example: org.springframework.data.domain.Example<S>): Optional<S> =
            throw UnsupportedOperationException()
    }

    class FakeFileSpy {
        val writtenFiles = mutableListOf<Path>()
    }

    class TestFileSystemService(private val spy: FakeFileSpy) : FileSystemService() {
        override fun writeFile(file: org.springframework.web.multipart.MultipartFile, targetPath: Path): Path {
            spy.writtenFiles.add(targetPath)
            return super.writeFile(file, targetPath)
        }
    }

    class FakeThumbnailSpy {
        var canGenerateResult = false
        var generateResult = false
        var generateCalls = 0
    }

    class TestThumbnailService(
        private val spy: FakeThumbnailSpy,
        storageProperties: com.tistory.shanepark.dutypark.common.config.StorageProperties,
        attachmentRepository: AttachmentRepository,
        pathResolver: StoragePathResolver,
        fileSystemService: FileSystemService
    ) : ThumbnailService(
        emptyList(),
        storageProperties,
        attachmentRepository,
        pathResolver,
        fileSystemService
    ) {
        override fun canGenerateThumbnail(contentType: String): Boolean {
            return spy.canGenerateResult
        }

        override fun generateThumbnail(sourcePath: Path, targetPath: Path, contentType: String): Boolean {
            spy.generateCalls++
            if (spy.generateResult) {
                Files.write(targetPath, "thumbnail".toByteArray())
            }
            return spy.generateResult
        }
    }
}
