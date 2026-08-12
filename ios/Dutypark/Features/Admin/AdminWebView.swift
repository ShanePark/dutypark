import SwiftUI
import WebKit

struct AdminAuthenticatedWebView: View {
    let path: String
    let title: String
    @State private var loadFailed = false

    var body: some View {
        Group {
            if loadFailed {
                ContentUnavailableView {
                    Label(AdminLocalization.string("admin.web.loadFailed"), systemImage: "wifi.exclamationmark")
                } actions: {
                    Button(AdminLocalization.string("admin.common.retry")) { loadFailed = false }
                }
            } else {
                AdminCookieWebView(path: path, onFailure: { loadFailed = true })
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AdminCookieWebView: UIViewRepresentable {
    let path: String
    let onFailure: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFailure: onFailure)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        Task { @MainActor in
            for cookie in HTTPCookieStorage.shared.cookies ?? [] where Self.isDutyparkCookie(cookie) {
                await configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
            }
            guard let url = Self.destinationURL(path: path) else {
                onFailure()
                return
            }
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func destinationURL(path: String) -> URL? {
        let origin = AppConfiguration.apiBaseURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return origin.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

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
