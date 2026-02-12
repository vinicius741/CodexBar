import Foundation

public struct CopilotEndpoint: Sendable {
    public let baseURL: String

    public static let `default` = CopilotEndpoint(baseURL: "github.com")

    public init(baseURL: String) {
        var normalized = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty {
            normalized = "github.com"
        } else {
            // Strip https:// prefix
            if normalized.lowercased().hasPrefix("https://") {
                normalized = String(normalized.dropFirst(8))
            } else if normalized.lowercased().hasPrefix("http://") {
                normalized = String(normalized.dropFirst(7))
            }

            // Strip trailing slashes and paths
            if let slashIndex = normalized.firstIndex(of: "/") {
                normalized = String(normalized[..<slashIndex])
            }

            normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        self.baseURL = normalized
    }

    public var deviceCodeURL: URL {
        URL(string: "https://\(self.baseURL)/login/device/code")!
    }

    public var accessTokenURL: URL {
        URL(string: "https://\(self.baseURL)/login/oauth/access_token")!
    }

    public var usageAPIURL: URL {
        // For GitHub Enterprise, API is at api.SUBDOMAIN.ghe.com
        let apiHost: String
        if self.baseURL == "github.com" {
            apiHost = "api.github.com"
        } else {
            apiHost = "api.\(self.baseURL)"
        }
        return URL(string: "https://\(apiHost)/copilot_internal/user")!
    }

    public var dashboardURL: URL {
        URL(string: "https://\(self.baseURL)/settings/copilot")!
    }

    public var isEnterprise: Bool {
        self.baseURL != "github.com"
    }
}
