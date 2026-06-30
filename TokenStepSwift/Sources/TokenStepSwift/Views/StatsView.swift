import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 18) {
                StatHeroMetric(label: L("累计 Token 用量"), value: TokenStepFormat.tokens(appState.snapshot.totals.tokens), symbol: "figure.walk", note: L("所有客户端 token 总和"))
                StatHeroMetric(label: L("等值金额（估算）"), value: TokenStepFormat.money(appState.snapshot.totals.cost), symbol: "dollarsign.circle", note: L("按官方价折算 · 非实际账单"))
                StatHeroMetric(label: L("活跃天数"), value: localizedDays(appState.snapshot.totals.activeDays), symbol: "flame", note: L("有 AI 使用的天数"))
            }

            recentActivityCard

            HStack(alignment: .top, spacing: 22) {
                usageList(title: L("按客户端"), subtitle: L("累计总量分布"), rows: appState.snapshot.tools.map {
                    UsageStatRow(name: $0.tool, value: $0.tokens, percent: $0.percentValue, color: $0.displayColor)
                })
                usageList(title: L("按模型"), subtitle: "Top \(min(mergedModelRows.count, 10)) / \(mergedModelRows.count)", rows: Array(mergedModelRows.prefix(10)))
            }
        }

    }

    private var recentActivityCard: some View {
        TokenCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("最近 30 天"))
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(Color.tokenInk)
                        Text(L("柱越高，用量越多；颜色代表客户端"))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TokenToolLegend(tools: recentTools, showsGoalLine: true)
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.caption2.weight(.bold))
                        Text(LFormat("缓存 %.0f%%", recentWarmPercent))
                            .font(.callout.weight(.bold))
                    }
                    .foregroundStyle(cacheRateColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(cacheRateColor.opacity(0.14), in: Capsule())
                    .help(L("最近 30 天缓存命中率（热 token 占比）"))
                    Text(LFormat("今天 %@", TokenStepFormat.tokens(appState.today.totalTokens, compact: true)))
                        .font(.callout.weight(.bold))
                        .foregroundStyle(Color.tokenGreenDark)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.tokenMint.opacity(0.28), in: Capsule())
                }

                StackedActivityBarsView(rows: appState.snapshot.daily, goal: appState.settings.dailyGoalTokens)
                    .frame(height: 96)
            }
        }
    }

    private func usageList(title: String, subtitle: String, rows: [UsageStatRow]) -> some View {
        TokenCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Color.tokenInk)
                    Spacer()
                    Text(subtitle)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if rows.isEmpty {
                    Text(L("等待下一次同步"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                } else {
                    ForEach(rows) { row in
                        UsageProgressRow(
                            name: row.name,
                            value: "\(TokenStepFormat.tokens(row.value, compact: true)) · \(TokenStepFormat.percent(row.percent))",
                            percent: row.percent,
                            color: row.color
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func localizedDays(_ count: Int) -> String {
        TokenStepLocalization.language == .en ? "\(count)d" : "\(count) 天"
    }

    private var recentTools: [String] {
        uniqueToolNames(in: Array(appState.snapshot.daily.suffix(30)))
    }

    // Snapshot stores models per (model × client); merge by model name so each model shows once.
    private var mergedModelRows: [UsageStatRow] {
        var byModel: [String: Int] = [:]
        for entry in appState.snapshot.models {
            byModel[entry.model, default: 0] += entry.tokens
        }
        let total = byModel.values.reduce(0, +)
        return byModel
            .map { name, tokens in
                UsageStatRow(
                    name: name,
                    value: tokens,
                    percent: total > 0 ? Double(tokens) / Double(total) * 100 : 0,
                    color: tokenModelColor(name)
                )
            }
            .sorted { $0.value > $1.value }
    }

    private var recentWarmPercent: Double {
        let recent = appState.snapshot.daily.suffix(30)
        let cold = recent.map(\.coldTokens).reduce(0, +)
        let warm = recent.map(\.warmTokens).reduce(0, +)
        return (cold + warm) > 0 ? Double(warm) / Double(cold + warm) * 100 : 0
    }

    private var cacheRateColor: Color {
        switch recentWarmPercent {
        case 50...:  return Color.tokenGreenDark
        case 25...:  return Color.yellow
        case 5...:   return Color.orange
        default:     return Color.red.opacity(0.72)
        }
    }
}

private struct StatHeroMetric: View {
    var label: String
    var value: String
    var symbol: String
    var note: String? = nil

    var body: some View {
        TokenCard {
            VStack(alignment: .leading, spacing: 15) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.tokenMint.opacity(0.24))
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.tokenGreenDark)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 6) {
                    Text(value)
                        .font(.system(size: 29, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.tokenInk)
                        .minimumScaleFactor(0.62)
                        .lineLimit(1)
                    Text(label)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(Color.tokenInk.opacity(0.78))
                    if let note {
                        Text(note)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct UsageStatRow: Identifiable {
    var id: String { name }
    var name: String
    var value: Int
    var percent: Double
    var color: Color
}
