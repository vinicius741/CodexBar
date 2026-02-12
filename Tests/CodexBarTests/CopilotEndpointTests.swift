import CodexBarCore
import Testing

@Suite
struct CopilotEndpointTests {
    // MARK: - Default Endpoint

    @Test
    func defaultEndpointUsesGitHub() {
        let endpoint = CopilotEndpoint.default
        #expect(endpoint.baseURL == "github.com")
        #expect(!endpoint.isEnterprise)
    }

    @Test
    func defaultEndpointURLs() {
        let endpoint = CopilotEndpoint.default
        #expect(endpoint.deviceCodeURL.absoluteString == "https://github.com/login/device/code")
        #expect(endpoint.accessTokenURL.absoluteString == "https://github.com/login/oauth/access_token")
        #expect(endpoint.usageAPIURL.absoluteString == "https://api.github.com/copilot_internal/user")
        #expect(endpoint.dashboardURL.absoluteString == "https://github.com/settings/copilot")
    }

    // MARK: - Enterprise Endpoint

    @Test
    func enterpriseEndpointURLs() {
        let endpoint = CopilotEndpoint(baseURL: "octocorp.ghe.com")
        #expect(endpoint.baseURL == "octocorp.ghe.com")
        #expect(endpoint.isEnterprise)
        #expect(endpoint.deviceCodeURL.absoluteString == "https://octocorp.ghe.com/login/device/code")
        #expect(endpoint.accessTokenURL.absoluteString == "https://octocorp.ghe.com/login/oauth/access_token")
        #expect(endpoint.usageAPIURL.absoluteString == "https://api.octocorp.ghe.com/copilot_internal/user")
        #expect(endpoint.dashboardURL.absoluteString == "https://octocorp.ghe.com/settings/copilot")
    }

    // MARK: - URL Normalization - HTTPS Prefix

    @Test
    func stripsHTTPSPrefix() {
        let endpoint = CopilotEndpoint(baseURL: "https://octocorp.ghe.com")
        #expect(endpoint.baseURL == "octocorp.ghe.com")
    }

    @Test
    func stripsHTTPPrefix() {
        let endpoint = CopilotEndpoint(baseURL: "http://octocorp.ghe.com")
        #expect(endpoint.baseURL == "octocorp.ghe.com")
    }

    // MARK: - URL Normalization - Trailing Slashes

    @Test
    func stripsTrailingSlash() {
        let endpoint = CopilotEndpoint(baseURL: "octocorp.ghe.com/")
        #expect(endpoint.baseURL == "octocorp.ghe.com")
    }

    @Test
    func stripsMultipleTrailingSlashes() {
        let endpoint = CopilotEndpoint(baseURL: "octocorp.ghe.com///")
        #expect(endpoint.baseURL == "octocorp.ghe.com")
    }

    // MARK: - URL Normalization - Paths

    @Test
    func stripsPathFromURL() {
        let endpoint = CopilotEndpoint(baseURL: "octocorp.ghe.com/some/path")
        #expect(endpoint.baseURL == "octocorp.ghe.com")
    }

    @Test
    func stripsPathAndTrailingSlash() {
        let endpoint = CopilotEndpoint(baseURL: "octocorp.ghe.com/settings/")
        #expect(endpoint.baseURL == "octocorp.ghe.com")
    }

    // MARK: - URL Normalization - Whitespace

    @Test
    func trimsWhitespace() {
        let endpoint = CopilotEndpoint(baseURL: "  octocorp.ghe.com  ")
        #expect(endpoint.baseURL == "octocorp.ghe.com")
    }

    // MARK: - Empty String Falls Back to Default

    @Test
    func emptyStringFallsBackToGitHub() {
        let endpoint = CopilotEndpoint(baseURL: "")
        #expect(endpoint.baseURL == "github.com")
        #expect(!endpoint.isEnterprise)
    }

    @Test
    func whitespaceOnlyFallsBackToGitHub() {
        let endpoint = CopilotEndpoint(baseURL: "   ")
        #expect(endpoint.baseURL == "github.com")
    }

    // MARK: - API URL Construction

    @Test
    func enterpriseAPIUsesApiPrefix() {
        let endpoint = CopilotEndpoint(baseURL: "company.ghe.com")
        #expect(endpoint.usageAPIURL.host() == "api.company.ghe.com")
    }

    @Test
    func defaultAPIUsesApiGitHub() {
        let endpoint = CopilotEndpoint.default
        #expect(endpoint.usageAPIURL.host() == "api.github.com")
    }
}

@Suite
struct CopilotSettingsReaderTests {
    // MARK: - Enterprise URL from Environment

    @Test
    func enterpriseURLFromEnvironment() {
        let env = [CopilotSettingsReader.enterpriseURLKey: "octocorp.ghe.com"]
        let url = CopilotSettingsReader.enterpriseURL(environment: env)
        #expect(url == "octocorp.ghe.com")
    }

    @Test
    func enterpriseURLTrimsWhitespace() {
        let env = [CopilotSettingsReader.enterpriseURLKey: "  octocorp.ghe.com  "]
        let url = CopilotSettingsReader.enterpriseURL(environment: env)
        #expect(url == "octocorp.ghe.com")
    }

    @Test
    func enterpriseURLReturnsNilWhenMissing() {
        let env: [String: String] = [:]
        let url = CopilotSettingsReader.enterpriseURL(environment: env)
        #expect(url == nil)
    }

    // MARK: - Endpoint Resolution

    @Test
    func resolveEndpointFromEnvironment() {
        let env = [CopilotSettingsReader.enterpriseURLKey: "company.ghe.com"]
        let endpoint = CopilotSettingsReader.resolveEndpoint(environment: env, config: nil)
        #expect(endpoint.baseURL == "company.ghe.com")
        #expect(endpoint.isEnterprise)
    }

    @Test
    func resolveEndpointFromConfig() {
        let config = ProviderConfig(id: .copilot, enterpriseURL: "company.ghe.com")
        let endpoint = CopilotSettingsReader.resolveEndpoint(environment: [:], config: config)
        #expect(endpoint.baseURL == "company.ghe.com")
        #expect(endpoint.isEnterprise)
    }

    @Test
    func environmentOverridesConfig() {
        let env = [CopilotSettingsReader.enterpriseURLKey: "env.ghe.com"]
        let config = ProviderConfig(id: .copilot, enterpriseURL: "config.ghe.com")
        let endpoint = CopilotSettingsReader.resolveEndpoint(environment: env, config: config)
        #expect(endpoint.baseURL == "env.ghe.com")
    }

    @Test
    func resolveEndpointReturnsDefaultWhenMissing() {
        let endpoint = CopilotSettingsReader.resolveEndpoint(environment: [:], config: nil)
        #expect(endpoint.baseURL == "github.com")
        #expect(!endpoint.isEnterprise)
    }

    @Test
    func resolveEndpointReturnsDefaultWhenConfigHasNoEnterpriseURL() {
        let config = ProviderConfig(id: .copilot)
        let endpoint = CopilotSettingsReader.resolveEndpoint(environment: [:], config: config)
        #expect(endpoint.baseURL == "github.com")
    }
}
