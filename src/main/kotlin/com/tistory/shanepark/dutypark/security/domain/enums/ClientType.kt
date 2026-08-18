package com.tistory.shanepark.dutypark.security.domain.enums

/**
 * Client a session was created from, so session lists can tell the native app apart from a browser.
 */
enum class ClientType {
    BROWSER,
    IOS_APP,
    ;

    companion object {
        /**
         * The native app sends no client header, so it is recognised by the user agent CFNetwork
         * derives from its bundle: "Dutypark/<build> CFNetwork/<version> Darwin/<version>".
         * Both markers are required so that a browser merely mentioning the product name stays BROWSER.
         */
        private const val NATIVE_APP_PREFIX = "Dutypark/"
        private const val NATIVE_APP_MARKER = "CFNetwork/"

        fun fromUserAgent(userAgent: String?): ClientType {
            if (userAgent == null) return BROWSER
            val isNativeApp = userAgent.startsWith(NATIVE_APP_PREFIX) && userAgent.contains(NATIVE_APP_MARKER)
            return if (isNativeApp) IOS_APP else BROWSER
        }
    }
}
