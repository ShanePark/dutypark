package com.tistory.shanepark.dutypark.common.slack

/**
 * 운영 슬랙 알림의 공통 레이아웃. 새 알림을 붙일 때는 아래 조각에 값을 채우기만 하면
 * 채널에 쌓이는 메시지 모양이 일관되게 유지된다.
 *
 * 채널을 훑을 때 한 눈에 읽히는 것이 목적이라 세로 길이를 아끼도록 짰다.
 * 값마다 한 줄씩 늘리지 말고, 라벨 없이 뜻이 통하는 값은 [chips] 로,
 * 필요할 때만 찾아보면 되는 값은 [footnote] 로 내려보낸다. 빈 조각은 줄을 차지하지 않는다.
 */
data class SlackEvent(
    /** 제목 앞에 붙는 유니코드 이모지. 색보다 먼저 알림 종류를 구분해 준다. */
    val emoji: String,

    /** 무슨 일이 일어났는지. 예: `New inquiry` */
    val title: String,

    /** 누구에 대한 일인지 한 줄. 제목 옆에 이어 붙는다. */
    val subtitle: String? = null,

    /** 가장 먼저 읽어야 할 한 줄. 굵게 표시된다. */
    val headline: String? = null,

    /** 라벨 없이도 뜻이 통하는 짧은 값들. 배지 모양으로 한 줄에 모인다. */
    val chips: List<String> = emptyList(),

    /** 사용자가 직접 쓴 글. 인용구로 감싸 우리가 붙인 값과 구분한다. */
    val body: String? = null,

    /** ID 처럼 평소에는 안 보다가 필요할 때만 찾는 값. 맨 아래 작은 글씨 한 줄. */
    val footnote: List<String> = emptyList(),

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
