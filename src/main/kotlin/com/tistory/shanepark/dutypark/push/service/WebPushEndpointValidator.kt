package com.tistory.shanepark.dutypark.push.service

import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.net.URI
import java.net.UnknownHostException

class WebPushEndpointValidator(private val resolve: (String) -> Array<InetAddress>) {
    enum class Result { VALID, INVALID, UNRESOLVED }

    fun validate(endpoint: String): Result {
        val uri = runCatching { URI(endpoint) }.getOrNull() ?: return Result.INVALID
        val host = uri.host?.lowercase() ?: return Result.INVALID
        if (!uri.scheme.equals("https", ignoreCase = true) || uri.port !in listOf(-1, 443) ||
            uri.rawUserInfo != null || uri.rawFragment != null || !isTrustedProvider(host)
        ) return Result.INVALID
        val addresses = try {
            resolve(host)
        } catch (_: UnknownHostException) {
            return Result.UNRESOLVED
        } catch (_: SecurityException) {
            return Result.UNRESOLVED
        }
        if (addresses.isEmpty()) return Result.UNRESOLVED
        return if (addresses.all(::isPublicAddress)) Result.VALID else Result.INVALID
    }

    private fun isTrustedProvider(host: String): Boolean =
        host == "fcm.googleapis.com" || host == "updates.push.services.mozilla.com" ||
            host.endsWith(".push.apple.com") || host.endsWith(".notify.windows.com")

    private fun isPublicAddress(address: InetAddress): Boolean {
        if (address.isAnyLocalAddress || address.isLoopbackAddress || address.isLinkLocalAddress ||
            address.isSiteLocalAddress || address.isMulticastAddress
        ) return false
        val bytes = address.address.map { it.toInt() and 0xff }
        return when (address) {
            is Inet4Address -> {
                val value = bytes.fold(0L) { result, byte -> (result shl 8) or byte.toLong() }
                NON_PUBLIC_IPV4.none { (network, prefix) -> value shr (32 - prefix) == network shr (32 - prefix) }
            }
            is Inet6Address -> {
                // Only global unicast; exclude special-purpose, documentation and 6to4 ranges.
                bytes[0] and 0xe0 == 0x20 &&
                    !(bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] and 0xfe == 0) &&
                    !(bytes.take(4) == listOf(0x20, 0x01, 0x0d, 0xb8)) &&
                    !(bytes[0] == 0x20 && bytes[1] == 0x02)
            }
            else -> false
        }
    }

    companion object {
        private val NON_PUBLIC_IPV4 = listOf(
            0x00000000L to 8, 0x0a000000L to 8, 0x64400000L to 10, 0x7f000000L to 8,
            0xa9fe0000L to 16, 0xac100000L to 12, 0xc0000000L to 24, 0xc0000200L to 24,
            0xc0586300L to 24, 0xc0a80000L to 16, 0xc6120000L to 15, 0xc6336400L to 24,
            0xcb007100L to 24, 0xe0000000L to 3,
        )
    }
}
