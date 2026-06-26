import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 22) {
            hero
            todayBreakdownStrip
            recent14DayBars
            metricStrip
            if appState.settings.showCodexQuota, appState.hasAnyQuota {
                quotaCard
            }
        }
    }

    private var hero: some View {
        let lap = appState.todayLap
        return TokenCard {
            HStack(alignment: .center, spacing: 34) {
                ZStack {
                    ProgressRingView(progress: lap.currentLapProgress, lineWidth: 20, color: lap.color)
                    VStack(spacing: 6) {
                        Text(TokenStepFormat.tokens(appState.today.totalTokens))
                            .font(.system(size: 42, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.tokenInk)
                            .minimumScaleFactor(0.42)
                            .lineLimit(1)
                        Text(LFormat("/ %@ 每圈", TokenStepFormat.tokens(appState.settings.dailyGoalTokens, compact: true)))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 160)
                }
                .frame(width: 204, height: 204)

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lap.lapStatusText)
                            .font(.system(size: 35, weight: .heavy, design: .rounded))
                            .foregroundStyle(lap.color)
                            .monospacedDigit()
                        Text(lap.completedTokensText)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(lap.perLapGoalText)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("圈数进度"))
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Color.tokenInk)
                        LapProgressChips(lap: lap)
                    }

                    HStack(spacing: 10) {
                        MetricPill(label: L("消耗金额"), value: TokenStepFormat.money(appState.today.cost))
                        MetricPill(label: L("本月均值"), value: TokenStepFormat.tokens(appState.monthAverage, compact: true))
                    }

                    Button {
                        appState.refresh()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption.weight(.heavy))
                            Text(L("刷新"))
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .background(Color.tokenSurface.opacity(0.9), in: Capsule())
                    .overlay(Capsule().stroke(Color.black.opacity(0.06)))
                    .disabled(appState.isRefreshing)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var metricStrip: some View {
        HStack(spacing: 18) {
            CompactMetricCard(label: L("累计用量"), value: TokenStepFormat.tokens(appState.snapshot.totals.tokens), detail: L("所有客户端总计"))
            CompactMetricCard(label: L("活跃天数"), value: localizedDays(appState.snapshot.totals.activeDays), detail: L("有 AI 使用的日期"))
            CompactMetricCard(label: L("达标天数"), value: localizedDays(appState.goalDays), detail: L("超过每日目标"))
        }
    }

    private var todayBreakdownStrip: some View {
        HStack(alignment: .top, spacing: 22) {
            TodayBreakdownCard(title: L("今日客户端"), rows: todayToolRows, maxRows: 3)
            TodayBreakdownCard(title: L("今日模型"), rows: todayModelRows, maxRows: 4)
        }
    }

    private var recent14DayBars: some View {
        TokenCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L("过去 14 天"))
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Color.tokenInk)
                    Spacer()
                    Text(LFormat("日均 %@", TokenStepFormat.tokens(appState.monthAverage, compact: true)))
                        .font(.callout.weight(.bold))
                        .foregroundStyle(Color.tokenGreenDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.tokenMint.opacity(0.22), in: Capsule())
                }
                StackedActivityBarsView(
                    rows: appState.snapshot.daily,
                    goal: appState.settings.dailyGoalTokens,
                    maxCount: 14
                )
                .frame(height: 72)
            }
        }
    }

    private func localizedDays(_ count: Int) -> String {
        TokenStepLocalization.language == .en ? "\(count)d" : "\(count) 天"
    }

    private var quotaCard: some View {
        TokenCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.tokenGreen)
                        .frame(width: 8, height: 8)
                    Text(L("已用额度"))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Color.tokenInk)
                    Spacer()
                    if let fetchedAt = appState.claudeQuota.fetchedAt ?? appState.codexQuota.fetchedAt {
                        let seconds = max(0, Int(Date().timeIntervalSince(fetchedAt).rounded()))
                        let text = seconds < 60 ? L("刚刚") : String(format: L("%%d 分钟前"), max(1, seconds / 60))
                        Text(text)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 28) {
                    if appState.claudeQuota.isAvailable {
                        quotaColumn(title: "Claude", quota: appState.claudeQuota)
                    }
                    if appState.codexQuota.isAvailable {
                        quotaColumn(title: "Codex", quota: appState.codexQuota)
                    }
                }
            }
        }
    }

    private func quotaColumn(title: String, quota: CodexQuotaSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color.tokenInk.opacity(0.72))
            quotaRow("5h", window: quota.fiveHour)
            quotaRow("7d", window: quota.sevenDay)
        }
    }

    private func quotaRow(_ label: String, window: CodexQuotaWindow?) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color.tokenInk.opacity(0.62))
                .frame(width: 22, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(window.map { String(format: "已用 %.0f%%", $0.usedPercent) } ?? "--")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(window == nil ? .secondary : Color.tokenInk.opacity(0.82))
                        .monospacedDigit()
                    if window != nil {
                        Text("·")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(quotaRemainingText(window?.resetsAt))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Color.tokenGreenDark)
                            .monospacedDigit()
                    }
                    Spacer()
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.tokenGreen.opacity(0.10))
                        if let window {
                            Capsule()
                                .fill(Color.tokenGreen)
                                .frame(width: max(5, proxy.size.width * window.usedPercent / 100))
                        }
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private func quotaRemainingText(_ date: Date?) -> String {
        guard let date else { return "" }
        let seconds = max(0, Int(date.timeIntervalSinceNow.rounded()))
        if seconds < 60 { return L("距刷新 <1分") }
        if seconds < 3_600 {
            return String(format: L("距刷新 %d分"), max(1, seconds / 60))
        }
        let h = seconds / 3_600
        let m = (seconds % 3_600) / 60
        if h < 24 {
            return m > 0
                ? String(format: L("距刷新 %dh %dm"), h, m)
                : String(format: L("距刷新 %dh"), h)
        }
        let d = max(1, Int(ceil(Double(seconds) / 86_400)))
        return String(format: L("距刷新 %d天"), d)
    }

    private func quotaResetText(_ date: Date?) -> String {
        guard let date else { return L("等待重置") }
        let seconds = max(0, Int(date.timeIntervalSinceNow.rounded()))
        if seconds < 60 { return L("即将重置") }
        if seconds < 3_600 { return String(format: L("%%d 分后重置"), max(1, seconds / 60)) }
        if seconds < 86_400 {
            let h = seconds / 3_600
            let m = (seconds % 3_600) / 60
            return String(format: L("约 %d:%02d 后重置"), h, m)
        }
        return String(format: L("%%d 天后重置"), max(1, Int(ceil(Double(seconds) / 86_400))))
    }

    private var todayToolRows: [TodayBreakdownRow] {
        let total = appState.today.totalTokens
        guard total > 0 else { return [] }
        let primaryTools = ["Codex", "Claude Code", "Claude Cowork"]
        let primaryRows = primaryTools.map { name in
            TodayBreakdownRow(
                name: name,
                tokens: appState.today.tools[name] ?? 0,
                percent: Double(appState.today.tools[name] ?? 0) * 100 / Double(total),
                color: tokenToolColor(name)
            )
        }
        let extraRows = appState.today.tools
            .filter { !primaryTools.contains($0.key) && $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { name, tokens in
                TodayBreakdownRow(
                    name: name,
                    tokens: tokens,
                    percent: Double(tokens) * 100 / Double(total),
                    color: tokenToolColor(name)
                )
            }
        return primaryRows + extraRows
    }

    private var todayModelRows: [TodayBreakdownRow] {
        breakdownRows(from: appState.today.models) { _ in nil }
    }

    private func breakdownRows(from values: [String: Int], color: (String) -> Color?) -> [TodayBreakdownRow] {
        let total = appState.today.totalTokens
        guard total > 0 else { return [] }
        return values
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { name, tokens in
                TodayBreakdownRow(
                    name: name,
                    tokens: tokens,
                    percent: Double(tokens) * 100 / Double(total),
                    color: color(name)
                )
            }
    }
}

private struct CompactMetricCard: View {
    var label: String
    var value: String
    var detail: String

    var body: some View {
        TokenCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(label)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.tokenInk.opacity(0.8))
                Text(value)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.tokenInk)
                    .minimumScaleFactor(0.62)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.tokenGreenDark)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LapProgressChips: View {
    var lap: TokenStepLapProgress

    private var visibleCompletedLaps: [Int] {
        let completed = max(0, lap.completedLaps)
        guard completed > 0 else { return [] }
        if completed <= 2 { return Array(1...completed) }
        return Array(max(1, completed - 1)...completed)
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(visibleCompletedLaps, id: \.self) { item in
                LapChip(title: LFormat("%d圈完成", item), detail: TokenStepFormat.tokens(item * lap.safeGoal, compact: true), active: false, color: .tokenGreen)
            }
            LapChip(title: LFormat("%@进行中", lap.lapTitle), detail: lap.lapPercentText, active: true, color: lap.color)
        }
    }
}

private struct LapChip: View {
    var title: String
    var detail: String
    var active: Bool
    var color: Color

    var body: some View {
        VStack(spacing: 4) {
            Label(title, systemImage: active ? "arrow.clockwise.circle.fill" : "checkmark.circle.fill")
                .font(.caption.weight(.heavy))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
            Text(detail)
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(active ? color : Color.tokenInk.opacity(0.68))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(active ? color.opacity(0.12) : Color.tokenTrack.opacity(0.46), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(active ? color.opacity(0.36) : Color.black.opacity(0.045)))
    }
}
