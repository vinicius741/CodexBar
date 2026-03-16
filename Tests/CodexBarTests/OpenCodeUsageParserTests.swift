import Foundation
import Testing
@testable import CodexBarCore

struct OpenCodeUsageParserTests {
    @Test
    func `parses workspace I ds`() {
        let text = ";0x00000089;((self.$R=self.$R||{})[\"codexbar\"]=[]," +
            "($R=>$R[0]=[$R[1]={id:\"wrk_01K6AR1ZET89H8NB691FQ2C2VB\",name:\"Default\",slug:null}])" +
            "($R[\"codexbar\"]))"
        let ids = OpenCodeUsageFetcher.parseWorkspaceIDs(text: text)
        #expect(ids == ["wrk_01K6AR1ZET89H8NB691FQ2C2VB"])
    }

    @Test
    func `parses subscription usage`() throws {
        let text = "$R[16]($R[30],$R[41]={rollingUsage:$R[42]={status:\"ok\",resetInSec:5944,usagePercent:17}," +
            "weeklyUsage:$R[43]={status:\"ok\",resetInSec:278201,usagePercent:75}});"
        let now = Date(timeIntervalSince1970: 0)
        let snapshot = try OpenCodeUsageFetcher.parseSubscription(text: text, now: now)
        #expect(snapshot.rollingUsagePercent == 17)
        #expect(snapshot.weeklyUsagePercent == 75)
        #expect(snapshot.rollingResetInSec == 5944)
        #expect(snapshot.weeklyResetInSec == 278_201)
        #expect(snapshot.planName == nil)
    }

    @Test
    func `parses subscription from JSON with reset at`() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let resetAt = now.addingTimeInterval(3600)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let payload: [String: Any] = [
            "usage": [
                "rollingUsage": [
                    "usagePercent": 0.25,
                    "resetAt": formatter.string(from: resetAt),
                ],
                "weeklyUsage": [
                    "usagePercent": 75,
                    "resetInSec": 7200,
                ],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let text = String(data: data, encoding: .utf8) ?? ""

        let snapshot = try OpenCodeUsageFetcher.parseSubscription(text: text, now: now)

        #expect(snapshot.rollingUsagePercent == 25)
        #expect(snapshot.weeklyUsagePercent == 75)
        #expect(snapshot.rollingResetInSec == 3600)
        #expect(snapshot.weeklyResetInSec == 7200)
        #expect(snapshot.planName == nil)
    }

    @Test
    func `parses subscription from candidate windows`() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "windows": [
                "primaryWindow": [
                    "percent": 0.1,
                    "resetInSec": 300,
                ],
                "secondaryWindow": [
                    "percent": 0.5,
                    "resetInSec": 1200,
                ],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let text = String(data: data, encoding: .utf8) ?? ""

        let snapshot = try OpenCodeUsageFetcher.parseSubscription(text: text, now: now)

        #expect(snapshot.rollingUsagePercent == 10)
        #expect(snapshot.weeklyUsagePercent == 50)
        #expect(snapshot.rollingResetInSec == 300)
        #expect(snapshot.weeklyResetInSec == 1200)
        #expect(snapshot.planName == nil)
    }

    @Test
    func `computes usage percent from totals`() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "rollingUsage": [
                "used": 25,
                "limit": 100,
                "resetInSec": 600,
            ],
            "weeklyUsage": [
                "used": 50,
                "limit": 200,
                "resetInSec": 3600,
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let text = String(data: data, encoding: .utf8) ?? ""

        let snapshot = try OpenCodeUsageFetcher.parseSubscription(text: text, now: now)

        #expect(snapshot.rollingUsagePercent == 25)
        #expect(snapshot.weeklyUsagePercent == 25)
        #expect(snapshot.planName == nil)
    }

    @Test
    func parsesGoSubscriptionFromBillingHTML() throws {
        let text = """
        <section>
          <h2>Go Subscription</h2>
          <p>You are subscribed to OpenCode Go.</p>
        </section>
        <script>
        $R[13]($R[28],$R[46]={mine:!0,useBalance:!1,rollingUsage:$R[47]={status:"ok",resetInSec:4982,usagePercent:6},weeklyUsage:$R[48]={status:"ok",resetInSec:290876,usagePercent:2},monthlyUsage:$R[49]={status:"ok",resetInSec:2665043,usagePercent:1}});
        </script>
        """
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let snapshot = try OpenCodeUsageFetcher.parseSubscription(text: text, now: now)

        #expect(snapshot.rollingUsagePercent == 6)
        #expect(snapshot.weeklyUsagePercent == 2)
        #expect(snapshot.rollingResetInSec == 4982)
        #expect(snapshot.weeklyResetInSec == 290_876)
        #expect(snapshot.planName == "OpenCode Go")
    }

    @Test
    func mapsPlanNameToIdentity() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = OpenCodeUsageSnapshot(
            rollingUsagePercent: 10,
            weeklyUsagePercent: 20,
            rollingResetInSec: 300,
            weeklyResetInSec: 900,
            planName: "OpenCode Go",
            updatedAt: now)

        let usage = snapshot.toUsageSnapshot()

        #expect(usage.loginMethod(for: .opencode) == "OpenCode Go")
        #expect(usage.identity?.providerID == .opencode)
    }

    @Test
    func `parse subscription throws when fields missing`() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let text = "{\"ok\":true}"

        #expect(throws: OpenCodeUsageError.self) {
            _ = try OpenCodeUsageFetcher.parseSubscription(text: text, now: now)
        }
    }
}
