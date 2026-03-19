package com.tistory.shanepark.dutypark.notification.domain.enums

enum class NotificationType(
    val titleTemplate: String,
    val pushBodyTemplate: String
) {
    FRIEND_REQUEST_RECEIVED("{actorName}님이 친구 요청을 보냈습니다", "친구 요청을 보냈습니다"),
    FRIEND_REQUEST_ACCEPTED("{actorName}님이 친구 요청을 수락했습니다", "친구 요청을 수락했습니다"),
    FAMILY_REQUEST_RECEIVED("{actorName}님이 가족 요청을 보냈습니다", "가족 요청을 보냈습니다"),
    FAMILY_REQUEST_ACCEPTED("{actorName}님이 가족 요청을 수락했습니다", "가족 요청을 수락했습니다"),
    SCHEDULE_TAGGED("{actorName}님의 [{scheduleTitle}] 일정에 태그되었습니다", "[{scheduleTitle}] 일정에 태그되었습니다"),
    TODO_TAGGED("{actorName}님의 [{todoTitle}] TODO에 태그되었습니다", "[{todoTitle}] TODO에 태그되었습니다"),
    TODO_STATUS_TODO("{actorName}님이 [{todoTitle}] TODO를 할 일로 변경했습니다", "[{todoTitle}] TODO를 할 일로 변경했습니다"),
    TODO_STATUS_IN_PROGRESS("{actorName}님이 [{todoTitle}] TODO를 진행중으로 변경했습니다", "[{todoTitle}] TODO를 진행중으로 변경했습니다"),
    TODO_STATUS_DONE("{actorName}님이 [{todoTitle}] TODO를 완료 처리했습니다", "[{todoTitle}] TODO를 완료 처리했습니다");

    fun generateTitle(actorName: String, contentTitle: String? = null): String {
        var result = titleTemplate.replace("{actorName}", actorName)
        if (contentTitle != null) {
            result = result.replace("{scheduleTitle}", contentTitle)
            result = result.replace("{todoTitle}", contentTitle)
        }
        return result
    }

    fun generatePushBody(contentTitle: String? = null): String {
        var result = pushBodyTemplate
        if (contentTitle != null) {
            result = result.replace("{scheduleTitle}", contentTitle)
            result = result.replace("{todoTitle}", contentTitle)
        }
        return result
    }
}
