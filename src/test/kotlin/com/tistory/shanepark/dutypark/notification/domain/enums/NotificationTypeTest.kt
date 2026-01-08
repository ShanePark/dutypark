package com.tistory.shanepark.dutypark.notification.domain.enums

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class NotificationTypeTest {

    @Test
    fun `generateTitle replaces actorName placeholder`() {
        // When
        val title = NotificationType.FRIEND_REQUEST_RECEIVED.generateTitle("홍길동")

        // Then
        assertThat(title).isEqualTo("홍길동님이 친구 요청을 보냈습니다")
    }

    @Test
    fun `generateTitle for SCHEDULE_TAGGED includes schedule title when provided`() {
        // When
        val title = NotificationType.SCHEDULE_TAGGED.generateTitle("홍길동", "팀 회의")

        // Then
        assertThat(title).isEqualTo("홍길동님의 [팀 회의] 일정에 태그되었습니다")
    }

    @Test
    fun `generateTitle for SCHEDULE_TAGGED keeps placeholder when schedule title is null`() {
        // When
        val title = NotificationType.SCHEDULE_TAGGED.generateTitle("홍길동", null)

        // Then
        assertThat(title).isEqualTo("홍길동님의 [{scheduleTitle}] 일정에 태그되었습니다")
    }

    @Test
    fun `generateTitle ignores schedule title for non-SCHEDULE_TAGGED types`() {
        // When
        val title = NotificationType.FRIEND_REQUEST_ACCEPTED.generateTitle("홍길동", "무시될 값")

        // Then
        assertThat(title).isEqualTo("홍길동님이 친구 요청을 수락했습니다")
    }

    @Test
    fun `all notification types generate correct titles`() {
        val actorName = "테스트유저"
        val scheduleTitle = "스케줄 제목"

        assertThat(NotificationType.FRIEND_REQUEST_RECEIVED.generateTitle(actorName))
            .isEqualTo("테스트유저님이 친구 요청을 보냈습니다")

        assertThat(NotificationType.FRIEND_REQUEST_ACCEPTED.generateTitle(actorName))
            .isEqualTo("테스트유저님이 친구 요청을 수락했습니다")

        assertThat(NotificationType.FAMILY_REQUEST_RECEIVED.generateTitle(actorName))
            .isEqualTo("테스트유저님이 가족 요청을 보냈습니다")

        assertThat(NotificationType.FAMILY_REQUEST_ACCEPTED.generateTitle(actorName))
            .isEqualTo("테스트유저님이 가족 요청을 수락했습니다")

        assertThat(NotificationType.SCHEDULE_TAGGED.generateTitle(actorName, scheduleTitle))
            .isEqualTo("테스트유저님의 [스케줄 제목] 일정에 태그되었습니다")
    }
}
