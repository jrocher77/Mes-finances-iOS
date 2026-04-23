//
//  ContentView.swift
//  Mes Finances iOS
//
//  Created by JEREMY on 23/04/2026.
//

import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        WebAppView()
            .ignoresSafeArea(.container, edges: .bottom)
    }
}

private struct WebAppView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        loadLocalWebApp(in: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }

    private func loadLocalWebApp(in webView: WKWebView) {
        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "html") else {
            webView.loadHTMLString("<h1>Erreur</h1><p>index.html introuvable dans le bundle.</p>", baseURL: nil)
            return
        }

        let readAccessURL = indexURL.deletingLastPathComponent()
        webView.loadFileURL(indexURL, allowingReadAccessTo: readAccessURL)
    }
}

#Preview {
    ContentView()
}
