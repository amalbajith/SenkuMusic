//
//  DownloadView.swift
//  SenkuPlayer
//
//  Created by Amal on 16/01/26.
//

import SwiftUI
import WebKit

struct DownloadView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    header
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(ModernTheme.backgroundPrimary)
                    
                    // Web View
                    ZStack {
                        DownloadWebView(isLoading: $isLoading)
                        
                        if isLoading {
                            loadingView
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(ModernTheme.lightGray)
                    }
                }
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Download Music")
                .font(ModernTheme.heroTitle())
                .foregroundColor(.white)
                .fontWeight(.bold)
            
            Text("Download your favorite songs")
                .font(ModernTheme.caption())
                .foregroundColor(ModernTheme.lightGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(ModernTheme.cardGradient)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 32))
                    .foregroundColor(ModernTheme.accentYellow)
            }
            .shadow(
                color: ModernTheme.accentYellow.opacity(0.3),
                radius: 12,
                x: 0,
                y: 6
            )
            
            VStack(spacing: 8) {
                Text("Loading...")
                    .font(ModernTheme.headline())
                    .foregroundColor(.white)
                
                ProgressView()
                    .tint(ModernTheme.accentYellow)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ModernTheme.backgroundPrimary)
    }
}

// MARK: - Download Web View (Platform Independent)
struct DownloadWebView: PlatformViewRepresentable {
    @Binding var isLoading: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        return createWebView(context: context)
    }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    #else
    func makeUIView(context: Context) -> WKWebView {
        return createWebView(context: context)
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    #endif
    
    private func createWebView(context: Context) -> WKWebView {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences = preferences
        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        #endif
        
        // Add content blocker for ads
        let blockRules = """
        [{
            "trigger": {
                "url-filter": ".*",
                "resource-type": ["image", "style-sheet", "script"],
                "if-domain": ["*doubleclick.net", "*googlesyndication.com", "*googleadservices.com", "*google-analytics.com", "*googletagmanager.com", "*facebook.com/tr", "*facebook.net", "*ads*.com", "*ad*.js", "*analytics*.js", "*tracking*.js", "*adservice*", "*adsystem*"]
            },
            "action": {
                "type": "block"
            }
        }]
        """
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "DownloadContentBlockingRules",
            encodedContentRuleList: blockRules
        ) { contentRuleList, error in
            if let contentRuleList = contentRuleList {
                configuration.userContentController.add(contentRuleList)
            }
        }
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        #if os(iOS)
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false
        webView.scrollView.backgroundColor = UIColor.black
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/120.0.6099.119 Mobile/15E148 Safari/604.1"
        #else
        webView.setValue(false, forKey: "drawsBackground")
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        #endif
        
        // Enable JavaScript
        webView.configuration.preferences.javaScriptEnabled = true
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Load Download Page
        if let url = URL(string: "https://spotidownloader.com/en13") {
            var request = URLRequest(url: url)
            request.setValue("https://www.google.com", forHTTPHeaderField: "Referer")
            request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
            webView.load(request)
        }
        
        return webView
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: DownloadWebView
        
        init(_ parent: DownloadWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    self.parent.isLoading = false
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Navigation failed: \(error.localizedDescription)")
            withAnimation {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation
            decisionHandler(.allow)
        }
    }
}

#Preview {
    DownloadView()
}
