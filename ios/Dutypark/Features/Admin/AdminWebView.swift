import Foundation
import SwiftUI
import WebKit

struct AdminAuthenticatedWebView: View {
    let path: String
    let title: String
    @AppStorage(SettingsPreference.languageKey) private var languageCode = ""
    @AppStorage(SettingsPreference.themeKey) private var themeCode = SettingsPreference.defaultTheme
    @Environment(\.colorScheme) private var colorScheme
    @State private var loadFailed = false

    var body: some View {
        Group {
            if loadFailed {
                ContentUnavailableView {
                    Label(
                        AdminLocalization.string("admin.web.loadFailed"),
                        systemImage: "wifi.exclamationmark"
                    )
                } actions: {
                    Button(AdminLocalization.string("admin.common.retry")) {
                        loadFailed = false
                    }
                }
            } else {
                AdminCookieWebView(
                    path: path,
                    preferences: AdminWebPreferences.resolve(
                        languageCode: languageCode,
                        themeCode: themeCode,
                        systemIsDark: colorScheme == .dark
                    ),
                    onFailure: { loadFailed = true }
                )
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("screen.admin.development")
    }
}

nonisolated struct AdminWebPreferences: Equatable, Hashable, Sendable {
    let locale: String
    let theme: String

    static func resolve(
        languageCode: String,
        preferredLanguages: [String] = Locale.preferredLanguages,
        themeCode: String,
        systemIsDark: Bool
    ) -> Self {
        let locale = AppLocalization.supportedLocale(
            languageCode: languageCode,
            preferredLanguages: preferredLanguages
        ).identifier.lowercased().hasPrefix("ko") ? "ko" : "en"

        let theme: String
        switch themeCode {
        case AppTheme.light.rawValue:
            theme = "light"
        case AppTheme.dark.rawValue:
            theme = "dark"
        default:
            theme = systemIsDark ? "dark" : "light"
        }
        return Self(locale: locale, theme: theme)
    }
}

nonisolated enum AdminWebDestination {
    static func url(path: String, apiBaseURL: URL = AppConfiguration.apiBaseURL) -> URL? {
        guard let origin = originURL(apiBaseURL: apiBaseURL) else { return nil }
        return origin.appending(
            path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        )
    }

    static func apiDocumentationURL(apiBaseURL: URL = AppConfiguration.apiBaseURL) -> URL {
        url(path: "docs/index.html", apiBaseURL: apiBaseURL)
            ?? apiBaseURL.appending(path: "docs/index.html")
    }

    static func originURL(apiBaseURL: URL = AppConfiguration.apiBaseURL) -> URL? {
        guard let scheme = apiBaseURL.scheme,
              let host = apiBaseURL.host
        else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = apiBaseURL.port
        return components.url
    }
}

nonisolated enum AdminWebDocumentStartScript {
    static let embeddedSelectors = [
        "header",
        ".footer-shell",
        "div:has(> .admin-top-tile)",
        ".app-layout__main--authed",
    ]

    static func source(allowedOrigin: String, preferences: AdminWebPreferences) -> String {
        let origin = escapedSingleQuoted(allowedOrigin)
        let locale = escapedSingleQuoted(preferences.locale)
        let theme = escapedSingleQuoted(preferences.theme)
        let hiddenSelectors = embeddedSelectors.dropLast().joined(separator: ", ")

        return """
        (() => {
          const expectedOrigin = '\(origin)';
          if (window.location.origin !== expectedOrigin) return;
          const locale = '\(locale)';
          const theme = '\(theme)';
          localStorage.setItem('dp-locale', locale);
          localStorage.setItem('theme', theme);
          document.documentElement.lang = locale;
          document.documentElement.classList.toggle('dark', theme === 'dark');
          document.documentElement.classList.add('dp-ios-embedded');
          const style = document.createElement('style');
          style.id = 'dp-ios-admin-embedded-style';
          style.textContent = `
            \(hiddenSelectors) { display: none !important; }
            .app-layout__main--authed {
              padding-top: 0 !important;
              padding-bottom: 0 !important;
            }
          `;
          (document.head || document.documentElement).appendChild(style);
        })();
        """
    }

    private static func escapedSingleQuoted(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}

private struct AdminCookieWebView: UIViewRepresentable {
    let path: String
    let preferences: AdminWebPreferences
    let onFailure: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFailure: onFailure)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        guard let origin = AdminWebDestination.originURL()?.absoluteString else {
            Task { @MainActor in onFailure() }
            return WKWebView(frame: .zero, configuration: configuration)
        }

        let script = WKUserScript(
            source: AdminWebDocumentStartScript.source(
                allowedOrigin: origin,
                preferences: preferences
            ),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        Task { @MainActor in
            for cookie in HTTPCookieStorage.shared.cookies ?? [] where Self.isDutyparkCookie(cookie) {
                await configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
            }
            guard let url = AdminWebDestination.url(path: path) else {
                onFailure()
                return
            }
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private static func isDutyparkCookie(_ cookie: HTTPCookie) -> Bool {
        guard let host = AppConfiguration.apiBaseURL.host else { return false }
        let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return host == domain || host.hasSuffix(".\(domain)")
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onFailure: @MainActor () -> Void

        init(onFailure: @escaping @MainActor () -> Void) {
            self.onFailure = onFailure
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
            onFailure()
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation?,
            withError error: Error
        ) {
            onFailure()
        }
    }
}
