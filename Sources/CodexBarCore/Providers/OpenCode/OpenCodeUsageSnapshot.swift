import Foundation

public struct OpenCodeUsageSnapshot: Sendable {
    public let rollingUsagePercent: Double
    public let weeklyUsagePercent: Double
    public let rollingResetInSec: Int
    public let weeklyResetInSec: Int
    public let planName: String?
    public let updatedAt: Date

    public init(
        rollingUsagePercent: Double,
        weeklyUsagePercent: Double,
        rollingResetInSec: Int,
        weeklyResetInSec: Int,
        planName: String? = nil,
        updatedAt: Date)
    {
        self.rollingUsagePercent = rollingUsagePercent
        self.weeklyUsagePercent = weeklyUsagePercent
        self.rollingResetInSec = rollingResetInSec
        self.weeklyResetInSec = weeklyResetInSec
        self.planName = planName
        self.updatedAt = updatedAt
    }

    public func toUsageSnapshot() -> UsageSnapshot {
        let rollingReset = self.updatedAt.addingTimeInterval(TimeInterval(self.rollingResetInSec))
        let weeklyReset = self.updatedAt.addingTimeInterval(TimeInterval(self.weeklyResetInSec))
        let normalizedPlan = self.planName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Existing provider convention: expose subscription tier via `loginMethod` so shared UI renders "Plan".
        let loginMethod = (normalizedPlan?.isEmpty ?? true) ? nil : normalizedPlan
        let identity: ProviderIdentitySnapshot? = if let loginMethod {
            ProviderIdentitySnapshot(
                providerID: .opencode,
                accountEmail: nil,
                accountOrganization: nil,
                loginMethod: loginMethod)
        } else {
            nil
        }

        let primary = RateWindow(
            usedPercent: self.rollingUsagePercent,
            windowMinutes: 5 * 60,
            resetsAt: rollingReset,
            resetDescription: nil)
        let secondary = RateWindow(
            usedPercent: self.weeklyUsagePercent,
            windowMinutes: 7 * 24 * 60,
            resetsAt: weeklyReset,
            resetDescription: nil)

        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            updatedAt: self.updatedAt,
            identity: identity)
    }
}
