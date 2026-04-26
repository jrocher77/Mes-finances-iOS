//
//  ContentView.swift
//  Mes Finances iOS
//
//  Created by JEREMY on 23/04/2026.
//

import SwiftUI
import UIKit
import WebKit

struct ContentView: View {
    var body: some View {
        NativeMigrationShellView()
    }
}

struct WebAppView: UIViewRepresentable {
    private let bridgeName = "iosBridge"

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let userContentController = WKUserContentController()
        userContentController.add(WeakScriptMessageHandler(delegate: context.coordinator), name: bridgeName)
        userContentController.addUserScript(WKUserScript(
            source: iosBridgeScript(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif

        loadLocalWebApp(in: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }

    private func loadLocalWebApp(in webView: WKWebView) {
        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "html") else {
            webView.loadHTMLString(Self.errorHTML(title: "Fichier introuvable", message: "index.html est absent du bundle iOS."), baseURL: nil)
            return
        }

        let readAccessURL = indexURL.deletingLastPathComponent()
        webView.loadFileURL(indexURL, allowingReadAccessTo: readAccessURL)
    }

    private func iosBridgeScript() -> String {
        """
        (() => {
          if (window.MonBudgetIOS) return;
          const post = (type, payload = {}) => {
            try {
              window.webkit.messageHandlers.\(bridgeName).postMessage({ type, payload });
            } catch (_) {}
          };
          window.MonBudgetIOS = Object.freeze({
            ready: () => post("ready"),
            log: (message) => post("log", { message: String(message || "") }),
            haptic: () => post("haptic"),
            openExternal: (url) => post("openExternal", { url: String(url || "") })
          });
        })();
        """
    }

    private static func errorHTML(title: String, message: String) -> String {
        """
        <!doctype html>
        <html lang="fr">
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body {
              margin: 0;
              min-height: 100vh;
              display: grid;
              place-items: center;
              padding: 24px;
              font: -apple-system-body;
              color: #f0ece4;
              background: #0e0f13;
            }
            main { max-width: 420px; }
            h1 { font: -apple-system-title1; margin: 0 0 10px; }
            p { color: rgba(240,236,228,.7); line-height: 1.45; margin: 0; }
          </style>
        </head>
        <body><main><h1>\(title)</h1><p>\(message)</p></main></body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard
                let body = message.body as? [String: Any],
                let type = body["type"] as? String
            else { return }

            let payload = body["payload"] as? [String: Any]

            switch type {
            case "ready":
                #if DEBUG
                print("[MonBudget iOS] Web app ready")
                #endif
            case "log":
                #if DEBUG
                if let text = payload?["message"] as? String {
                    print("[MonBudget Web] \(text)")
                }
                #endif
            case "haptic":
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case "openExternal":
                guard
                    let rawURL = payload?["url"] as? String,
                    let url = URL(string: rawURL)
                else { return }
                openExternalURL(url)
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if shouldOpenExternally(url, navigationType: navigationAction.navigationType) {
                openExternalURL(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showLoadError(error, in: webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showLoadError(error, in: webView)
        }

        private func shouldOpenExternally(_ url: URL, navigationType: WKNavigationType) -> Bool {
            guard navigationType == .linkActivated else { return false }
            guard let scheme = url.scheme?.lowercased() else { return false }
            return ["http", "https", "mailto", "tel"].contains(scheme)
        }

        private func openExternalURL(_ url: URL) {
            DispatchQueue.main.async {
                guard UIApplication.shared.canOpenURL(url) else { return }
                UIApplication.shared.open(url)
            }
        }

        private func showLoadError(_ error: Error, in webView: WKWebView) {
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else { return }
            webView.loadHTMLString(WebAppView.errorHTML(
                title: "Chargement impossible",
                message: error.localizedDescription
            ), baseURL: nil)
        }
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
