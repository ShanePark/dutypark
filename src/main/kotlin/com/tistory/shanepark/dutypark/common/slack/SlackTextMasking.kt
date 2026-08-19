package com.tistory.shanepark.dutypark.common.slack

/**
 * 슬랙은 서버 밖의 채널이므로 알림에 담는 사용자 입력은 여기서 한 번 걸러 보낸다.
 * 운영자가 상황을 판단할 만큼만 남기고, 회신 주소나 접속지처럼 식별에 쓰이는 값은 원문을 내보내지 않는다.
 */
object SlackTextMasking {

    const val EMPTY = "-"

    private const val MASK = "***"

    fun preview(text: String?, maxLength: Int): String {
        val trimmed = text?.trim()?.takeIf(String::isNotEmpty) ?: return EMPTY
        if (trimmed.length <= maxLength) {
            return trimmed
        }
        return trimmed.take(maxLength) + "… (+${trimmed.length - maxLength} chars)"
    }

    fun maskEmail(email: String?): String {
        val trimmed = email?.trim()?.takeIf(String::isNotEmpty) ?: return EMPTY
        val at = trimmed.lastIndexOf('@')
        if (at <= 0) {
            return MASK
        }
        return trimmed.take(minOf(2, at)) + MASK + trimmed.substring(at)
    }

    /**
     * IPv4 는 마지막 옥텟만, IPv6 는 앞 두 그룹만 남긴다. 같은 대역에서 반복되는 문의·신고는 알아볼 수 있으면서
     * 특정 접속지를 지목하지는 못하는 수준이다.
     */
    fun maskIp(ip: String?): String {
        val trimmed = ip?.trim()?.takeIf(String::isNotEmpty) ?: return EMPTY
        if (trimmed.contains(':')) {
            val groups = trimmed.split(':')
            return if (groups.size < 3) MASK else groups.take(2).joinToString(":") + ":$MASK"
        }
        val octets = trimmed.split('.')
        return if (octets.size != 4) MASK else octets.take(3).joinToString(".") + ".$MASK"
    }
}
