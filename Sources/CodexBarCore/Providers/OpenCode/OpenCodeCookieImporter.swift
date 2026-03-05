import Foundation

#if os(macOS)
import SweetCookieKit

private let opencodeCookieImportOrder: BrowserCookieImportOrder =
    ProviderDefaults.metadata[.opencode]?.browserCookieOrder ?? Browser.defaultImportOrder

public enum OpenCodeCookieImporter {
    private static let cookieClient = BrowserCookieClient()
    private static let cookieDomains = ["opencode.ai", "app.opencode.ai"]
    public static let defaultPreferredBrowsers: [Browser] = [.chrome]
    private static let sessionCookieNames: Set<String> = [
        "auth",
        "__Host-auth",
        "__Secure-auth",
    ]

    public struct SessionInfo: Sendable {
        public let cookies: [HTTPCookie]
        public let sourceLabel: String

        public init(cookies: [HTTPCookie], sourceLabel: String) {
            self.cookies = cookies
            self.sourceLabel = sourceLabel
        }

        public var cookieHeader: String {
            self.cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        }
    }

    public static func importSession(
        browserDetection: BrowserDetection,
        preferredBrowsers: [Browser] = defaultPreferredBrowsers,
        allowFallbackBrowsers: Bool = true,
        logger: ((String) -> Void)? = nil) throws -> SessionInfo
    {
        let log: (String) -> Void = { msg in logger?("[opencode-cookie] \(msg)") }
        let preferredSources = self.browserSources(
            browserDetection: browserDetection,
            preferredBrowsers: preferredBrowsers,
            refreshIfNeeded: true)
        let preferredCandidates = self.collectSessionInfo(from: preferredSources, logger: log)
        return try self.selectSessionInfoWithFallback(
            preferredCandidates: preferredCandidates,
            allowFallbackBrowsers: allowFallbackBrowsers,
            loadFallbackCandidates: {
                guard !preferredBrowsers.isEmpty else { return [] }
                let fallbackSources = self.fallbackBrowserSources(
                    browserDetection: browserDetection,
                    excluding: preferredSources)
                guard !fallbackSources.isEmpty else { return [] }
                log("No recognized OpenCode auth cookie in preferred browsers; trying fallback import order")
                return self.collectSessionInfo(from: fallbackSources, logger: log)
            },
            logger: log)
    }

    public static func hasSession(
        browserDetection: BrowserDetection,
        preferredBrowsers: [Browser] = defaultPreferredBrowsers,
        allowFallbackBrowsers: Bool = true,
        logger: ((String) -> Void)? = nil) -> Bool
    {
        do {
            _ = try self.importSession(
                browserDetection: browserDetection,
                preferredBrowsers: preferredBrowsers,
                allowFallbackBrowsers: allowFallbackBrowsers,
                logger: logger)
            return true
        } catch {
            return false
        }
    }

    static func selectSessionInfo(from candidates: [SessionInfo], logger: ((String) -> Void)? = nil) throws -> SessionInfo {
        guard let first = try self.selectSessionInfos(from: candidates, logger: logger).first else {
            throw OpenCodeCookieImportError.noCookies
        }
        return first
    }

    static func selectSessionInfos(
        from candidates: [SessionInfo],
        logger: ((String) -> Void)? = nil) throws -> [SessionInfo]
    {
        var recognized: [SessionInfo] = []
        for candidate in candidates {
            let names = candidate.cookies.map(\.name).joined(separator: ", ")
            logger?("\(candidate.sourceLabel) cookies: \(names)")
            if self.containsRecognizedSessionCookie(in: candidate.cookies) {
                logger?("Found OpenCode auth cookie in \(candidate.sourceLabel)")
                recognized.append(candidate)
            } else {
                logger?("\(candidate.sourceLabel) cookies found, but no recognized OpenCode auth cookie present")
                logger?("Expected one of: \(Self.sessionCookieNames.sorted().joined(separator: ", "))")
            }
        }

        guard !recognized.isEmpty else {
            throw OpenCodeCookieImportError.noCookies
        }
        return recognized
    }

    static func selectSessionInfoWithFallback(
        preferredCandidates: [SessionInfo],
        allowFallbackBrowsers: Bool,
        loadFallbackCandidates: () -> [SessionInfo],
        logger: ((String) -> Void)? = nil) throws -> SessionInfo
    {
        guard allowFallbackBrowsers else {
            return try self.selectSessionInfo(from: preferredCandidates, logger: logger)
        }
        do {
            return try self.selectSessionInfo(from: preferredCandidates, logger: logger)
        } catch OpenCodeCookieImportError.noCookies {
            let fallbackCandidates = loadFallbackCandidates()
            return try self.selectSessionInfo(from: fallbackCandidates, logger: logger)
        }
    }

    private static func browserSources(
        browserDetection: BrowserDetection,
        preferredBrowsers: [Browser],
        refreshIfNeeded: Bool) -> [Browser]
    {
        let browsers = preferredBrowsers.isEmpty ? opencodeCookieImportOrder : preferredBrowsers
        return self.resolveBrowserSources(
            inOrder: browsers,
            browserDetection: browserDetection,
            refreshIfNeeded: refreshIfNeeded)
    }

    private static func fallbackBrowserSources(
        browserDetection: BrowserDetection,
        excluding triedSources: [Browser]) -> [Browser]
    {
        let tried = Set(triedSources)
        let fallbackOrder = opencodeCookieImportOrder.filter { !tried.contains($0) }
        return self.resolveBrowserSources(
            inOrder: fallbackOrder,
            browserDetection: browserDetection,
            refreshIfNeeded: true)
    }

    private static func collectSessionInfo(
        from browserSources: [Browser],
        logger: @escaping (String) -> Void) -> [SessionInfo]
    {
        var candidates: [SessionInfo] = []
        for browserSource in browserSources {
            do {
                let query = BrowserCookieQuery(domains: self.cookieDomains)
                let sources = try Self.cookieClient.records(
                    matching: query,
                    in: browserSource,
                    logger: logger)
                if sources.isEmpty {
                    logger("No OpenCode cookie stores returned for \(browserSource.displayName)")
                }
                for source in sources where !source.records.isEmpty {
                    let cookies = self.makeCookies(
                        from: source.records,
                        origin: query.origin,
                        sourceLabel: source.label,
                        logger: logger)
                    guard !cookies.isEmpty else { continue }
                    candidates.append(SessionInfo(cookies: cookies, sourceLabel: source.label))
                }
            } catch {
                BrowserCookieAccessGate.recordIfNeeded(error)
                logger("\(browserSource.displayName) cookie import failed: \(error.localizedDescription)")
            }
        }
        return candidates
    }

    private static func containsRecognizedSessionCookie(in cookies: [HTTPCookie]) -> Bool {
        cookies.contains { cookie in
            self.sessionCookieNames.contains(cookie.name)
        }
    }

    private static func resolveBrowserSources(
        inOrder browsers: [Browser],
        browserDetection: BrowserDetection,
        refreshIfNeeded: Bool) -> [Browser]
    {
        var resolved: [Browser] = []
        self.appendUniqueBrowsers(
            from: browsers.cookieImportCandidates(using: browserDetection),
            into: &resolved)
        if resolved.isEmpty, refreshIfNeeded {
            browserDetection.clearCache()
            self.appendUniqueBrowsers(
                from: browsers.cookieImportCandidates(using: browserDetection),
                into: &resolved)
        }
        if !resolved.isEmpty {
            return resolved
        }

        // Last-resort fallback: include installed/profile-backed browsers even if gate heuristics suppress them.
        // This avoids false negatives when detection cache/gating state is stale.
        self.appendUniqueBrowsers(
            from: self.aggressiveBrowserSources(
                inOrder: browsers,
                browserDetection: browserDetection),
            into: &resolved)
        return resolved
    }

    private static func aggressiveBrowserSources(
        inOrder browsers: [Browser],
        browserDetection: BrowserDetection) -> [Browser]
    {
        browsers.filter { browser in
            if browser == .safari { return true }
            return browserDetection.hasUsableProfileData(browser) || browserDetection.isAppInstalled(browser)
        }
    }

    private static func appendUniqueBrowsers(from sources: [Browser], into result: inout [Browser]) {
        var seen = Set(result)
        for source in sources where !seen.contains(source) {
            result.append(source)
            seen.insert(source)
        }
    }

    private static func makeCookies(
        from records: [BrowserCookieRecord],
        origin: BrowserCookieOriginStrategy,
        sourceLabel: String,
        logger: @escaping (String) -> Void) -> [HTTPCookie]
    {
        var cookies = BrowserCookieClient.makeHTTPCookies(records, origin: origin)
        var names = Set(cookies.map { $0.name })

        // Preserve recognized auth cookies even when origin-filtered conversion omits host-scoped variants.
        for record in records where self.sessionCookieNames.contains(record.name) {
            guard !names.contains(record.name), let cookie = self.makeCookie(from: record) else { continue }
            cookies.append(cookie)
            names.insert(record.name)
            logger("Recovered \(record.name) from raw cookie record for \(sourceLabel)")
        }

        if !cookies.isEmpty {
            return cookies
        }

        // If conversion yields nothing, synthesize a minimal cookie set from raw records for header transport.
        let synthesized = records.compactMap(self.makeCookie(from:))
        if !synthesized.isEmpty {
            logger("Using synthesized OpenCode cookies for \(sourceLabel)")
        }
        return synthesized
    }

    private static func makeCookie(from record: BrowserCookieRecord) -> HTTPCookie? {
        guard !record.name.isEmpty else { return nil }
        guard !record.value.isEmpty else { return nil }
        let domain = record.domain.isEmpty ? "opencode.ai" : record.domain
        let path = record.path.isEmpty ? "/" : record.path
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: record.name,
            .value: record.value,
            .domain: domain,
            .path: path,
        ]
        if let expires = record.expires {
            properties[.expires] = expires
        }
        return HTTPCookie(properties: properties)
    }
}

enum OpenCodeCookieImportError: LocalizedError {
    case noCookies

    var errorDescription: String? {
        switch self {
        case .noCookies:
            "No OpenCode session cookies found in browsers."
        }
    }
}
#endif
