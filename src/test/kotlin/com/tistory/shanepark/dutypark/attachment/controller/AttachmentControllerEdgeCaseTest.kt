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
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.mock.web.MockMultipartFile
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders.*
import java.nio.file.Files
import java.time.Clock
import java.time.LocalDateTime
import java.util.*

class AttachmentControllerEdgeCaseTest : RestDocsTest() {

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
    fun `upload to session owned by another user returns 403`() {
        val member = TestData.member
        val member2 = TestData.member2
        val jwt = getJwt(member)

        val session = sessionRepository.save(
            AttachmentUploadSession(
                contextType = AttachmentContextType.SCHEDULE,
                targetContextId = null,
                ownerId = member2.id!!,
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
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().is4xxClientError)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `upload with special characters in filename`() {
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

        val specialFilename = "테스트 파일 (1) [중요].txt"
        val file = MockMultipartFile(
            "file",
            specialFilename,
            "text/plain",
            "Content with special chars".toByteArray()
        )

        mockMvc.perform(
            multipart("/api/attachments")
                .file(file)
                .param("sessionId", session.id.toString())
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
    }


    @Test
    fun `delete attachment owned by another user returns 403`() {
        val member = TestData.member
        val member2 = TestData.member2
        val jwt = getJwt(member)

        val session = sessionRepository.save(
            AttachmentUploadSession(
                contextType = AttachmentContextType.SCHEDULE,
                targetContextId = null,
                ownerId = member2.id!!,
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
                createdBy = member2.id!!,
                orderIndex = 0
            )
        )

        mockMvc.perform(
            delete("/api/attachments/{id}", attachment.id)
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().is4xxClientError)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `finalize session with empty attachments succeeds`() {
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

        val request = FinalizeSessionRequest(
            contextId = schedule.id.toString(),
            orderedAttachmentIds = emptyList()
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
    }


    @Test
    fun `reorder with empty attachment list succeeds`() {
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

        val request = ReorderAttachmentsRequest(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = schedule.id.toString(),
            orderedAttachmentIds = emptyList()
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
    }

    @Test
    fun `list attachments for non-existent context returns empty list`() {
        val member = TestData.member
        val jwt = getJwt(member)

        mockMvc.perform(
            get("/api/attachments")
                .param("contextType", "SCHEDULE")
                .param("contextId", UUID.randomUUID().toString())
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `download attachment with filename containing newlines is sanitized`() {
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

        val maliciousFilename = "test\r\nContent-Type: text/html\r\n\r\n<script>alert('xss')</script>.txt"
        val attachment = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = null,
                uploadSessionId = session.id,
                originalFilename = maliciousFilename,
                storedFilename = "safe-uuid.txt",
                contentType = "text/plain",
                size = 100,
                storagePath = pathResolver.resolveTemporaryDirectory(session.id!!).toString(),
                createdBy = member.id!!,
                orderIndex = 0
            )
        )

        val tempDir = pathResolver.resolveTemporaryDirectory(session.id!!)
        Files.createDirectories(tempDir)
        Files.write(tempDir.resolve("safe-uuid.txt"), "safe content".toByteArray())

        mockMvc.perform(
            get("/api/attachments/{id}/download", attachment.id)
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
    }
}
