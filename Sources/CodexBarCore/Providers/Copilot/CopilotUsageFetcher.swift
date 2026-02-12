import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct CopilotUsageFetcher: Sendable {
    private let token: String
    private let endpoint: CopilotEndpoint

    public init(token: String, endpoint: CopilotEndpoint = .default) {
        self.token = token
        self.endpoint = endpoint
    }

    public func fetch() async throws -> UsageSnapshot {
        let url = self.endpoint.usageAPIURL

        var request = URLRequest(url: url)
        // Use the GitHub OAuth token directly, not the Copilot token.
        request.setValue("token \(self.token)", forHTTPHeaderField: "Authorization")
        self.addCommonHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        }

        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let usage = try JSONDecoder().decode(CopilotUsageResponse.self, from: data)

        let resetDate = Self.parseResetDate(usage.quotaResetDate)
        let primary = self.makeRateWindow(from: usage.quotaSnapshots.premiumInteractions, resetsAt: resetDate)
        let secondary = self.makeRateWindow(from: usage.quotaSnapshots.chat, resetsAt: resetDate)

        let identity = ProviderIdentitySnapshot(
            providerID: .copilot,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: usage.copilotPlan.capitalized)
        return UsageSnapshot(
            primary: primary ?? .init(usedPercent: 0, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
            secondary: secondary,
            tertiary: nil,
            providerCost: nil,
            updatedAt: Date(),
            identity: identity)
    }

    private static func parseResetDate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Try ISO8601 with fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: trimmed) { return date }

        // Try ISO8601 without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: trimmed) { return date }

        // Try date-only format (YYYY-MM-DD) - assume end of day UTC
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        if let date = dateFormatter.date(from: trimmed) {
            // Set to end of day (23:59:59 UTC)
            var components = DateComponents()
            components.hour = 23
            components.minute = 59
            components.second = 59
            return Calendar(identifier: .gregorian).date(byAdding: components, to: date)
        }

        return nil
    }

    private func addCommonHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("vscode/1.96.2", forHTTPHeaderField: "Editor-Version")
        request.setValue("copilot-chat/0.26.7", forHTTPHeaderField: "Editor-Plugin-Version")
        request.setValue("GitHubCopilotChat/0.26.7", forHTTPHeaderField: "User-Agent")
        request.setValue("2025-04-01", forHTTPHeaderField: "X-Github-Api-Version")
    }

    private func makeRateWindow(from snapshot: CopilotUsageResponse.QuotaSnapshot?, resetsAt: Date?) -> RateWindow? {
        guard let snapshot else { return nil }
        // percent_remaining is 0-100 based on the JSON example in the web app source
        let usedPercent = max(0, 100 - snapshot.percentRemaining)
        let resetDescription = resetsAt.map { UsageFormatter.resetDescription(from: $0) }

        return RateWindow(
            usedPercent: usedPercent,
            windowMinutes: nil,
            resetsAt: resetsAt,
            resetDescription: resetDescription)
    }
}
