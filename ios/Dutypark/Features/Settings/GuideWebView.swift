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

struct DutyparkGuideWebView: UIViewRepresentable {
    let destination: GuideDestination
    let languageCode: String
    var onFailure: @MainActor () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(destination: destination, onFailure: onFailure)
    }

    func makeUIView(context: Context) -> WKWebView {
        let locale = GuideLocaleResolver.webLocale(languageCode: languageCode)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(
            source: "localStorage.setItem('dp-locale', '\(locale)');",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: URL(string: "https://dutypark.o-r.kr/guide")!))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let destination: GuideDestination
        let onFailure: @MainActor () -> Void

        init(destination: GuideDestination, onFailure: @escaping @MainActor () -> Void) {
            self.destination = destination
            self.onFailure = onFailure
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
