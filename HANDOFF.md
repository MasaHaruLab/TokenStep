# TokenStep handoff

## 状态

已完成跨日今日日期修复。

## 已完成

1. `AppState.today` 不再回退到最后一条历史数据；当天没有采集记录时返回当天的零值记录。
2. 添加回归测试，覆盖快照仅有昨天数据的跨日情形。
3. 已通过全量 Swift 源码 typecheck。`swift test` 仍受本机 Command Line Tools 缺少 XCTest 模块阻断，非本次改动导致。

## 下一步

在具备 XCTest 的 Xcode 环境中运行 `swift test`；随后按常规发布流程构建并安装新版本，才能让 `/Applications/TokenStep.app` 获得此修复。
