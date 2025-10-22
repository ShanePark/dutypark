package com.tistory.shanepark.dutypark.attachment.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.dto.FinalizeSessionRequest
import com.tistory.shanepark.dutypark.attachment.dto.ReorderAttachmentsRequest
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentUploadSessionRepository
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import jakarta.servlet.http.Cookie
import java.time.LocalDateTime
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.mock.web.MockMultipartFile
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders.*
import org.springframework.restdocs.payload.JsonFieldType
import org.springframework.restdocs.payload.PayloadDocumentation.*
import org.springframework.restdocs.request.RequestDocumentation.*
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*
import java.nio.file.Files
import java.time.Clock
import java.util.*

class AttachmentControllerTest : RestDocsTest() {

    @Autowired
    lateinit var attachmentRepository: AttachmentRepository

    @Autowired
    lateinit var sessionRepository: AttachmentUploadSessionRepository

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Autowired
    lateinit var pathResolver: StoragePathResolver

    @Autowired
    lateinit var clock: Clock

    @AfterEach
    fun cleanup() {
        attachmentRepository.deleteAll()
        sessionRepository.deleteAll()
        val storageRoot = pathResolver.getStorageRoot()
        if (Files.exists(storageRoot)) {
            Files.walk(storageRoot)
                .sorted(Comparator.reverseOrder())
                .forEach { Files.deleteIfExists(it) }
        }
    }

    @Test
    fun `upload file successfully`() {
        val member = TestData.member
        val jwt = getJwt(member)

        val session = sessionRepository.save(
            AttachmentUploadSession(
                contextType = AttachmentContextType.SCHEDULE,
                targetContextId = null,
                ownerId = member.id!!,
                expiresAt = clock.instant().plusSeconds(86400)
            )
        )

        val file = MockMultipartFile(
            "file",
            "test.txt",
            "text/plain",
            "Hello World".toByteArray()
        )

        val sizeBefore = attachmentRepository.count()

        mockMvc.perform(
            multipart("/api/attachments")
                .file(file)
                .param("sessionId", session.id.toString())
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.id").exists())
            .andExpect(jsonPath("$.originalFilename").value("test.txt"))
            .andExpect(jsonPath("$.contentType").value("text/plain"))
            .andExpect(jsonPath("$.size").value(11))
            .andExpect(jsonPath("$.contextType").value("SCHEDULE"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "attachments/upload",
                    responseFields(
                        fieldWithPath("id").type(JsonFieldType.STRING).description("Attachment ID"),
                        fieldWithPath("contextType").type(JsonFieldType.STRING).description("Context type"),
                        fieldWithPath("contextId").type(JsonFieldType.STRING).description("Context ID (null during upload)").optional(),
                        fieldWithPath("originalFilename").type(JsonFieldType.STRING).description("Original filename"),
                        fieldWithPath("contentType").type(JsonFieldType.STRING).description("MIME content type"),
                        fieldWithPath("size").type(JsonFieldType.NUMBER).description("File size in bytes"),
                        fieldWithPath("hasThumbnail").type(JsonFieldType.BOOLEAN).description("Whether thumbnail is available"),
                        fieldWithPath("thumbnailUrl").type(JsonFieldType.STRING).description("Thumbnail URL if available").optional(),
                        fieldWithPath("orderIndex").type(JsonFieldType.NUMBER).description("Display order index"),
                        fieldWithPath("createdAt").type(JsonFieldType.STRING).description("Creation timestamp"),
                        fieldWithPath("createdBy").type(JsonFieldType.NUMBER).description("Creator member ID")
                    )
                )
            )

        assertThat(attachmentRepository.count()).isEqualTo(sizeBefore + 1)
    }

    @Test
    fun `upload file unauthorized`() {
        val session = sessionRepository.save(
            AttachmentUploadSession(
                contextType = AttachmentContextType.SCHEDULE,
                targetContextId = null,
                ownerId = 999L,
                expiresAt = clock.instant().plusSeconds(86400)
            )
        )

        val file = MockMultipartFile(
            "file",
            "test.txt",
            "text/plain",
            "Hello World".toByteArray()
        )

        mockMvc.perform(
            multipart("/api/attachments")
                .file(file)
                .param("sessionId", session.id.toString())
        ).andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `delete attachment successfully`() {
        val member = TestData.member
        val jwt = getJwt(member)

        val session = sessionRepository.save(
            AttachmentUploadSession(
                contextType = AttachmentContextType.SCHEDULE,
                targetContextId = null,
                ownerId = member.id!!,
                expiresAt = clock.instant().plusSeconds(86400)
            )
        )

        val attachment = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = null,
                uploadSessionId = session.id,
                originalFilename = "test.txt",
                storedFilename = "uuid.txt",
                contentType = "text/plain",
                size = 100,
                storagePath = "/tmp/test",
                createdBy = member.id!!,
                orderIndex = 0
            )
        )

        val tempDir = pathResolver.resolveTemporaryDirectory(session.id!!)
        Files.createDirectories(tempDir)
        Files.write(tempDir.resolve("uuid.txt"), "test content".toByteArray())

        val sizeBefore = attachmentRepository.count()

        mockMvc.perform(
            delete("/api/attachments/{id}", attachment.id)
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document("attachments/delete")
            )

        assertThat(attachmentRepository.count()).isEqualTo(sizeBefore - 1)
    }

    @Test
    fun `list attachments by context`() {
        val member = TestData.member
        val jwt = getJwt(member)

        val schedule = scheduleRepository.save(
            Schedule(
                member = member,
                content = "Test schedule",
                startDateTime = LocalDateTime.now(),
                endDateTime = LocalDateTime.now().plusHours(1)
            )
        )
        val contextId = schedule.id.toString()

        attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = contextId,
                uploadSessionId = null,
                originalFilename = "file1.txt",
                storedFilename = "uuid1.txt",
                contentType = "text/plain",
                size = 100,
                storagePath = "/tmp/test",
                createdBy = member.id!!,
                orderIndex = 0
            )
        )

        attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = contextId,
                uploadSessionId = null,
                originalFilename = "file2.txt",
                storedFilename = "uuid2.txt",
                contentType = "text/plain",
                size = 200,
                storagePath = "/tmp/test",
                createdBy = member.id!!,
                orderIndex = 1
            )
        )

        mockMvc.perform(
            get("/api/attachments")
                .param("contextType", "SCHEDULE")
                .param("contextId", contextId)
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$").isArray)
            .andExpect(jsonPath("$.length()").value(2))
            .andExpect(jsonPath("$[0].originalFilename").value("file1.txt"))
            .andExpect(jsonPath("$[1].originalFilename").value("file2.txt"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "attachments/list",
                    queryParameters(
                        parameterWithName("contextType").description("Context type (e.g., SCHEDULE)"),
                        parameterWithName("contextId").description("Context ID")
                    ),
                    responseFields(
                        fieldWithPath("[].id").type(JsonFieldType.STRING).description("Attachment ID"),
                        fieldWithPath("[].contextType").type(JsonFieldType.STRING).description("Context type"),
                        fieldWithPath("[].contextId").type(JsonFieldType.STRING).description("Context ID"),
                        fieldWithPath("[].originalFilename").type(JsonFieldType.STRING).description("Original filename"),
                        fieldWithPath("[].contentType").type(JsonFieldType.STRING).description("MIME content type"),
                        fieldWithPath("[].size").type(JsonFieldType.NUMBER).description("File size in bytes"),
                        fieldWithPath("[].hasThumbnail").type(JsonFieldType.BOOLEAN).description("Whether thumbnail is available"),
                        fieldWithPath("[].thumbnailUrl").type(JsonFieldType.STRING).description("Thumbnail URL if available").optional(),
                        fieldWithPath("[].orderIndex").type(JsonFieldType.NUMBER).description("Display order index"),
                        fieldWithPath("[].createdAt").type(JsonFieldType.STRING).description("Creation timestamp"),
                        fieldWithPath("[].createdBy").type(JsonFieldType.NUMBER).description("Creator member ID")
                    )
                )
            )
    }

    @Test
    fun `reorder attachments successfully`() {
        val member = TestData.member
        val jwt = getJwt(member)

        val schedule = scheduleRepository.save(
            Schedule(
                member = member,
                content = "Test schedule",
                startDateTime = LocalDateTime.now(),
                endDateTime = LocalDateTime.now().plusHours(1)
            )
        )
        val contextId = schedule.id.toString()

        val attachment1 = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = contextId,
                uploadSessionId = null,
                originalFilename = "file1.txt",
                storedFilename = "uuid1.txt",
                contentType = "text/plain",
                size = 100,
                storagePath = "/tmp/test",
                createdBy = member.id!!,
                orderIndex = 0
            )
        )

        val attachment2 = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = contextId,
                uploadSessionId = null,
                originalFilename = "file2.txt",
                storedFilename = "uuid2.txt",
                contentType = "text/plain",
                size = 200,
                storagePath = "/tmp/test",
                createdBy = member.id!!,
                orderIndex = 1
            )
        )

        val request = ReorderAttachmentsRequest(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = contextId,
            orderedAttachmentIds = listOf(attachment2.id, attachment1.id)
        )
        val json = objectMapper.writeValueAsString(request)

        mockMvc.perform(
            post("/api/attachments/reorder")
                .accept("application/json")
                .contentType("application/json")
                .content(json)
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "attachments/reorder",
                    requestFields(
                        fieldWithPath("contextType").type(JsonFieldType.STRING).description("Context type"),
                        fieldWithPath("contextId").type(JsonFieldType.STRING).description("Context ID"),
                        fieldWithPath("orderedAttachmentIds").type(JsonFieldType.ARRAY).description("Ordered list of attachment IDs")
                    )
                )
            )

        val reordered1 = attachmentRepository.findById(attachment1.id).get()
        val reordered2 = attachmentRepository.findById(attachment2.id).get()

        assertThat(reordered2.orderIndex).isEqualTo(0)
        assertThat(reordered1.orderIndex).isEqualTo(1)
    }

    @Test
    fun `finalize session successfully`() {
        val member = TestData.member
        val jwt = getJwt(member)

        val schedule = scheduleRepository.save(
            Schedule(
                member = member,
                content = "Test schedule",
                startDateTime = LocalDateTime.now(),
                endDateTime = LocalDateTime.now().plusHours(1)
            )
        )

        val session = sessionRepository.save(
            AttachmentUploadSession(
                contextType = AttachmentContextType.SCHEDULE,
                targetContextId = schedule.id.toString(),
                ownerId = member.id!!,
                expiresAt = clock.instant().plusSeconds(86400)
            )
        )

        val tempDir = pathResolver.resolveTemporaryDirectory(session.id!!)
        Files.createDirectories(tempDir)
        Files.write(tempDir.resolve("uuid1.txt"), "test content 1".toByteArray())
        Files.write(tempDir.resolve("uuid2.txt"), "test content 2".toByteArray())

        val attachment1 = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = null,
                uploadSessionId = session.id,
                originalFilename = "file1.txt",
                storedFilename = "uuid1.txt",
                contentType = "text/plain",
                size = 14,
                storagePath = tempDir.toString(),
                createdBy = member.id!!,
                orderIndex = 0
            )
        )

        val attachment2 = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = null,
                uploadSessionId = session.id,
                originalFilename = "file2.txt",
                storedFilename = "uuid2.txt",
                contentType = "text/plain",
                size = 14,
                storagePath = tempDir.toString(),
                createdBy = member.id!!,
                orderIndex = 1
            )
        )

        val request = FinalizeSessionRequest(
            contextId = schedule.id.toString(),
            orderedAttachmentIds = listOf(attachment1.id, attachment2.id)
        )
        val json = objectMapper.writeValueAsString(request)

        mockMvc.perform(
            post("/api/attachments/sessions/{sessionId}/finalize", session.id)
                .accept("application/json")
                .contentType("application/json")
                .content(json)
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "attachments/sessions/finalize",
                    pathParameters(
                        parameterWithName("sessionId").description("Upload session ID to finalize")
                    ),
                    requestFields(
                        fieldWithPath("contextId").type(JsonFieldType.STRING).description("Target context ID (e.g., schedule ID)"),
                        fieldWithPath("orderedAttachmentIds").type(JsonFieldType.ARRAY).description("Ordered list of attachment IDs to bind to the context")
                    )
                )
            )

        val finalized1 = attachmentRepository.findById(attachment1.id).get()
        val finalized2 = attachmentRepository.findById(attachment2.id).get()

        assertThat(finalized1.contextId).isEqualTo(schedule.id.toString())
        assertThat(finalized1.uploadSessionId).isNull()
        assertThat(finalized2.contextId).isEqualTo(schedule.id.toString())
        assertThat(finalized2.uploadSessionId).isNull()
    }

    @Test
    fun `download attachment successfully`() {
        val member = TestData.member
        val jwt = getJwt(member)

        val schedule = scheduleRepository.save(
            Schedule(
                member = member,
                content = "Test schedule",
                startDateTime = LocalDateTime.now(),
                endDateTime = LocalDateTime.now().plusHours(1)
            )
        )

        val contextDir = pathResolver.resolveContextDirectory(AttachmentContextType.SCHEDULE, schedule.id.toString())
        Files.createDirectories(contextDir)
        val testContent = "Hello, this is a test file content!"
        Files.write(contextDir.resolve("stored-uuid.txt"), testContent.toByteArray())

        val attachment = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = schedule.id.toString(),
                uploadSessionId = null,
                originalFilename = "test-document.txt",
                storedFilename = "stored-uuid.txt",
                contentType = "text/plain",
                size = testContent.length.toLong(),
                storagePath = contextDir.toString(),
                createdBy = member.id!!,
                orderIndex = 0
            )
        )

        mockMvc.perform(
            get("/api/attachments/{id}/download", attachment.id)
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andExpect(header().string(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"test-document.txt\""))
            .andExpect(content().contentType(MediaType.TEXT_PLAIN))
            .andExpect(content().string(testContent))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "attachments/download",
                    pathParameters(
                        parameterWithName("id").description("Attachment ID to download")
                    )
                )
            )
    }

    @Test
    fun `get thumbnail successfully`() {
        val member = TestData.member
        val jwt = getJwt(member)

        val schedule = scheduleRepository.save(
            Schedule(
                member = member,
                content = "Test schedule",
                startDateTime = LocalDateTime.now(),
                endDateTime = LocalDateTime.now().plusHours(1)
            )
        )

        val contextDir = pathResolver.resolveContextDirectory(AttachmentContextType.SCHEDULE, schedule.id.toString())
        Files.createDirectories(contextDir)
        val thumbnailContent = "fake-png-data".toByteArray()
        Files.write(contextDir.resolve("thumb-uuid.png"), thumbnailContent)

        val attachment = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = schedule.id.toString(),
                uploadSessionId = null,
                originalFilename = "image.jpg",
                storedFilename = "stored-uuid.jpg",
                contentType = "image/jpeg",
                size = 50000,
                storagePath = contextDir.toString(),
                thumbnailFilename = "thumb-uuid.png",
                thumbnailContentType = "image/png",
                thumbnailSize = thumbnailContent.size.toLong(),
                createdBy = member.id!!,
                orderIndex = 0
            )
        )

        mockMvc.perform(
            get("/api/attachments/{id}/thumbnail", attachment.id)
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andExpect(content().contentType(MediaType.IMAGE_PNG))
            .andExpect(content().bytes(thumbnailContent))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "attachments/thumbnail",
                    pathParameters(
                        parameterWithName("id").description("Attachment ID to retrieve thumbnail for")
                    )
                )
            )
    }
}
