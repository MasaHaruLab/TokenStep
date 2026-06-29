import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    var historyLimit: Int? = nil

    var body: some View {
        VStack(spacing: 22) {
            TokenCard {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L("近 8 个月活动墙"))
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(Color.tokenInk)
                            Text(L("颜色越深，用量越高；描边是今天"))
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            appState.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.tokenGreenDark)
                        .opacity(appState.isRefreshing ? 0.4 : 1)
                        .disabled(appState.isRefreshing)
                        .padding(.trailing, 4)
                        Text(LFormat("%d 个活跃日", appState.snapshot.totals.activeDays))
                            .font(.callout.weight(.bold))
                            .foregroundStyle(Color.tokenGreenDark)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.tokenMint.opacity(0.28), in: Capsule())
                    }

                    ContributionWallView(
                        rows: Array(appState.snapshot.daily.suffix(238)),
                        goal: appState.settings.dailyGoalTokens
                    )
                }
            }

            if !historyRows.isEmpty {
                cacheAdviceCard
            }

            StatsView()

            TokenCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L("全部明细"))
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(Color.tokenInk)
                            Text(historySummaryText)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        TokenToolLegend(tools: historyTools)
                    }

                    LazyVStack(spacing: 0) {
                        header
                        ForEach(historyRows) { row in
                            HistoryRow(row: row, goal: appState.settings.dailyGoalTokens)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Cache advice

    private var cacheAdviceCard: some View {
        let recentRows = Array(historyRows.prefix(30))
        let totalCold = recentRows.map(\.coldTokens).reduce(0, +)
        let totalWarm = recentRows.map(\.warmTokens).reduce(0, +)
        let overallWarmPercent = (totalCold + totalWarm) > 0
            ? Double(totalWarm) / Double(totalCold + totalWarm) * 100
            : 0

        let advice = cacheAdvice(warmPercent: overallWarmPercent, totalCold: totalCold, totalWarm: totalWarm)

        return TokenCard {
            HStack(spacing: 14) {
                Image(systemName: advice.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(advice.color)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 5) {
                    Text(advice.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.tokenInk)
                    Text(advice.detail)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.tokenInk.opacity(0.35)).frame(width: 8, height: 8)
                        Text(L("冷"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(TokenStepFormat.tokens(totalCold, compact: true))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Color.tokenInk.opacity(0.7))
                    }
                    HStack(spacing: 6) {
                        Circle().fill(advice.color).frame(width: 8, height: 8)
                        Text(L("热"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(TokenStepFormat.tokens(totalWarm, compact: true))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(advice.color)
                    }
                }
            }
            .padding(4)
        }
    }

    private func cacheAdvice(warmPercent: Double, totalCold: Int, totalWarm: Int) -> (icon: String, title: String, detail: String, color: Color) {
        if totalCold + totalWarm == 0 {
            return ("questionmark.circle", L("暂无数据"), L("收集更多使用数据后会生成建议"), .secondary)
        }
        if warmPercent < 5 {
            return (
                "thermometer.snowflake",
                L("几乎没用上缓存"),
                L("说明每次都开了新会话。试试把相关任务合并到同一个长对话里，模型就不需要重复读上下文了"),
                Color.red.opacity(0.72)
            )
        }
        if warmPercent < 25 {
            return (
                "thermometer.low",
                L("缓存用得还不够"),
                L("热 token 占比 \(String(format: "%.0f", warmPercent))%。写长 prompt 时让模型在同一个会话里继续改，别每次都开新窗口"),
                Color.orange
            )
        }
        if warmPercent < 50 {
            return (
                "thermometer.medium",
                L("缓存效率不错"),
                L("热 token 占比 \(String(format: "%.0f", warmPercent))%。已经帮你在中段以上了，继续维持长会话习惯就行"),
                Color.yellow
            )
        }
        return (
            "flame.fill",
            L("缓存效率很高"),
            L("热 token 占比 \(String(format: "%.0f", warmPercent))%。你还挺会省——长会话用得好，大部分上下文都被复用了"),
            Color.tokenGreenDark
        )
    }

    // MARK: - History rows

    private var historyRows: [DailyUsage] {
        let rows = appState.visibleHistoryRows
        guard let historyLimit else { return rows }
        return Array(rows.prefix(historyLimit))
    }

    private var historySummaryText: String {
        if let historyLimit {
            return LFormat("最近 %d 天，适合保存为截图", min(historyLimit, historyRows.count))
        }
        return LFormat("%d 条记录，向下滚动查看完整历史", appState.visibleHistoryRows.count)
    }

    private var historyTools: [String] {
        uniqueToolNames(in: historyRows)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text(L("日期")).frame(width: 100, alignment: .leading)
            Text(L("Token 消耗")).frame(width: 130, alignment: .leading)
            Text(L("冷 / 热")).frame(width: 110, alignment: .leading)
            Text(L("消耗金额")).frame(width: 100, alignment: .leading)
            Text(L("主力工具")).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.weight(.heavy))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.tokenTrack.opacity(0.62), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct HistoryRow: View {
    var row: DailyUsage
    var goal: Int

    var body: some View {
        HStack(spacing: 16) {
            Text(row.date)
                .frame(width: 100, alignment: .leading)
                .foregroundStyle(Color.tokenInk.opacity(0.72))
            Text(TokenStepFormat.tokens(row.totalTokens))
                .fontWeight(.heavy)
                .foregroundStyle(Color.tokenInk)
                .frame(width: 130, alignment: .leading)
            coldWarmBar
                .frame(width: 110, alignment: .leading)
            Text(TokenStepFormat.money(row.cost))
                .frame(width: 100, alignment: .leading)
                .foregroundStyle(Color.tokenInk.opacity(0.72))
            HStack(spacing: 8) {
                Circle()
                    .fill(tokenToolColor(dominantTool))
                    .frame(width: 8, height: 8)
                Text(dominantTool)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.tokenInk.opacity(0.72))
        }
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.055))
                .frame(height: 1)
        }
    }

    private var dominantTool: String {
        row.tools.max(by: { $0.value < $1.value })?.key ?? L("无")
    }

    private var coldWarmBar: some View {
        let total = Double(max(row.totalTokens, 1))
        let coldFrac = Double(row.coldTokens) / total
        let warmFrac = Double(row.warmTokens) / total
        let hasCache = row.warmTokens > 0

        return HStack(spacing: 4) {
            if hasCache {
                HStack(spacing: 2) {
                    Circle().fill(Color.tokenInk.opacity(0.35)).frame(width: 5, height: 5)
                    Text(TokenStepFormat.tokens(row.coldTokens, compact: true))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Text("/")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 2) {
                    Circle().fill(cacheColor).frame(width: 5, height: 5)
                    Text(TokenStepFormat.tokens(row.warmTokens, compact: true))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(cacheColor)
                }
            } else {
                HStack(spacing: 2) {
                    Circle().fill(Color.tokenInk.opacity(0.35)).frame(width: 5, height: 5)
                    Text(TokenStepFormat.tokens(row.coldTokens, compact: true))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Text("--")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Mini bar
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.tokenInk.opacity(0.25))
                        .frame(width: geo.size.width * coldFrac)
                    if warmFrac > 0 {
                        Rectangle()
                            .fill(cacheColor.opacity(0.55))
                            .frame(width: geo.size.width * warmFrac)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            .frame(height: 10)
        }
    }

    private var cacheColor: Color {
        let pct = row.warmPercent
        if pct < 10 { return Color.red.opacity(0.6) }
        if pct < 30 { return Color.orange }
        if pct < 50 { return Color.yellow }
        return Color.tokenGreenDark
    }
}
