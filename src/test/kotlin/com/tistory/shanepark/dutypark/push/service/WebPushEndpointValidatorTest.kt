package com.tistory.shanepark.dutypark.push.service

import com.tistory.shanepark.dutypark.push.service.WebPushEndpointValidator.Result
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.net.InetAddress
import java.net.UnknownHostException

class WebPushEndpointValidatorTest {
    private val publicAddress = InetAddress.getByAddress(byteArrayOf(8, 8, 8, 8))

    @Test
    fun `accepts supported provider HTTPS endpoints with public DNS addresses`() {
        val validator = WebPushEndpointValidator { arrayOf(publicAddress, InetAddress.getByName("2606:4700:4700::1111")) }
        listOf(
            "https://fcm.googleapis.com/fcm/send/token",
            "https://updates.push.services.mozilla.com/wpush/v2/token",
            "https://web.push.apple.com/token",
            "https://region.web.push.apple.com/token",
            "https://wns2.notify.windows.com/?token=secret",
            "https://FCM.GOOGLEAPIS.COM:443/token",
        ).forEach { endpoint -> assertThat(validator.validate(endpoint)).describedAs(endpoint).isEqualTo(Result.VALID) }
    }

    @Test
    fun `rejects untrusted or ambiguous endpoints before resolving DNS`() {
        val validator = WebPushEndpointValidator { error("Untrusted host must not be resolved") }
        listOf(
            "http://fcm.googleapis.com/token", "ftp://fcm.googleapis.com/token",
            "https://fcm.googleapis.com:8443/token", "https://user@fcm.googleapis.com/token",
            "https://fcm.googleapis.com/token#fragment", "https://fcm.googleapis.com./token",
            "https://fcm.googleapis.com.evil.example/token", "https://evilpush.apple.com/token",
            "https://evilnotify.windows.com/token", "https://push.apple.com/token",
            "https://localhost/internal", "https://127.0.0.1/internal", "https://[::1]/internal",
            "https://169.254.169.254/latest", "//fcm.googleapis.com/token", "not a URL",
            "https://fcm.googleapis.com\\@127.0.0.1/internal", "https://fcm.googleapis.com%2eevil.example/token",
        ).forEach { endpoint -> assertThat(validator.validate(endpoint)).describedAs(endpoint).isEqualTo(Result.INVALID) }
    }

    @Test
    fun `rejects provider DNS pointing to non public IPv4 addresses`() {
        listOf(
            "0.0.0.0", "10.0.0.1", "100.64.0.1", "100.127.255.255", "127.0.0.1",
            "169.254.169.254", "172.16.0.1", "172.31.255.255", "192.0.0.1", "192.0.2.1",
            "192.168.1.1", "198.18.0.1", "198.51.100.1", "203.0.113.1", "224.0.0.1", "255.255.255.255",
        ).forEach { address ->
            val validator = WebPushEndpointValidator { arrayOf(InetAddress.getByName(address)) }
            assertThat(validator.validate("https://fcm.googleapis.com/token")).describedAs(address).isEqualTo(Result.INVALID)
        }
    }

    @Test
    fun `rejects provider DNS pointing to non public IPv6 and mapped IPv4 addresses`() {
        listOf("::", "::1", "fc00::1", "fd00::1", "fe80::1", "ff02::1", "::ffff:127.0.0.1",
            "::ffff:192.168.1.1", "64:ff9b::7f00:1", "2001:db8::1", "2001::1", "2002:7f00:1::").forEach { address ->
            val validator = WebPushEndpointValidator { arrayOf(InetAddress.getByName(address)) }
            assertThat(validator.validate("https://web.push.apple.com/token")).describedAs(address).isEqualTo(Result.INVALID)
        }
    }

    @Test
    fun `rejects mixed public and private DNS results`() {
        val validator = WebPushEndpointValidator { arrayOf(publicAddress, InetAddress.getByName("10.0.0.1")) }
        assertThat(validator.validate("https://fcm.googleapis.com/token")).isEqualTo(Result.INVALID)
    }

    @Test
    fun `DNS lookup permission failure is unresolved rather than an invalid subscription`() {
        val validator = WebPushEndpointValidator { throw SecurityException("lookup denied") }
        assertThat(validator.validate("https://fcm.googleapis.com/token")).isEqualTo(Result.UNRESOLVED)
    }

    @Test
    fun `distinguishes unresolved DNS from confirmed invalid destinations`() {
        val unavailable = WebPushEndpointValidator { throw UnknownHostException("must not log provider token") }
        val empty = WebPushEndpointValidator { emptyArray() }
        assertThat(unavailable.validate("https://fcm.googleapis.com/token")).isEqualTo(Result.UNRESOLVED)
        assertThat(empty.validate("https://fcm.googleapis.com/token")).isEqualTo(Result.UNRESOLVED)
    }
}
