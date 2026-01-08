package com.tistory.shanepark.dutypark.notification.domain.enums

enum class NotificationType(val titleTemplate: String) {
    FRIEND_REQUEST_RECEIVED("{actorName}님이 친구 요청을 보냈습니다"),
    FRIEND_REQUEST_ACCEPTED("{actorName}님이 친구 요청을 수락했습니다"),
    FAMILY_REQUEST_RECEIVED("{actorName}님이 가족 요청을 보냈습니다"),
    FAMILY_REQUEST_ACCEPTED("{actorName}님이 가족 요청을 수락했습니다"),
    SCHEDULE_TAGGED("{actorName}님이 스케줄에 태그했습니다");

    fun generateTitle(actorName: String): String {
        return titleTemplate.replace("{actorName}", actorName)
    }
}
