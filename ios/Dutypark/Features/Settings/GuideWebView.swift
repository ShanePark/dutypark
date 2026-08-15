import SwiftUI
import UIKit
import WebKit

enum GuideDestination: Equatable {
    case guide
    case releaseNotes
}

struct GuideWebView: View {
    let destination: GuideDestination
    @AppStorage(SettingsPreference.languageKey) private var languageCode = ""
    @State private var loadFailed = false

    var body: some View {
        Group {
            if loadFailed {
                ContentUnavailableView {
                    Label(
                        SettingsLocalization.string("settings.guide.loadError.title"),
                        systemImage: "wifi.exclamationmark"
                    )
                } description: {
                    Text(SettingsLocalization.string("settings.guide.loadError.message"))
                } actions: {
                    Button(SettingsLocalization.string("settings.action.retry")) {
                        loadFailed = false
                    }
                }
            } else {
                DutyparkGuideWebView(
                    destination: destination,
                    languageCode: languageCode,
                    onFailure: { loadFailed = true }
                )
            }
        }
        .navigationTitle(SettingsLocalization.string(titleKey))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titleKey: String {
        destination == .guide ? "settings.guide" : "settings.releaseNotes"
    }
}

nonisolated enum GuideLocaleResolver {
    static func webLocale(languageCode: String, preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        AppLocalization.supportedLocale(
            languageCode: languageCode,
            preferredLanguages: preferredLanguages
        ).identifier
    }
}

nonisolated enum GuideNavigationPolicy {
    static func shouldNavigateHomeNatively(
        _ url: URL,
        interceptsFirstPartyHome: Bool
    ) -> Bool {
        guard interceptsFirstPartyHome else { return false }
        return url.scheme?.lowercased() == "https"
            && url.host?.lowercased() == "dutypark.o-r.kr"
            && (url.path.isEmpty || url.path == "/")
    }
}

struct DutyparkGuideWebView: UIViewRepresentable {
    let destination: GuideDestination
    let languageCode: String
    var onFailure: @MainActor () -> Void = {}
    var onNavigateHome: (@MainActor () -> Void)?

    init(
        destination: GuideDestination,
        languageCode: String,
        onFailure: @escaping @MainActor () -> Void = {},
        onNavigateHome: (@MainActor () -> Void)? = nil
    ) {
        self.destination = destination
        self.languageCode = languageCode
        self.onFailure = onFailure
        self.onNavigateHome = onNavigateHome
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            destination: destination,
            onFailure: onFailure,
            onNavigateHome: onNavigateHome
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let locale = GuideLocaleResolver.webLocale(languageCode: languageCode)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(
            source: "localStorage.setItem('dp-locale', '\(locale)');",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        if onNavigateHome != nil {
            configuration.userContentController.add(
                context.coordinator,
                name: Coordinator.navigateHomeMessageName
            )
            configuration.userContentController.addUserScript(WKUserScript(
                source: Coordinator.navigateHomeScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: URL(string: "https://dutypark.o-r.kr/guide")!))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        static let navigateHomeMessageName = "dutyparkNavigateHome"
        static let navigateHomeScript = """
        document.addEventListener('click', (event) => {
          const target = event.target;
          if (!(target instanceof Element)) return;
          const link = target.closest('a[href]');
          if (!link) return;
          const destination = new URL(link.href, window.location.href);
          if (destination.origin !== window.location.origin || destination.pathname !== '/') return;
          event.preventDefault();
          event.stopImmediatePropagation();
          window.webkit.messageHandlers.dutyparkNavigateHome.postMessage(destination.href);
        }, true);
        """

        let destination: GuideDestination
        let onFailure: @MainActor () -> Void
        let onNavigateHome: (@MainActor () -> Void)?

        init(
            destination: GuideDestination,
            onFailure: @escaping @MainActor () -> Void,
            onNavigateHome: (@MainActor () -> Void)?
        ) {
            self.destination = destination
            self.onFailure = onFailure
            self.onNavigateHome = onNavigateHome
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == Self.navigateHomeMessageName,
                  let value = message.body as? String,
                  let url = URL(string: value),
                  GuideNavigationPolicy.shouldNavigateHomeNatively(
                    url,
                    interceptsFirstPartyHome: onNavigateHome != nil
                  )
            else { return }
            onNavigateHome?()
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation?,
            withError error: Error
        ) {
            onFailure()
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation?,
            withError error: Error
        ) {
            onFailure()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            guard destination == .releaseNotes else { return }
            webView.evaluateJavaScript(
                """
                (() => {
                  const sections = document.querySelectorAll('section');
                  const target = sections[sections.length - 1];
                  const button = target?.querySelector('button');
                  button?.click();
                  setTimeout(() => target?.scrollIntoView(), 100);
                })();
                """
            )
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if GuideNavigationPolicy.shouldNavigateHomeNatively(
                url,
                interceptsFirstPartyHome: onNavigateHome != nil
            ) {
                onNavigateHome?()
                decisionHandler(.cancel)
                return
            }
            let opensNewWindow = navigationAction.targetFrame == nil
            let leavesDutypark = url.host?.lowercased() != "dutypark.o-r.kr"
            if opensNewWindow || leavesDutypark {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
            return nil
        }
    }
}
