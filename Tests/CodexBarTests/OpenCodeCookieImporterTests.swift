import Foundation
import Testing
@testable import CodexBarCore

@Suite
struct OpenCodeCookieImporterTests {
    #if os(macOS)
    @Test
    func cookieImporterDefaultsToChromeFirst() {
        #expect(OpenCodeCookieImporter.defaultPreferredBrowsers == [.chrome])
    }

    @Test
    func cookieSelectorAcceptsRecognizedAuthCookieVariants() throws {
        let auth = OpenCodeCookieImporter.SessionInfo(
            cookies: [Self.makeCookie(name: "auth", value: "token-auth")],
            sourceLabel: "Chrome Profile A")
        let host = OpenCodeCookieImporter.SessionInfo(
            cookies: [Self.makeCookie(name: "__Host-auth", value: "token-host")],
            sourceLabel: "Chrome Profile B")
        let secure = OpenCodeCookieImporter.SessionInfo(
            cookies: [Self.makeCookie(name: "__Secure-auth", value: "token-secure")],
            sourceLabel: "Chrome Profile C")

        let selected = try OpenCodeCookieImporter.selectSessionInfos(from: [auth, host, secure])
        #expect(selected.map(\.sourceLabel) == ["Chrome Profile A", "Chrome Profile B", "Chrome Profile C"])
    }

    @Test
    func cookieSelectorThrowsWhenNoRecognizedAuthCookieExists() {
        let candidates = [
            OpenCodeCookieImporter.SessionInfo(
                cookies: [Self.makeCookie(name: "analytics_session_id", value: "noise")],
                sourceLabel: "Chrome Profile A"),
            OpenCodeCookieImporter.SessionInfo(
                cookies: [Self.makeCookie(name: "tracking", value: "noise")],
                sourceLabel: "Chrome Profile B"),
        ]

        do {
            _ = try OpenCodeCookieImporter.selectSessionInfo(from: candidates)
            Issue.record("Expected OpenCodeCookieImportError.noCookies")
        } catch OpenCodeCookieImportError.noCookies {
            // expected
        } catch {
            Issue.record("Expected OpenCodeCookieImportError.noCookies, got \(error)")
        }
    }

    @Test
    func cookieSelectorFallsBackWhenEnabled() throws {
        let preferred = [
            OpenCodeCookieImporter.SessionInfo(
                cookies: [Self.makeCookie(name: "analytics_session_id", value: "noise")],
                sourceLabel: "Chrome Profile"),
        ]
        let fallback = [
            OpenCodeCookieImporter.SessionInfo(
                cookies: [Self.makeCookie(name: "auth", value: "token-auth")],
                sourceLabel: "Safari Profile"),
        ]

        let selected = try OpenCodeCookieImporter.selectSessionInfoWithFallback(
            preferredCandidates: preferred,
            allowFallbackBrowsers: true,
            loadFallbackCandidates: { fallback })
        #expect(selected.sourceLabel == "Safari Profile")
    }

    @Test
    func cookieSelectorDoesNotFallbackWhenDisabled() {
        let preferred = [
            OpenCodeCookieImporter.SessionInfo(
                cookies: [Self.makeCookie(name: "analytics_session_id", value: "noise")],
                sourceLabel: "Chrome Profile"),
        ]
        let fallback = [
            OpenCodeCookieImporter.SessionInfo(
                cookies: [Self.makeCookie(name: "auth", value: "token-auth")],
                sourceLabel: "Safari Profile"),
        ]

        do {
            _ = try OpenCodeCookieImporter.selectSessionInfoWithFallback(
                preferredCandidates: preferred,
                allowFallbackBrowsers: false,
                loadFallbackCandidates: { fallback })
            Issue.record("Expected OpenCodeCookieImportError.noCookies")
        } catch OpenCodeCookieImportError.noCookies {
            // expected
        } catch {
            Issue.record("Expected OpenCodeCookieImportError.noCookies, got \(error)")
        }
    }

    private static func makeCookie(
        name: String,
        value: String,
        domain: String = "opencode.ai") -> HTTPCookie
    {
        HTTPCookie(
            properties: [
                .name: name,
                .value: value,
                .domain: domain,
                .path: "/",
            ])!
    }
    #endif
}
