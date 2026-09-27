package com.tistory.shanepark.dutypark.common.logging

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.slf4j.Logger
import org.springframework.transaction.support.TransactionSynchronization
import org.springframework.transaction.support.TransactionSynchronizationManager
import tools.jackson.databind.json.JsonMapper
import java.time.temporal.TemporalAccessor
import java.util.UUID

data class AuditActor(
    val id: Long?,
    val name: String,
    val originalMemberId: Long? = null,
)

private val auditJsonMapper = JsonMapper.builder().build()

private val sensitiveFieldNames = setOf(
    "email",
    "emailaddress",
    "memberemail",
    "useremail",
    "password",
    "passwordhash",
    "passwordsalt",
    "currentpassword",
    "oldpassword",
    "newpassword",
    "passwordconfirmation",
    "token",
    "accesstoken",
    "refreshtoken",
    "idtoken",
    "sessiontoken",
    "devicetoken",
    "pushtoken",
    "secret",
    "clientsecret",
    "privatekey",
    "vapidprivatekey",
    "credential",
    "credentials",
    "authorization",
    "authheader",
    "bearertoken",
    "apikey",
    "webhookurl",
    "webhooktoken",
)

fun LoginMember.toAuditActor(): AuditActor = AuditActor(
    id = id,
    name = name,
    originalMemberId = originalMemberId.takeIf { isImpersonating },
)

fun Member.toAuditActor(): AuditActor = AuditActor(id = id, name = name)

/** Renders safe, scalar context as one JSON object suitable for a single log line. */
fun auditContext(fields: Map<String, Any?>): String = auditJsonMapper.writeValueAsString(sanitizeFields(fields))

fun Logger.auditEventAfterCommit(
    event: String,
    actor: AuditActor?,
    target: Map<String, Any?> = emptyMap(),
    details: Map<String, Any?> = emptyMap(),
) {
    if (!isInfoEnabled) return

    val message = auditContext(
        linkedMapOf(
            "event" to event,
            "actor" to actor,
            "target" to target,
            "details" to details,
        )
    )
    infoAfterCommit(message)
}

fun Logger.auditChangeAfterCommit(
    event: String,
    actor: AuditActor?,
    target: Map<String, Any?>,
    before: Map<String, Any?>,
    after: Map<String, Any?>,
): Boolean {
    val changes = changedFields(before, after)
    if (changes.isEmpty()) return false
    if (!isInfoEnabled) return true

    val message = auditContext(
        linkedMapOf(
            "event" to event,
            "actor" to actor,
            "target" to target,
            "changes" to changes,
        )
    )
    infoAfterCommit(message)
    return true
}

private fun changedFields(
    before: Map<String, Any?>,
    after: Map<String, Any?>,
): Map<String, Map<String, Any?>> {
    val changes = linkedMapOf<String, Map<String, Any?>>()
    (before.keys + after.keys).distinct().forEach { field ->
        if (isSensitiveField(field)) return@forEach

        val previousValue = before[field]
        val currentValue = after[field]
        if (previousValue != currentValue) {
            changes[field] = linkedMapOf("before" to previousValue, "after" to currentValue)
        }
    }
    return changes
}

private fun sanitizeFields(fields: Map<String, Any?>): Map<String, Any?> =
    linkedMapOf<String, Any?>().apply {
        fields.forEach { (key, value) ->
            if (!isSensitiveField(key)) put(key, sanitizeValue(value))
        }
    }

private fun sanitizeValue(value: Any?): Any? = when (value) {
    null, is String, is Boolean, is Number -> value
    is Char -> value.toString()
    is Enum<*> -> value.name
    is TemporalAccessor, is UUID -> value.toString()
    is AuditActor -> auditActorFields(value)
    is Map<*, *> -> linkedMapOf<String, Any?>().apply {
        value.forEach { (key, nestedValue) ->
            val field = key as? String ?: return@forEach
            if (!isSensitiveField(field)) put(field, sanitizeValue(nestedValue))
        }
    }
    is Iterable<*> -> value.map(::sanitizeValue)
    is Array<*> -> value.map(::sanitizeValue)
    else -> "[${value.javaClass.simpleName.ifBlank { "object" }}]"
}

private fun auditActorFields(actor: AuditActor): Map<String, Any?> =
    linkedMapOf<String, Any?>("id" to actor.id, "name" to actor.name).apply {
        actor.originalMemberId?.let {
            put("originalMemberId", it)
        }
    }

private fun isSensitiveField(field: String): Boolean =
    field.filter(Char::isLetterOrDigit).lowercase() in sensitiveFieldNames

private fun Logger.infoAfterCommit(message: String) {
    if (TransactionSynchronizationManager.isSynchronizationActive()) {
        TransactionSynchronizationManager.registerSynchronization(
            object : TransactionSynchronization {
                override fun afterCommit() {
                    info("{}", message)
                }
            }
        )
    } else {
        info("{}", message)
    }
}
