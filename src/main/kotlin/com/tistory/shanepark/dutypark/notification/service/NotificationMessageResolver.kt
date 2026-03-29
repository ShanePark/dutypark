package com.tistory.shanepark.dutypark.notification.service

import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import org.springframework.context.MessageSource
import org.springframework.stereotype.Component
import java.util.Locale

@Component
class NotificationMessageResolver(
    private val messageSource: MessageSource,
) {
    fun resolveTitle(
        type: NotificationType,
        locale: Locale,
        actorName: String,
        contentTitle: String? = null,
    ): String {
        return messageSource.getMessage(
            type.titleCode,
            arrayOf(actorName, contentTitle.orEmpty()),
            type.titleCode,
            locale,
        ) ?: type.titleCode
    }

    fun resolvePushBody(
        type: NotificationType,
        locale: Locale,
        contentTitle: String? = null,
    ): String {
        return messageSource.getMessage(
            type.pushBodyCode,
            arrayOf(contentTitle.orEmpty()),
            type.pushBodyCode,
            locale,
        ) ?: type.pushBodyCode
    }
}
