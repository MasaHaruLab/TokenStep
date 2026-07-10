import XCTest
@testable import TokenStepSwift

final class AppStateTests: XCTestCase {
    func testDailyUsageReturnsZeroUsageForMissingCurrentDayInsteadOfPreviousDay() {
        let yesterday = DailyUsage(
            date: "2026-07-09",
            tools: ["Codex": 42],
            totalTokens: 42,
            cost: 1.25
        )
        let snapshot = UsageSnapshot(
            generatedAt: nil,
            timezone: "Asia/Shanghai",
            totals: UsageTotals(tokens: 42, cost: 1.25, activeDays: 1),
            daily: [yesterday],
            tools: [],
            models: [],
            sources: [:]
        )

        let today = AppState.dailyUsage(for: "2026-07-10", in: snapshot)

        XCTAssertEqual(today.date, "2026-07-10")
        XCTAssertEqual(today.totalTokens, 0)
        XCTAssertEqual(today.cost, 0)
        XCTAssertTrue(today.tools.isEmpty)
    }
}
