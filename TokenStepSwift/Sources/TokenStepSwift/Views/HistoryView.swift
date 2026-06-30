import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    var historyLimit: Int? = nil

    enum SortField { case date, tokens, warm, cost }
    @State private var sortField: SortField = .date
    @State private var sortAscending: Bool = false

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

            StatsView()
                .id(appState.snapshot.generatedAt ?? "")

            TokenCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L("全部明细"))
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(Color.tokenInk)
                            Text(historySummaryText)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(L("颜色＝主力客户端"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.tokenInk.opacity(0.55))
                            TokenToolLegend(tools: historyTools)
                        }
                    }

                    LazyVStack(spacing: 0) {
                        header
                        ForEach(sortedHistoryRows) { row in
                            HistoryRow(row: row, goal: appState.settings.dailyGoalTokens)
                        }
                    }
                }
            }
        }
    }

    // MARK: - History rows

    private var historyRows: [DailyUsage] {
        let rows = appState.visibleHistoryRows
        guard let historyLimit else { return rows }
        return Array(rows.prefix(historyLimit))
    }

    private var sortedHistoryRows: [DailyUsage] {
        let rows = historyRows
        let asc: [DailyUsage]
        switch sortField {
        case .date:   asc = rows.sorted { $0.date < $1.date }
        case .tokens: asc = rows.sorted { $0.totalTokens < $1.totalTokens }
        case .warm:   asc = rows.sorted { $0.warmPercent < $1.warmPercent }
        case .cost:   asc = rows.sorted { $0.cost < $1.cost }
        }
        return sortAscending ? asc : asc.reversed()
    }

    private func toggleSort(_ field: SortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortField = field
            sortAscending = false
        }
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
            sortHeader(L("日期"), field: .date, width: 100)
            sortHeader(L("Token 消耗"), field: .tokens, width: 130)
            sortHeader(L("冷 / 热"), field: .warm, width: 110)
            sortHeader(L("消耗金额"), field: .cost, width: 100)
            Text(L("主力工具"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Color.tokenInk.opacity(0.72))
        }
        .font(.caption.weight(.heavy))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.tokenTrack.opacity(0.62), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sortHeader(_ title: String, field: SortField, width: CGFloat) -> some View {
        Button {
            toggleSort(field)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: sortField == field ? (sortAscending ? "chevron.up" : "chevron.down") : "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .heavy))
                    .opacity(sortField == field ? 1 : 0.35)
            }
            .foregroundStyle(sortField == field ? Color.tokenGreenDark : Color.tokenInk.opacity(0.72))
            .frame(width: width, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L("点击按此列排序"))
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
