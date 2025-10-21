package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.domain.enums.ThumbnailStatus
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.mock.web.MockMultipartFile
import java.nio.file.Files
import java.nio.file.Path
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
    private lateinit var tempDir: Path
    private lateinit var storageProperties: com.tistory.shanepark.dutypark.common.config.StorageProperties

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
        service = AttachmentService(
            attachmentRepository,
            validationService,
            pathResolver,
            fileSystemService,
            thumbnailService
        )
    }

    @Test
    fun `uploadFile should save attachment with generated filename`() {
        val sessionId = UUID.randomUUID()
        val file = MockMultipartFile(
            "file",
            "test.png",
            "image/png",
            "test content".toByteArray()
        )
        val createdBy = 42L

        val result = service.uploadFile(
            sessionId = sessionId,
            file = file,
            contextType = AttachmentContextType.SCHEDULE,
            createdBy = createdBy
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
        assertThat(result.createdBy).isEqualTo(createdBy)
        assertThat(result.orderIndex).isEqualTo(0)
        assertThat(attachmentRepository.savedAttachments).hasSize(1)
        assertThat(fakeFileSpy.writtenFiles).hasSize(1)
    }

    @Test
    fun `uploadFile should set thumbnail status to PENDING for image files`() {
        val sessionId = UUID.randomUUID()
        val file = MockMultipartFile(
            "file",
            "image.jpg",
            "image/jpeg",
            "image content".toByteArray()
        )

        fakeThumbnailSpy.canGenerateResult = true
        fakeThumbnailSpy.generateResult = true

        val result = service.uploadFile(
            sessionId = sessionId,
            file = file,
            contextType = AttachmentContextType.SCHEDULE,
            createdBy = 1L
        )

        assertThat(result.thumbnailStatus).isIn(ThumbnailStatus.PENDING, ThumbnailStatus.COMPLETED)
    }

    @Test
    fun `uploadFile should set thumbnail status to NONE for non-image files`() {
        val sessionId = UUID.randomUUID()
        val file = MockMultipartFile(
            "file",
            "document.pdf",
            "application/pdf",
            "pdf content".toByteArray()
        )

        fakeThumbnailSpy.canGenerateResult = false

        val result = service.uploadFile(
            sessionId = sessionId,
            file = file,
            contextType = AttachmentContextType.SCHEDULE,
            createdBy = 1L
        )

        assertThat(result.thumbnailStatus).isEqualTo(ThumbnailStatus.NONE)
    }

    @Test
    fun `uploadFile should set orderIndex based on existing attachments in session`() {
        val sessionId = UUID.randomUUID()

        val file1 = MockMultipartFile("file", "file1.txt", "text/plain", "content1".toByteArray())
        val file2 = MockMultipartFile("file", "file2.txt", "text/plain", "content2".toByteArray())
        val file3 = MockMultipartFile("file", "file3.txt", "text/plain", "content3".toByteArray())

        val attachment1 = service.uploadFile(sessionId, file1, AttachmentContextType.SCHEDULE, 1L)
        val attachment2 = service.uploadFile(sessionId, file2, AttachmentContextType.SCHEDULE, 1L)
        val attachment3 = service.uploadFile(sessionId, file3, AttachmentContextType.SCHEDULE, 1L)

        assertThat(attachment1.orderIndex).isEqualTo(0)
        assertThat(attachment2.orderIndex).isEqualTo(1)
        assertThat(attachment3.orderIndex).isEqualTo(2)
    }

    class FakeAttachmentRepository : AttachmentRepository {
        val savedAttachments = mutableListOf<Attachment>()
        val attachments = mutableMapOf<UUID, Attachment>()

        override fun <S : Attachment> save(entity: S): S {
            val attachmentId = entity.id ?: UUID.randomUUID()
            val field = Attachment::class.java.superclass.getDeclaredField("id")
            field.isAccessible = true
            if (entity.id == null) {
                field.set(entity, attachmentId)
            }
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

        override fun findById(id: UUID): Optional<Attachment> {
            return Optional.ofNullable(attachments[id])
        }

        override fun <S : Attachment> saveAll(entities: MutableIterable<S>): MutableList<S> {
            val result = mutableListOf<S>()
            entities.forEach { result.add(save(it)) }
            return result
        }

        override fun findAll(): MutableList<Attachment> = attachments.values.toMutableList()
        override fun findAllById(ids: MutableIterable<UUID>): MutableList<Attachment> = throw UnsupportedOperationException()
        override fun count(): Long = attachments.size.toLong()
        override fun deleteById(id: UUID) { attachments.remove(id) }
        override fun delete(entity: Attachment) { attachments.remove(entity.id) }
        override fun deleteAllById(ids: MutableIterable<UUID>) { ids.forEach { attachments.remove(it) } }
        override fun deleteAll(entities: MutableIterable<Attachment>) { entities.forEach { attachments.remove(it.id) } }
        override fun deleteAll() { attachments.clear() }
        override fun existsById(id: UUID): Boolean = attachments.containsKey(id)
        override fun flush() {}
        override fun <S : Attachment> saveAndFlush(entity: S): S = throw UnsupportedOperationException()
        override fun <S : Attachment> saveAllAndFlush(entities: MutableIterable<S>): MutableList<S> = throw UnsupportedOperationException()
        override fun deleteAllInBatch(entities: MutableIterable<Attachment>) = throw UnsupportedOperationException()
        override fun deleteAllByIdInBatch(ids: MutableIterable<UUID>) = throw UnsupportedOperationException()
        override fun deleteAllInBatch() = throw UnsupportedOperationException()
        override fun getOne(id: UUID): Attachment = throw UnsupportedOperationException()
        override fun getById(id: UUID): Attachment = throw UnsupportedOperationException()
        override fun getReferenceById(id: UUID): Attachment = throw UnsupportedOperationException()
        override fun <S : Attachment> findAll(example: org.springframework.data.domain.Example<S>): MutableList<S> = throw UnsupportedOperationException()
        override fun <S : Attachment> findAll(example: org.springframework.data.domain.Example<S>, sort: org.springframework.data.domain.Sort): MutableList<S> = throw UnsupportedOperationException()
        override fun <S : Attachment> findAll(example: org.springframework.data.domain.Example<S>, pageable: org.springframework.data.domain.Pageable): org.springframework.data.domain.Page<S> = throw UnsupportedOperationException()
        override fun <S : Attachment> count(example: org.springframework.data.domain.Example<S>): Long = throw UnsupportedOperationException()
        override fun <S : Attachment> exists(example: org.springframework.data.domain.Example<S>): Boolean = throw UnsupportedOperationException()
        override fun <S : Attachment, R : Any?> findBy(example: org.springframework.data.domain.Example<S>, queryFunction: java.util.function.Function<org.springframework.data.repository.query.FluentQuery.FetchableFluentQuery<S>, R>): R = throw UnsupportedOperationException()
        override fun findAll(sort: org.springframework.data.domain.Sort): MutableList<Attachment> = throw UnsupportedOperationException()
        override fun findAll(pageable: org.springframework.data.domain.Pageable): org.springframework.data.domain.Page<Attachment> = throw UnsupportedOperationException()
        override fun <S : Attachment> findOne(example: org.springframework.data.domain.Example<S>): Optional<S> = throw UnsupportedOperationException()
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
