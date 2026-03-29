package com.tistory.shanepark.dutypark.notification.domain.enums

enum class NotificationType(
    val titleCode: String,
    val pushBodyCode: String
) {
    FRIEND_REQUEST_RECEIVED("notification.friendRequestReceived.title", "notification.friendRequestReceived.body"),
    FRIEND_REQUEST_ACCEPTED("notification.friendRequestAccepted.title", "notification.friendRequestAccepted.body"),
    FAMILY_REQUEST_RECEIVED("notification.familyRequestReceived.title", "notification.familyRequestReceived.body"),
    FAMILY_REQUEST_ACCEPTED("notification.familyRequestAccepted.title", "notification.familyRequestAccepted.body"),
    SCHEDULE_TAGGED("notification.scheduleTagged.title", "notification.scheduleTagged.body"),
    TODO_TAGGED("notification.todoTagged.title", "notification.todoTagged.body"),
    TODO_STATUS_TODO("notification.todoStatusTodo.title", "notification.todoStatusTodo.body"),
    TODO_STATUS_IN_PROGRESS("notification.todoStatusInProgress.title", "notification.todoStatusInProgress.body"),
    TODO_STATUS_DONE("notification.todoStatusDone.title", "notification.todoStatusDone.body");

    fun generateTitle(actorName: String, contentTitle: String? = null): String {
        var result = koreanTitleTemplate().replace("{actorName}", actorName)
        if (contentTitle != null) {
            result = result.replace("{scheduleTitle}", contentTitle)
            result = result.replace("{todoTitle}", contentTitle)
        }
        return result
    }

    fun generatePushBody(contentTitle: String? = null): String {
        var result = koreanPushBodyTemplate()
        if (contentTitle != null) {
            result = result.replace("{scheduleTitle}", contentTitle)
            result = result.replace("{todoTitle}", contentTitle)
        }
        return result
    }

    private fun koreanTitleTemplate(): String {
        return when (this) {
            FRIEND_REQUEST_RECEIVED -> "{actorName}님이 친구 요청을 보냈습니다"
            FRIEND_REQUEST_ACCEPTED -> "{actorName}님이 친구 요청을 수락했습니다"
            FAMILY_REQUEST_RECEIVED -> "{actorName}님이 가족 요청을 보냈습니다"
            FAMILY_REQUEST_ACCEPTED -> "{actorName}님이 가족 요청을 수락했습니다"
            SCHEDULE_TAGGED -> "{actorName}님의 [{scheduleTitle}] 일정에 태그되었습니다"
            TODO_TAGGED -> "{actorName}님의 [{todoTitle}] TODO에 태그되었습니다"
            TODO_STATUS_TODO -> "{actorName}님이 [{todoTitle}] TODO를 할 일로 변경했습니다"
            TODO_STATUS_IN_PROGRESS -> "{actorName}님이 [{todoTitle}] TODO를 진행중으로 변경했습니다"
            TODO_STATUS_DONE -> "{actorName}님이 [{todoTitle}] TODO를 완료 처리했습니다"
        }
    }

    private fun koreanPushBodyTemplate(): String {
        return when (this) {
            FRIEND_REQUEST_RECEIVED -> "친구 요청을 보냈습니다"
            FRIEND_REQUEST_ACCEPTED -> "친구 요청을 수락했습니다"
            FAMILY_REQUEST_RECEIVED -> "가족 요청을 보냈습니다"
            FAMILY_REQUEST_ACCEPTED -> "가족 요청을 수락했습니다"
            SCHEDULE_TAGGED -> "[{scheduleTitle}] 일정에 태그되었습니다"
            TODO_TAGGED -> "[{todoTitle}] TODO에 태그되었습니다"
            TODO_STATUS_TODO -> "[{todoTitle}] TODO를 할 일로 변경했습니다"
            TODO_STATUS_IN_PROGRESS -> "[{todoTitle}] TODO를 진행중으로 변경했습니다"
            TODO_STATUS_DONE -> "[{todoTitle}] TODO를 완료 처리했습니다"
        }
    }
}
