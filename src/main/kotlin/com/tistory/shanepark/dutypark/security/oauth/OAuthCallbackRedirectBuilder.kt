package com.tistory.shanepark.dutypark.security.oauth

import org.springframework.web.util.UriComponentsBuilder
import java.net.URI
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

internal fun buildOAuthCallbackUri(
    callbackUrl: String,
    redirectTarget: String?,
    vararg fragmentParams: Pair<String, String>
): URI {
    val params = buildList {
        addAll(fragmentParams.toList())
        redirectTarget
        ?.takeIf { it.isNotBlank() }
        ?.let { add("redirect" to it) }
    }
    val fragment = params.joinToString("&") { (key, value) ->
        "${key.urlEncode()}=${value.urlEncode()}"
    }

    return UriComponentsBuilder.fromUriString(callbackUrl)
        .fragment(fragment)
        .build(true)
        .toUri()
}

private fun String.urlEncode(): String = URLEncoder.encode(this, StandardCharsets.UTF_8)
