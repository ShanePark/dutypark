package com.tistory.shanepark.dutypark.security.config

import com.tistory.shanepark.dutypark.security.repository.LoginAttemptRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.env.YamlPropertySourceLoader
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment.RANDOM_PORT
import org.springframework.boot.test.web.server.LocalServerPort
import org.springframework.core.env.EnumerablePropertySource
import org.springframework.core.io.FileSystemResource
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse

private const val EMAIL = "forwarded-header-trust@duty.park"
private val LOOPBACK_ADDRESSES = setOf("127.0.0.1", "0:0:0:0:0:0:0:1", "::1")

/**
 * Runs against a real Tomcat because forwarded-header handling happens in Tomcat's RemoteIpValve,
 * which MockMvc bypasses. The server.* forwarding settings come from the production application.yml
 * (the test application.yml shadows it on the classpath).
 */
@SpringBootTest(webEnvironment = RANDOM_PORT)
class ForwardedHeaderTrustTest {

    @LocalServerPort
    var port: Int = 0

    @Autowired
    lateinit var loginAttemptRepository: LoginAttemptRepository

    @BeforeEach
    @AfterEach
    fun cleanup() {
        loginAttemptRepository.deleteAll()
    }

    @Test
    fun `rotating spoofed Forwarded header does not bypass the login rate limit`() {
        val statuses = (1..6).map { attempt ->
            failedLogin(port, "Forwarded" to "for=203.0.113.$attempt")
        }

        assertThat(statuses).containsExactly(401, 401, 401, 401, 401, 429)
        assertThat(loginAttemptRepository.findAll().map { it.ipAddress }.toSet())
            .isSubsetOf(LOOPBACK_ADDRESSES)
    }

    @Test
    fun `X-Forwarded-For from a trusted internal proxy sets the client IP`() {
        assertThat(failedLogin(port, "X-Forwarded-For" to "198.51.100.7")).isEqualTo(401)

        assertThat(loginAttemptRepository.findAll().map { it.ipAddress })
            .containsExactly("198.51.100.7")
    }

    companion object {
        @JvmStatic
        @DynamicPropertySource
        fun productionForwardingProperties(registry: DynamicPropertyRegistry) {
            registerProductionForwardingProperties(registry)
        }
    }
}

/**
 * Same production forwarding settings, but the loopback test client is not a trusted proxy,
 * as for any direct peer outside the internal proxy ranges.
 */
@SpringBootTest(
    webEnvironment = RANDOM_PORT,
    properties = ["server.tomcat.remoteip.internal-proxies=192\\.0\\.2\\.1"],
)
class UntrustedPeerForwardedHeaderTest {

    @LocalServerPort
    var port: Int = 0

    @Autowired
    lateinit var loginAttemptRepository: LoginAttemptRepository

    @BeforeEach
    @AfterEach
    fun cleanup() {
        loginAttemptRepository.deleteAll()
    }

    @Test
    fun `X-Forwarded-For from an untrusted peer is ignored`() {
        val statuses = (1..6).map { attempt ->
            failedLogin(port, "X-Forwarded-For" to "203.0.113.$attempt")
        }

        assertThat(statuses).containsExactly(401, 401, 401, 401, 401, 429)
        assertThat(loginAttemptRepository.findAll().map { it.ipAddress }.toSet())
            .isSubsetOf(LOOPBACK_ADDRESSES)
    }

    companion object {
        @JvmStatic
        @DynamicPropertySource
        fun productionForwardingProperties(registry: DynamicPropertyRegistry) {
            registerProductionForwardingProperties(registry, except = setOf("server.tomcat.remoteip.internal-proxies"))
        }
    }
}

private fun registerProductionForwardingProperties(
    registry: DynamicPropertyRegistry,
    except: Set<String> = emptySet(),
) {
    val production = YamlPropertySourceLoader()
        .load("application", FileSystemResource("src/main/resources/application.yml"))
        .first() as EnumerablePropertySource<*>
    production.propertyNames
        .filter { it == "server.forward-headers-strategy" || it.startsWith("server.tomcat.remoteip.") }
        .filterNot { it in except }
        .forEach { name -> registry.add(name) { requireNotNull(production.getProperty(name)) } }
}

private fun failedLogin(port: Int, header: Pair<String, String>): Int {
    val request = HttpRequest.newBuilder(URI("http://127.0.0.1:$port/api/auth/token"))
        .header("Content-Type", "application/json")
        .header(header.first, header.second)
        .POST(HttpRequest.BodyPublishers.ofString("""{"email":"$EMAIL","password":"wrong-password"}"""))
        .build()
    return HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.discarding()).statusCode()
}
