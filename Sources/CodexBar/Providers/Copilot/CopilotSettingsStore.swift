import CodexBarCore
import Foundation

extension SettingsStore {
    var copilotAPIToken: String {
        get { self.configSnapshot.providerConfig(for: .copilot)?.sanitizedAPIKey ?? "" }
        set {
            self.updateProviderConfig(provider: .copilot) { entry in
                entry.apiKey = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .copilot, field: "apiKey", value: newValue)
        }
    }

    var copilotEnterpriseURL: String {
        get { self.configSnapshot.providerConfig(for: .copilot)?.enterpriseURL ?? "" }
        set {
            self.updateProviderConfig(provider: .copilot) { entry in
                entry.enterpriseURL = self.normalizedConfigValue(newValue)
            }
        }
    }

    func ensureCopilotAPITokenLoaded() {}
}

extension SettingsStore {
    func copilotSettingsSnapshot() -> ProviderSettingsSnapshot.CopilotProviderSettings {
        let config = self.configSnapshot.providerConfig(for: .copilot)
        return ProviderSettingsSnapshot.CopilotProviderSettings(
            enterpriseURL: config?.enterpriseURL,
            config: config)
    }
}
