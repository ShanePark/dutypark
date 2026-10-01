package com.tistory.shanepark.dutypark.common.logging

import ch.qos.logback.classic.Level
import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.slf4j.LoggerFactory
import org.slf4j.MDC
import org.springframework.transaction.support.TransactionSynchronization
import org.springframework.transaction.support.TransactionSynchronizationManager
import java.time.LocalDate

class AuditLogTest {
    private val logger = LoggerFactory.getLogger(AuditLogTest::class.java) as Logger
    private lateinit var appender: ListAppender<ILoggingEvent>

    @BeforeEach
    fun setUp() {
        logger.level = Level.INFO
        appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
    }

    @AfterEach
    fun tearDown() {
        logger.detachAppender(appender)
        appender.stop()
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization()
        }
    }

    @Test
    fun `change log includes only changed fields and preserves nullable removals`() {
        val actor = LoginMember(
            id = 5,
            email = "private@example.com",
            name = "Shane",
            isImpersonating = true,
            originalMemberId = 2,
        ).toAuditActor()

        val logged = logger.auditChangeAfterCommit(
            event = "duty_type.updated",
            actor = actor,
            target = linkedMapOf("type" to "DutyType", "teamId" to 8, "teamName" to "Ward", "id" to 37),
            before = linkedMapOf("name" to "DAY", "color" to "#111111", "abbreviation" to "D"),
            after = linkedMapOf("name" to "NIGHT", "color" to "#111111", "abbreviation" to null),
        )

        assertThat(logged).isTrue()
        val message = appender.list.single().formattedMessage
        assertThat(message).contains("\"originalMemberId\":2")
        assertThat(message).doesNotContain("originalMemberName", "Manager")
        assertThat(message).contains("\"teamName\":\"Ward\"")
        assertThat(message).contains("\"name\":{\"before\":\"DAY\",\"after\":\"NIGHT\"}")
        assertThat(message).contains("\"abbreviation\":{\"before\":\"D\",\"after\":null}")
        assertThat(message).doesNotContain("\"color\"")
        assertThat(message).doesNotContain("private@example.com", "\"email\"")
    }

    @Test
    fun `no-op changes are suppressed`() {
        val logged = logger.auditChangeAfterCommit(
            event = "duty_type.updated",
            actor = AuditActor(5, "Shane"),
            target = mapOf("type" to "DutyType", "id" to 37),
            before = linkedMapOf("name" to "DAY", "hidden" to false),
            after = linkedMapOf("name" to "DAY", "hidden" to false),
        )

        assertThat(logged).isFalse()
        assertThat(appender.list).isEmpty()
    }

    @Test
    fun `disabled audit event does not serialize into after commit callback`() {
        val previousLevel = logger.level
        logger.level = Level.WARN
        TransactionSynchronizationManager.initSynchronization()
        try {
            logger.auditEventAfterCommit(
                event = "attachment.deleted",
                actor = AuditActor(5, "Shane"),
                target = mapOf("type" to "Attachment", "id" to 13),
            )

            assertThat(TransactionSynchronizationManager.getSynchronizations()).isEmpty()
            assertThat(appender.list).isEmpty()
        } finally {
            TransactionSynchronizationManager.clearSynchronization()
            logger.level = previousLevel
        }
    }

    @Test
    fun `disabled audit change preserves changed result without registering callback`() {
        val previousLevel = logger.level
        logger.level = Level.WARN
        TransactionSynchronizationManager.initSynchronization()
        try {
            val changed = logger.auditChangeAfterCommit(
                event = "duty_type.updated",
                actor = AuditActor(5, "Shane"),
                target = mapOf("type" to "DutyType", "id" to 37),
                before = mapOf("name" to "DAY"),
                after = mapOf("name" to "NIGHT"),
            )
            val unchanged = logger.auditChangeAfterCommit(
                event = "duty_type.updated",
                actor = AuditActor(5, "Shane"),
                target = mapOf("type" to "DutyType", "id" to 37),
                before = mapOf("name" to "NIGHT"),
                after = mapOf("name" to "NIGHT"),
            )

            assertThat(changed).isTrue()
            assertThat(unchanged).isFalse()
            assertThat(TransactionSynchronizationManager.getSynchronizations()).isEmpty()
            assertThat(appender.list).isEmpty()
        } finally {
            TransactionSynchronizationManager.clearSynchronization()
            logger.level = previousLevel
        }
    }

    @Test
    fun `context is one-line JSON escaped and excludes sensitive values`() {
        val context = auditContext(
            linkedMapOf(
                "message" to "first line\n\"second\"",
                "email" to "private@example.com",
                "password" to "private-password",
                "access_token" to "private-token",
                "sessionToken" to "private-session-token",
                "deviceToken" to "private-device-token",
                "pushToken" to "private-push-token",
                "vapidPrivateKey" to "private-vapid-key",
                "webhookUrl" to "https://private-webhook.example",
                "webhookToken" to "private-webhook-token",
                "sessionId" to 9,
                "refreshTokenId" to 13,
                "credentialChanged" to true,
                "date" to LocalDate.of(2026, 9, 27),
            )
        )

        assertThat(context).contains("\"message\":\"first line\\n\\\"second\\\"\"")
        assertThat(context).contains("\"sessionId\":9", "\"refreshTokenId\":13", "\"credentialChanged\":true")
        assertThat(context).contains("\"date\":\"2026-09-27\"")
        assertThat(context).doesNotContain(
            "private@example.com",
            "private-password",
            "private-token",
            "private-session-token",
            "private-device-token",
            "private-push-token",
            "private-vapid-key",
            "https://private-webhook.example",
            "private-webhook-token",
        )
        assertThat(context).doesNotContain(
            "\"email\"",
            "\"password\"",
            "\"access_token\"",
            "\"sessionToken\"",
            "\"deviceToken\"",
            "\"pushToken\"",
            "\"vapidPrivateKey\"",
            "\"webhookUrl\"",
            "\"webhookToken\"",
        )
        assertThat(context).doesNotContain("\n")
    }

    @Test
    fun `audit event waits for transaction commit`() {
        TransactionSynchronizationManager.initSynchronization()
        try {
            logger.auditEventAfterCommit(
                event = "attachment.deleted",
                actor = AuditActor(5, "Shane"),
                target = mapOf("type" to "Attachment", "id" to 13),
            )

            assertThat(appender.list).isEmpty()
            TransactionSynchronizationManager.getSynchronizations().forEach(TransactionSynchronization::afterCommit)
            assertThat(appender.list).hasSize(1)
        } finally {
            TransactionSynchronizationManager.clearSynchronization()
        }
    }

    @Test
    fun `audit event is discarded when transaction rolls back`() {
        TransactionSynchronizationManager.initSynchronization()
        try {
            logger.auditEventAfterCommit(
                event = "attachment.deleted",
                actor = AuditActor(5, "Shane"),
                target = mapOf("type" to "Attachment", "id" to 13),
            )

            assertThat(appender.list).isEmpty()
            TransactionSynchronizationManager.getSynchronizations().forEach {
                it.afterCompletion(TransactionSynchronization.STATUS_ROLLED_BACK)
            }
            assertThat(appender.list).isEmpty()
        } finally {
            TransactionSynchronizationManager.clearSynchronization()
        }
    }

    @Test
    fun `audit event freezes nested values and actor before commit`() {
        TransactionSynchronizationManager.initSynchronization()
        try {
            var actor = AuditActor(5, "Before")
            val nestedFields = linkedMapOf<String, Any?>("status" to "before")
            val items = mutableListOf("before")

            logger.auditEventAfterCommit(
                event = "schedule.updated",
                actor = actor,
                target = mapOf("type" to "Schedule", "id" to 17),
                details = linkedMapOf("nested" to nestedFields, "items" to items),
            )

            actor = AuditActor(6, "After")
            nestedFields["status"] = "after"
            items[0] = "after"
            assertThat(appender.list).isEmpty()

            TransactionSynchronizationManager.getSynchronizations().forEach { it.afterCommit() }

            val message = appender.list.single().formattedMessage
            assertThat(message).contains("\"actor\":{\"id\":5,\"name\":\"Before\"}")
            assertThat(message).contains("\"status\":\"before\"", "\"items\":[\"before\"]")
            assertThat(message).doesNotContain("\"name\":\"After\"", "\"status\":\"after\"", "\"items\":[\"after\"]")
        } finally {
            TransactionSynchronizationManager.clearSynchronization()
        }
    }

    @Test
    fun `context encodes audit actor fields and never calls arbitrary object stringification`() {
        val context = auditContext(
            linkedMapOf(
                "actor" to AuditActor(5, "Shane", 2),
                "unknown" to UnsafeToString(),
            )
        )

        assertThat(context).contains("\"actor\":{\"id\":5,\"name\":\"Shane\",\"originalMemberId\":2}")
        assertThat(context).doesNotContain("email", "Unsafe secret", "private@example.com")
        assertThat(context).contains("UnsafeToString")
    }

    @Test
    fun `credential aliases are excluded without hiding diagnostic codes`() {
        val context = auditContext(mapOf(
            "proof" to "secret-proof", "receiptToken" to "secret-receipt",
            "socialId" to "secret-social", "oauthState" to "secret-state",
            "authorizationCode" to "secret-authcode", "code" to "auth.required",
            "reauthProof" to "secret-reauth", "proofHash" to "secret-proof-hash",
            "receiptHash" to "secret-receipt-hash", "receiptTokenHash" to "secret-receipt-token-hash",
            "pkceVerifier" to "secret-pkce", "code_verifier" to "secret-verifier",
            "nested" to mapOf("id_token" to "secret-id-token"),
        ))
        assertThat(context).doesNotContain("secret-")
        assertThat(context).contains("auth.required")
    }

    @Test
    fun `audit event freezes request correlation before commit`() {
        TransactionSynchronizationManager.initSynchronization()
        MDC.put("requestId", "original-request")
        try {
            logger.auditEventAfterCommit("member.created", null)
            MDC.put("requestId", "different-request")
            TransactionSynchronizationManager.getSynchronizations().forEach { it.afterCommit() }
            assertThat(appender.list.single().formattedMessage).contains("original-request")
                .doesNotContain("different-request")
        } finally {
            MDC.remove("requestId")
        }
    }

    private class UnsafeToString {
        override fun toString(): String = error("Audit logging must not call arbitrary toString")
    }
}
