import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedDateOffset: Int = 0

    private let maxHistoryDays = 14

    private var availableDates: [String] {
        Array(appState.snapshot.daily.map(\.date).suffix(maxHistoryDays))
    }

    private var selectedDay: DailyUsage {
        guard let index = availableDateIndex else { return appState.today }
        let date = availableDates[index]
        return appState.snapshot.daily.first { $0.date == date }
            ?? DailyUsage(date: date, tools: [:], models: [:], totalTokens: 0, cost: 0)
    }

    private var availableDateIndex: Int? {
        guard !availableDates.isEmpty else { return nil }
        let todayKey = DateFormatter.tokenStepDay.string(from: Date())
        let todayIdx = availableDates.lastIndex(of: todayKey) ?? (availableDates.count - 1)
        let idx = todayIdx + selectedDateOffset
        guard idx >= 0, idx < availableDates.count else { return nil }
        return idx
    }

    private var isToday: Bool {
        let key = DateFormatter.tokenStepDay.string(from: Date())
        return selectedDay.date == key
    }

    private var selectedLap: TokenStepLapProgress {
        TokenStepLapProgress(tokens: selectedDay.totalTokens, goal: appState.settings.dailyGoalTokens)
    }

    var body: some View {
        VStack(spacing: 22) {
            dateSelector
            hero
            todayBreakdownStrip
            if selectedDay.totalTokens > 0 {
                todayAdviceCard
            }
            metricStrip
            if !sessionsForToday.isEmpty {
                sessionHealthCard
            }
            if appState.settings.showCodexQuota, appState.hasAnyQuota {
                quotaCard
            }
        }
    }

    // MARK: - Date selector

    private var dateSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(availableDates.enumerated()), id: \.element) { index, date in
                    let isSelected = availableDateIndex == index
                    Button {
                        let todayIdx = availableDates.lastIndex(of: DateFormatter.tokenStepDay.string(from: Date())) ?? (availableDates.count - 1)
                        selectedDateOffset = index - todayIdx
                    } label: {
                        VStack(spacing: 4) {
                            Text(dateDisplayText(date))
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(isSelected ? .white : Color.tokenInk.opacity(0.62))
                            if isSelected {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? appState.todayLap.color : Color.tokenSurface,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? Color.clear : Color.black.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func dateDisplayText(_ date: String) -> String {
        let todayKey = DateFormatter.tokenStepDay.string(from: Date())
        if date == todayKey { return L("今天") }
        // Show M-DD format
        let parts = date.split(separator: "-")
        if parts.count == 3 {
            return "\(parts[1])-\(parts[2])"
        }
        return date
    }

    // MARK: - Hero

    private var hero: some View {
        let lap = selectedLap
        return TokenCard {
            HStack(alignment: .center, spacing: 34) {
                ZStack {
                    ProgressRingView(progress: lap.currentLapProgress, lineWidth: 20, color: lap.color)
                    VStack(spacing: 6) {
                        Text(TokenStepFormat.tokens(selectedDay.totalTokens))
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
                    }

                    LapProgressChips(lap: lap)

                    coldWarmIndicator

                    HStack(spacing: 10) {
                        MetricPill(label: isToday ? L("今日消耗") : L("消耗金额"), value: TokenStepFormat.money(selectedDay.cost))
                        MetricPill(label: isToday ? L("本月均值") : L("当日占比"),
                            value: isToday
                                ? TokenStepFormat.tokens(appState.monthAverage, compact: true)
                                : dailyShareText)
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

    private var dailyShareText: String {
        guard appState.snapshot.totals.tokens > 0, selectedDay.totalTokens > 0 else { return "--" }
        let share = Double(selectedDay.totalTokens) / Double(appState.snapshot.totals.tokens) * 100
        return TokenStepFormat.percent(share)
    }

    // MARK: - Cold / Warm

    private var coldWarmIndicator: some View {
        let hasData = selectedDay.coldTokens > 0 || selectedDay.warmTokens > 0
        guard hasData else { return AnyView(EmptyView()) }

        let pct = selectedDay.warmPercent
        let color: Color = {
            if pct < 10 { return Color.red.opacity(0.7) }
            if pct < 30 { return Color.orange }
            if pct < 50 { return Color.yellow }
            return Color.tokenGreenDark
        }()

        return AnyView(
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Circle().fill(Color.tokenInk.opacity(0.35)).frame(width: 5, height: 5)
                    Text(L("冷"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(TokenStepFormat.tokens(selectedDay.coldTokens, compact: true))
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color.tokenInk.opacity(0.62))
                }
                Text("·")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.tertiary)
                HStack(spacing: 3) {
                    Circle().fill(color).frame(width: 5, height: 5)
                    Text(L("热"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(TokenStepFormat.tokens(selectedDay.warmTokens, compact: true))
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(color)
                }
                if selectedDay.warmTokens > 0 {
                    Text(String(format: "%.0f%%", pct))
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.12), in: Capsule())
                }
            }
        )
    }

    private var todayAdviceCard: some View {
        let pct = selectedDay.warmPercent
        let advice = todayAdvice(warmPercent: pct)

        return TokenCard {
            HStack(spacing: 12) {
                Image(systemName: advice.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(advice.color)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(advice.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.tokenInk)
                    if !advice.tip.isEmpty {
                        Text(advice.tip)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "%.0f%%", pct))
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(advice.color)
                    Text(L("缓存命中"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func todayAdvice(warmPercent: Double) -> (icon: String, title: String, tip: String, color: Color) {
        if selectedDay.totalTokens == 0 {
            return ("questionmark.circle", L("暂无数据"), "", .secondary)
        }
        if warmPercent < 5 {
            return (
                "thermometer.snowflake",
                L("几乎没用上缓存"),
                L("把相关任务放在同一个长会话里，别每次都开新窗口"),
                Color.red.opacity(0.72)
            )
        }
        if warmPercent < 25 {
            return (
                "thermometer.low",
                L("缓存偏少"),
                L("试试用同一个会话连续提问，而不是每次都新建"),
                Color.orange
            )
        }
        if warmPercent < 50 {
            return (
                "thermometer.medium",
                L("缓存效率不错"),
                L("继续维持长会话习惯就行"),
                Color.yellow
            )
        }
        return (
            "flame.fill",
            L("缓存效率很高"),
            L("长会话用得好，大部分上下文都被复用了"),
            Color.tokenGreenDark
        )
    }

    // MARK: - Session health

    private var sessionsForToday: [SessionSummary] {
        appState.snapshot.sessions.filter { $0.date == selectedDay.date }
    }

    private var sessionHealthCard: some View {
        let coldStarts = sessionsForToday.filter(\.isColdStart).sorted { $0.totalTokens > $1.totalTokens }.prefix(5)
        let bloated = sessionsForToday.filter(\.isBloated).sorted { $0.totalTokens > $1.totalTokens }.prefix(5)
        let healthy = sessionsForToday.filter(\.isHealthy).sorted { $0.warmPercent > $1.warmPercent }.prefix(3)

        let coldTotal = coldStarts.map(\.totalTokens).reduce(0, +)
        let bloatedTotal = bloated.map(\.totalTokens).reduce(0, +)
        let wastedTokens = coldTotal + bloatedTotal

        return TokenCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("会话健康"))
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Color.tokenInk)
                        if wastedTokens > 0 {
                            Text(LFormat("⚠️ 今天可能浪费了 %@ token", TokenStepFormat.tokens(wastedTokens, compact: true)))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.orange.opacity(0.85))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(sessionsForToday.count)")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(Color.tokenGreenDark)
                        Text(L("个会话"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                if !coldStarts.isEmpty {
                    sessionSection(
                        icon: "snowflake",
                        title: L("冷启动会话"),
                        subtitle: L("每次开新会话都要从头加载上下文"),
                        color: Color.red.opacity(0.72),
                        total: coldTotal,
                        sessions: Array(coldStarts)
                    )
                }

                if !bloated.isEmpty {
                    sessionSection(
                        icon: "exclamationmark.triangle.fill",
                        title: L("效率偏低"),
                        subtitle: L("token 量大但缓存利用不够——合并在一个会话里试试"),
                        color: Color.orange,
                        total: bloatedTotal,
                        sessions: Array(bloated)
                    )
                }

                if !healthy.isEmpty {
                    sessionSection(
                        icon: "leaf.fill",
                        title: L("健康会话"),
                        subtitle: L("缓存命中率高，保持这个习惯"),
                        color: Color.tokenGreenDark,
                        total: healthy.map(\.totalTokens).reduce(0, +),
                        sessions: Array(healthy)
                    )
                }
            }
        }
    }

    private func sessionSection(icon: String, title: String, subtitle: String, color: Color, total: Int, sessions: [SessionSummary]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Color.tokenInk.opacity(0.8))
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(TokenStepFormat.tokens(total, compact: true))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(color)
            }

            ForEach(sessions.prefix(5), id: \.sessionID) { session in
                sessionRow(session: session)
            }
        }
        .padding(12)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func sessionRow(session: SessionSummary) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(sessionLabelColor(session))
                .frame(width: 6, height: 6)
            Text(session.tool)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.tokenInk.opacity(0.62))
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)
            Text(TokenStepFormat.tokens(session.totalTokens, compact: true))
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color.tokenInk)
                .monospacedDigit()
            Spacer()
            HStack(spacing: 4) {
                Text(String(format: "冷 %.0f%%", 100 - session.warmPercent))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.tokenInk.opacity(0.5))
                Text(String(format: "热 %.0f%%", session.warmPercent))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(session.warmPercent > 50 ? Color.tokenGreenDark : Color.orange)
            }
            Text(L(session.label))
                .font(.caption2.weight(.heavy))
                .foregroundStyle(sessionLabelColor(session))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(sessionLabelColor(session).opacity(0.12), in: Capsule())
        }
    }

    private func sessionLabelColor(_ session: SessionSummary) -> Color {
        if session.isColdStart { return Color.red.opacity(0.72) }
        if session.isBloated { return Color.orange }
        if session.isHealthy { return Color.tokenGreenDark }
        return Color.secondary
    }

    private func modelColor(_ modelName: String) -> Color {
        let lower = modelName.lowercased()
        if lower.contains("deepseek") { return tokenToolColor("deepseek") }
        if lower.contains("minimax") { return tokenToolColor("minimax-cn") }
        if lower.contains("claude") || lower.contains("opus") || lower.contains("sonnet") || lower.contains("haiku") { return tokenToolColor("Claude Code") }
        if lower.contains("gpt") { return tokenToolColor("Codex") }
        return Color.tokenInk.opacity(0.52)
    }

    // MARK: - Metric strip

    private var metricStrip: some View {
        HStack(spacing: 18) {
            CompactMetricCard(label: L("累计用量"), value: TokenStepFormat.tokens(appState.snapshot.totals.tokens), detail: L("所有客户端总计"))
            CompactMetricCard(label: L("活跃天数"), value: localizedDays(appState.snapshot.totals.activeDays), detail: L("有 AI 使用的日期"))
            CompactMetricCard(label: L("达标天数"), value: localizedDays(appState.goalDays), detail: L("超过每日目标"))
        }
    }

    private var todayBreakdownStrip: some View {
        let dateLabel = isToday ? L("今日") : dateDisplayText(selectedDay.date)
        return HStack(alignment: .top, spacing: 22) {
            TodayBreakdownCard(title: L("客户端"), dateLabel: dateLabel, rows: todayToolRows, maxRows: 3)
            TodayBreakdownCard(title: L("模型"), dateLabel: dateLabel, rows: todayModelRows, maxRows: 4)
        }
    }

    private func localizedDays(_ count: Int) -> String {
        TokenStepLocalization.language == .en ? "\(count)d" : "\(count) 天"
    }

    // ... (quota card unchanged, same as before)
    private var quotaCard: some View {
        TokenCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.tokenGreen)
                        .frame(width: 8, height: 8)
                    Text(isToday ? L("今日已用额度") : L("已用额度"))
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

                if isToday, !todayModelRows.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("今日模型用量"))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Color.tokenInk.opacity(0.62))
                            .padding(.top, 4)
                        ForEach(todayModelRows.prefix(4), id: \.name) { row in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(row.color ?? Color.tokenGreen)
                                    .frame(width: 7, height: 7)
                                Text(modelDisplayName(row.name))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.tokenInk.opacity(0.72))
                                    .lineLimit(1)
                                Spacer()
                                Text(TokenStepFormat.tokens(row.tokens, compact: true))
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(Color.tokenInk.opacity(0.62))
                                    .monospacedDigit()
                            }
                        }
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

    // MARK: - Breakdown rows

    private var todayToolRows: [TodayBreakdownRow] {
        let total = selectedDay.totalTokens
        guard total > 0 else { return [] }
        let primaryTools = ["Codex", "Claude Code", "Claude Cowork", "deepseek", "minimax-cn"]
        let primaryRows = primaryTools.map { name in
            TodayBreakdownRow(
                name: name,
                tokens: selectedDay.tools[name] ?? 0,
                percent: Double(selectedDay.tools[name] ?? 0) * 100 / Double(total),
                color: tokenToolColor(name)
            )
        }
        let extraRows = selectedDay.tools
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
        breakdownRows(from: selectedDay.models) { modelColor($0) }
    }

    private func breakdownRows(from values: [String: Int], color: (String) -> Color?) -> [TodayBreakdownRow] {
        let total = selectedDay.totalTokens
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
