import Foundation

public struct CopilotSettingsReader: Sendable {
    public static let enterpriseURLKey = "GITHUB_ENTERPRISE_URL"

    public static func enterpriseURL(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.cleaned(environment[self.enterpriseURLKey])
    }

    static func cleaned(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
            (value.hasPrefix("'") && value.hasSuffix("'"))
        {
            value.removeFirst()
            value.removeLast()
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    public static func resolveEndpoint(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        config: ProviderConfig?) -> CopilotEndpoint
    {
        // Environment variable takes precedence
        if let envURL = self.enterpriseURL(environment: environment), !envURL.isEmpty {
            return CopilotEndpoint(baseURL: envURL)
        }

        // Fall back to config
        if let configURL = config?.enterpriseURL, !configURL.isEmpty {
            return CopilotEndpoint(baseURL: configURL)
        }

        return .default
    }
}
