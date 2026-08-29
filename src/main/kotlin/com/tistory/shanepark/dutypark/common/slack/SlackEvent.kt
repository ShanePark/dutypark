package com.tistory.shanepark.dutypark.common.slack

/**
 * 외부 운영 채널에 보낼 수 있는 안전한 알림 레이아웃.
 *
 * 이벤트에는 분류에 필요한 고정 문구와 운영 enum만 담는다. 사용자·요청 데이터와
 * record ID를 실을 수 있는 본문, 부제목, 각주 필드는 의도적으로 제공하지 않는다.
 */
data class SlackEvent(
    /** 제목 앞에 붙는 유니코드 이모지. 색보다 먼저 알림 종류를 구분해 준다. */
    val emoji: String,

    /** 무슨 일이 일어났는지. 예: `New inquiry` */
    val title: String,

    /** 분류에 필요한 고정 문구 또는 enum. 사용자 입력을 넣지 않는다. */
    val headline: String? = null,

    /** 분류에 필요한 짧은 운영 값들. 사용자 입력을 넣지 않는다. */
    val chips: List<String> = emptyList(),

    val level: SlackEventLevel = SlackEventLevel.INFO,
)

/**
 * 왼쪽 색 막대. 채널을 스크롤할 때 읽을 순서를 정하는 용도라 단계를 잘게 나누지 않는다.
 */
enum class SlackEventLevel(val color: String) {
    /** 평소 흐름대로 들어온 일 */
    INFO("#2eb886"),

    /** 사람이 확인해야 하는 일 */
    NOTICE("#e8a33d"),

    /** 지금 손대야 하는 일 */
    ALERT("#d64545"),

    /** 기록만 남기면 되는 일 */
    MUTED("#9aa4b2"),
}
