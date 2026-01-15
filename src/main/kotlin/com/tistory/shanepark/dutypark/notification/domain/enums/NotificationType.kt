package com.tistory.shanepark.dutypark.notification.domain.enums

enum class NotificationType(
    val titleTemplate: String,
    val pushBodyTemplate: String
) {
    FRIEND_REQUEST_RECEIVED("{actorName}님이 친구 요청을 보냈습니다", "친구 요청을 보냈습니다"),
    FRIEND_REQUEST_ACCEPTED("{actorName}님이 친구 요청을 수락했습니다", "친구 요청을 수락했습니다"),
    FAMILY_REQUEST_RECEIVED("{actorName}님이 가족 요청을 보냈습니다", "가족 요청을 보냈습니다"),
    FAMILY_REQUEST_ACCEPTED("{actorName}님이 가족 요청을 수락했습니다", "가족 요청을 수락했습니다"),
    SCHEDULE_TAGGED("{actorName}님의 [{scheduleTitle}] 일정에 태그되었습니다", "[{scheduleTitle}] 일정에 태그되었습니다");

    fun generateTitle(actorName: String, scheduleTitle: String? = null): String {
        var result = titleTemplate.replace("{actorName}", actorName)
        if (scheduleTitle != null) {
            result = result.replace("{scheduleTitle}", scheduleTitle)
        }
        return result
    }

    fun generatePushBody(scheduleTitle: String? = null): String {
        var result = pushBodyTemplate
        if (scheduleTitle != null) {
            result = result.replace("{scheduleTitle}", scheduleTitle)
        }
        return result
    }
}
