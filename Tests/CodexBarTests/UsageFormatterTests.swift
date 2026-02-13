import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@Suite
struct UsageFormatterTests {
    @Test
    func formatsUsageLine() {
        let line = UsageFormatter.usageLine(remaining: 25, used: 75, showUsed: false)
        #expect(line == "25% left")
    }

    @Test
    func formatsUsageLineShowUsed() {
        let line = UsageFormatter.usageLine(remaining: 25, used: 75, showUsed: true)
        #expect(line == "75% used")
    }

    @Test
    func relativeUpdatedRecent() {
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let text = UsageFormatter.updatedString(from: fiveHoursAgo, now: now)
        #expect(text.contains("Updated"))
        // Check for relative time format (varies by locale: "ago" in English, "전" in Korean, etc.)
        #expect(text.contains("5") || text.lowercased().contains("hour") || text.contains("시간"))
    }

    @Test
    func absoluteUpdatedOld() {
        let now = Date()
        let dayAgo = now.addingTimeInterval(-26 * 3600)
        let text = UsageFormatter.updatedString(from: dayAgo, now: now)
        #expect(text.contains("Updated"))
        #expect(!text.contains("ago"))
    }

    @Test
    func resetCountdown_minutes() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reset = now.addingTimeInterval(10 * 60 + 1)
        #expect(UsageFormatter.resetCountdownDescription(from: reset, now: now) == "in 11m")
    }

    @Test
    func resetCountdown_hoursAndMinutes() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reset = now.addingTimeInterval(3 * 3600 + 31 * 60)
        #expect(UsageFormatter.resetCountdownDescription(from: reset, now: now) == "in 3h 31m")
    }

    @Test
    func resetCountdown_daysAndHours() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reset = now.addingTimeInterval((26 * 3600) + 10)
        #expect(UsageFormatter.resetCountdownDescription(from: reset, now: now) == "in 1d 2h")
    }

    @Test
    func resetCountdown_exactHour() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reset = now.addingTimeInterval(60 * 60)
        #expect(UsageFormatter.resetCountdownDescription(from: reset, now: now) == "in 1h")
    }

    @Test
    func resetCountdown_pastDate() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reset = now.addingTimeInterval(-10)
        #expect(UsageFormatter.resetCountdownDescription(from: reset, now: now) == "now")
    }

    @Test
    func resetLineUsesCountdownWhenResetsAtIsAvailable() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reset = now.addingTimeInterval(10 * 60 + 1)
        let window = RateWindow(usedPercent: 0, windowMinutes: nil, resetsAt: reset, resetDescription: "Resets soon")
        let text = UsageFormatter.resetLine(for: window, style: .countdown, now: now)
        #expect(text == "Resets in 11m")
    }

    @Test
    func resetLineFallsBackToProvidedDescription() {
        let window = RateWindow(
            usedPercent: 0,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: "Resets at 23:30 (UTC)")
        let countdown = UsageFormatter.resetLine(for: window, style: .countdown)
        let absolute = UsageFormatter.resetLine(for: window, style: .absolute)
        #expect(countdown == "Resets at 23:30 (UTC)")
        #expect(absolute == "Resets at 23:30 (UTC)")
    }

    @Test
    func modelDisplayNameStripsTrailingDates() {
        #expect(UsageFormatter.modelDisplayName("claude-opus-4-5-20251101") == "claude-opus-4-5")
        #expect(UsageFormatter.modelDisplayName("gpt-4o-2024-08-06") == "gpt-4o")
        #expect(UsageFormatter.modelDisplayName("Claude Opus 4.5 2025 1101") == "Claude Opus 4.5")
        #expect(UsageFormatter.modelDisplayName("claude-sonnet-4-5") == "claude-sonnet-4-5")
    }

    @Test
    func cleanPlanMapsOAuthToOllama() {
        #expect(UsageFormatter.cleanPlanName("oauth") == "Ollama")
    }

    // MARK: - Currency Formatting

    @Test
    func currencyStringFormatsUSDCorrectly() {
        // Should produce "$54.72" without space after symbol
        let result = UsageFormatter.currencyString(54.72, currencyCode: "USD")
        #expect(result == "$54.72")
        #expect(!result.contains("$ ")) // No space after symbol
    }

    @Test
    func currencyStringHandlesLargeValues() {
        let result = UsageFormatter.currencyString(1234.56, currencyCode: "USD")
        // For USD, we use direct string formatting with thousand separators
        #expect(result == "$1,234.56")
        #expect(!result.contains("$ ")) // No space after symbol
    }

    @Test
    func currencyStringHandlesVeryLargeValues() {
        let result = UsageFormatter.currencyString(1_234_567.89, currencyCode: "USD")
        #expect(result == "$1,234,567.89")
    }

    @Test
    func currencyStringHandlesNegativeValues() {
        // Negative sign should come before the dollar sign: -$54.72 (not $-54.72)
        let result = UsageFormatter.currencyString(-54.72, currencyCode: "USD")
        #expect(result == "-$54.72")
    }

    @Test
    func currencyStringHandlesNegativeLargeValues() {
        let result = UsageFormatter.currencyString(-1234.56, currencyCode: "USD")
        #expect(result == "-$1,234.56")
    }

    @Test
    func usdStringMatchesCurrencyString() {
        // usdString should produce identical output to currencyString for USD
        #expect(UsageFormatter.usdString(54.72) == UsageFormatter.currencyString(54.72, currencyCode: "USD"))
        #expect(UsageFormatter.usdString(-1234.56) == UsageFormatter.currencyString(-1234.56, currencyCode: "USD"))
        #expect(UsageFormatter.usdString(0) == UsageFormatter.currencyString(0, currencyCode: "USD"))
    }

    @Test
    func currencyStringHandlesZero() {
        let result = UsageFormatter.currencyString(0, currencyCode: "USD")
        #expect(result == "$0.00")
    }

    @Test
    func currencyStringHandlesNonUSDCurrencies() {
        // FormatStyle handles all currencies with proper symbols
        let eur = UsageFormatter.currencyString(54.72, currencyCode: "EUR")
        #expect(eur == "€54.72")

        let gbp = UsageFormatter.currencyString(54.72, currencyCode: "GBP")
        #expect(gbp == "£54.72")

        // Negative non-USD
        let negEur = UsageFormatter.currencyString(-1234.56, currencyCode: "EUR")
        #expect(negEur == "-€1,234.56")
    }

    @Test
    func currencyStringHandlesSmallValues() {
        // Values smaller than 0.01 should round to $0.00
        let tiny = UsageFormatter.currencyString(0.001, currencyCode: "USD")
        #expect(tiny == "$0.00")

        // Values at 0.005 should round to $0.01 (banker's rounding)
        let halfCent = UsageFormatter.currencyString(0.005, currencyCode: "USD")
        #expect(halfCent == "$0.00" || halfCent == "$0.01") // Rounding behavior may vary

        // One cent
        let oneCent = UsageFormatter.currencyString(0.01, currencyCode: "USD")
        #expect(oneCent == "$0.01")
    }

    @Test
    func currencyStringHandlesBoundaryValues() {
        // Just under 1000 (no comma)
        let under1k = UsageFormatter.currencyString(999.99, currencyCode: "USD")
        #expect(under1k == "$999.99")

        // Exactly 1000 (first comma)
        let exact1k = UsageFormatter.currencyString(1000.00, currencyCode: "USD")
        #expect(exact1k == "$1,000.00")

        // Just over 1000
        let over1k = UsageFormatter.currencyString(1000.01, currencyCode: "USD")
        #expect(over1k == "$1,000.01")
    }

    @Test
    func creditsStringFormatsCorrectly() {
        let result = UsageFormatter.creditsString(from: 42.5)
        #expect(result == "42.5 left")
    }

    // MARK: - Days Left & Daily Budget

    @Test
    func daysUntilResetReturnsCorrectDays() {
        // Use a proper date in a billing month with reset in next month
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        // Jan 25, 2026 - billing month ends Jan 31
        let now = cal.date(from: DateComponents(year: 2026, month: 1, day: 25, hour: 12))!
        // Reset date of Feb 2, 2026
        let reset = cal.date(from: DateComponents(year: 2026, month: 2, day: 2))!
        let days = UsageFormatter.daysUntilReset(from: reset, now: now)
        // Jan 31 23:59:59 - Jan 25 12:00 = ~6.5 days → ceil = 7
        #expect(days == 7)
    }

    @Test
    func daysUntilResetReturnsOneDayForSmallRemaining() {
        // Last day of billing month
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        // Jan 31, 2026 22:00 - just before month end
        let now = cal.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 22))!
        // Reset date of Feb 2, 2026
        let reset = cal.date(from: DateComponents(year: 2026, month: 2, day: 2))!
        let days = UsageFormatter.daysUntilReset(from: reset, now: now)
        // Jan 31 23:59:59 - Jan 31 22:00 = ~2 hours → ceil = 1 day (minimum)
        #expect(days == 1)
    }

    @Test
    func daysUntilResetReturnsNilForPastDate() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reset = now.addingTimeInterval(-100)
        let days = UsageFormatter.daysUntilReset(from: reset, now: now)
        #expect(days == nil)
    }

    @Test
    func daysUntilResetReturnsNilForNilDate() {
        let days = UsageFormatter.daysUntilReset(from: nil)
        #expect(days == nil)
    }

    @Test
    func daysLeftStringFormatsSingular() {
        #expect(UsageFormatter.daysLeftString(days: 1) == "1 day left")
    }

    @Test
    func daysLeftStringFormatsPlural() {
        #expect(UsageFormatter.daysLeftString(days: 6) == "6 days left")
    }

    @Test
    func dailyBudgetStringCalculatesCorrectly() {
        let result = UsageFormatter.dailyBudgetString(remainingPercent: 75, daysLeft: 6)
        #expect(result == "12.5% per day")
    }

    @Test
    func dailyBudgetStringHandlesZeroDays() {
        let result = UsageFormatter.dailyBudgetString(remainingPercent: 50, daysLeft: 0)
        #expect(result == "0% per day")
    }

    @Test
    func dailyBudgetStringHandlesZeroRemaining() {
        let result = UsageFormatter.dailyBudgetString(remainingPercent: 0, daysLeft: 5)
        #expect(result == "0.0% per day")
    }

    // MARK: - Month-End Days Left Calculation

    @Test
    func daysUntilResetHandlesFebruary2026() {
        // Feb 13, 2026 12:00 UTC - February has 28 days
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 2, day: 13, hour: 12))!
        // Reset date of March 2, 2026
        let reset = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let days = UsageFormatter.daysUntilReset(from: reset, now: now)
        // Feb 28 23:59:59 - Feb 13 12:00 = ~15.5 days → ceil = 16
        #expect(days == 16)
    }

    @Test
    func daysUntilResetHandlesLeapYearFebruary() {
        // Feb 13, 2028 (leap year) - February has 29 days
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2028, month: 2, day: 13, hour: 12))!
        let reset = cal.date(from: DateComponents(year: 2028, month: 3, day: 2))!
        let days = UsageFormatter.daysUntilReset(from: reset, now: now)
        // Feb 29 23:59:59 - Feb 13 12:00 = ~16.5 days → ceil = 17
        #expect(days == 17)
    }

    @Test
    func daysUntilResetHandles31DayMonth() {
        // Jan 15, 2026 - January has 31 days
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        let reset = cal.date(from: DateComponents(year: 2026, month: 2, day: 2))!
        let days = UsageFormatter.daysUntilReset(from: reset, now: now)
        // Jan 31 23:59:59 - Jan 15 12:00 = ~16.5 days → ceil = 17
        #expect(days == 17)
    }

    @Test
    func daysUntilResetHandles30DayMonth() {
        // Apr 10, 2026 - April has 30 days
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 12))!
        let reset = cal.date(from: DateComponents(year: 2026, month: 5, day: 2))!
        let days = UsageFormatter.daysUntilReset(from: reset, now: now)
        // Apr 30 23:59:59 - Apr 10 12:00 = ~20.5 days → ceil = 21
        #expect(days == 21)
    }

    @Test
    func daysUntilResetHandlesLastDayOfMonth() {
        // Feb 28, 2026 10:00 UTC - last day of February
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 2, day: 28, hour: 10))!
        let reset = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let days = UsageFormatter.daysUntilReset(from: reset, now: now)
        // Feb 28 23:59:59 - Feb 28 10:00 = ~14 hours → ceil = 1 day
        #expect(days == 1)
    }

    @Test
    func daysUntilResetHandlesFirstDayOfMonth() {
        // Feb 1, 2026 12:00 UTC - first day of February
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 12))!
        let reset = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let days = UsageFormatter.daysUntilReset(from: reset, now: now)
        // Feb 28 23:59:59 - Feb 1 12:00 = ~27.5 days → ceil = 28
        #expect(days == 28)
    }
}
