# KeepingYouAwake (Amphetamine)

🌐 [English](README.md) · [日本語](README.ja.md) · **简体中文** · [Deutsch](README.de.md) · [Français](README.fr.md)

> [`newmarcel/KeepingYouAwake`](https://github.com/newmarcel/KeepingYouAwake) 的社区分支，由 [@ryouka0731](https://github.com/ryouka0731) 维护，为熟悉的 `caffeinate` 包装器引入 **Amphetamine 风格的功能**。遵照上游维护者的请求，本分支的应用名（橙色咖啡杯图标 + 带后缀的显示名）与原作保持区分。

KeepingYouAwake (Amphetamine) 是一个面向 macOS 10.13 及更高版本的轻量菜单栏工具，可在预设时长内（或在某种触发条件持续时）阻止 Mac 进入睡眠。

## 在上游 1.6.8 之上新增的功能

| # | 功能 | PR |
|---|------|----|
| 1 | 防止磁盘休眠 (`caffeinate -m`) | [#8](https://github.com/ryouka0731/KeepingYouAwake/pull/8) |
| 2 | 电池充满时自动停用 | [#9](https://github.com/ryouka0731/KeepingYouAwake/pull/9) |
| 3 | 激活时长：直到今日结束（次日零点） | [#10](https://github.com/ryouka0731/KeepingYouAwake/pull/10) |
| 4 | App Intents / Shortcuts.app 集成 (`Activate` / `Deactivate` / `Toggle`) | [#17](https://github.com/ryouka0731/KeepingYouAwake/pull/17) |
| 5 | 触发器：连接到指定 Wi-Fi SSID 时 | [#18](https://github.com/ryouka0731/KeepingYouAwake/pull/18) |
| 6 | 触发器：连接交流电源时（识别状态切换） | [#19](https://github.com/ryouka0731/KeepingYouAwake/pull/19) |
| 7 | Drive Alive — 激活期间保持外部驱动器持续运转 | [#20](https://github.com/ryouka0731/KeepingYouAwake/pull/20) |
| 8 | 触发器：指定应用运行时（多 bundle 支持） | [#27](https://github.com/ryouka0731/KeepingYouAwake/pull/27) / [#28](https://github.com/ryouka0731/KeepingYouAwake/pull/28) |
| 9 | 触发器：按工作日 × 时段排程 | [#63](https://github.com/ryouka0731/KeepingYouAwake/pull/63) |
| 10 | 触发器：下载进行中（`*.crdownload` 等） | [#64](https://github.com/ryouka0731/KeepingYouAwake/pull/64) |
| 11 | 菜单栏剩余时间倒计时显示 | [#55](https://github.com/ryouka0731/KeepingYouAwake/pull/55) |
| 12 | 活动日志（`~/Library/Application Support/KeepingYouAwake/activity.jsonl`） | [#59](https://github.com/ryouka0731/KeepingYouAwake/pull/59) / [#61](https://github.com/ryouka0731/KeepingYouAwake/pull/61) |

并引入 session source tracking，使功能触发器无法误终止用户主动启动的会话（外部显示触发器同样在 [#58](https://github.com/ryouka0731/KeepingYouAwake/pull/58) 中改为 source-aware）。同时已配置 Sparkle 自动更新 appcast 工作流（[#66](https://github.com/ryouka0731/KeepingYouAwake/pull/66)，剩余手动步骤见 `docs/sparkle-auto-update-setup.md`）。

## 安装

### 下载（推荐）

[Releases →](https://github.com/ryouka0731/KeepingYouAwake/releases)

每个发布都附带 `KeepingYouAwake-<tag>.dmg` 与 `.dmg.sha256`。由于没有 Apple Developer ID，仅做 ad-hoc 签名、未公证。首次启动需：

1. 挂载 dmg，将 `KeepingYouAwake.app` 拖入 `/Applications`。
2. **右键点击** 应用 → **打开** → 在弹窗中确认 *打开*。
3. （或在系统设置 → 隐私与安全性 → 仍要打开）

之后即可正常启动。

### 从源码构建

```bash
git clone https://github.com/ryouka0731/KeepingYouAwake.git
cd KeepingYouAwake
open KeepingYouAwake.xcworkspace
```

需 Xcode 16 或更高版本（图标使用 Xcode 16 引入的 Icon Composer 格式）。目标 macOS 10.13+。

## 配置新触发器

UI 暂未覆盖的功能开关可通过 `defaults write` 设置：

```bash
# 受监视的应用 bundle ID 列表（任意一个运行中即保持 KYA 激活）
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.WatchedApplicationBundleIdentifiers \
  -array com.apple.FinalCut com.apple.Logic

# 受监视的 Wi-Fi SSID（不区分大小写）
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.WatchedWiFiSSIDs \
  -array Office-WiFi Home-5G

# 接通交流电时自动激活
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.ActivateOnACPowerEnabled -bool YES

# Drive Alive
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.DriveAliveEnabled -bool YES

# 防止磁盘休眠
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.PreventDiskSleepEnabled -bool YES

# 充满电时停用
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.DeactivateOnFullChargeEnabled -bool YES

# 排程触发器（具体 windows 用 PlistBuddy 设置）
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.ScheduleEnabled -bool YES

# 下载进行中自动激活
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.DownloadInProgressActivationEnabled -bool YES

# 隐藏菜单栏倒计时（默认：显示）
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.MenuBarCountdownDisabled -bool YES
```

URL scheme `keepingyouawake:///activate?seconds=N` / `:///deactivate` / `:///toggle` 通过 App Intents 也可在 Shortcuts.app 中使用。

## 工作原理

本应用是 macOS 内置 [`caffeinate`](https://web.archive.org/web/20140604153141/https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/caffeinate.8.html) 命令的薄封装。上游说明的限制（如笔电合盖时 macOS 仍会强制睡眠）同样适用。

## 与上游的关系

本分支跟随 `newmarcel/KeepingYouAwake`，并回引上游的维护性修复。非分支特定的 bug 修复在合适时会先向上游提议。

原版 `newmarcel/KeepingYouAwake` 与 `keepingyouawake.app` 仍由 [Marcel Dierkes](https://github.com/newmarcel) 独立维护。

## bot 评审 / CI

- **CI** (`.github/workflows/ci.yml`) — 每个 PR 都会跑 xcodebuild build、SPM 包单元测试、URL scheme E2E（验证 `caffeinate` 进程实际启停）。
- **Release** (`.github/workflows/release.yml`) — 每个 `v*` 标签都会构建 Release config 的 dmg，做 ad-hoc 签名后上传到对应 Release。
- **CodeQL + OSSF Scorecards** — PR 与每周计划运行的安全审计。
- **AI 评审** — CodeRabbit / cubic / Gitar / Socket Security / Gemini Code Assist 在每个 PR 上留言。
- **Dependabot** — 每周更新 npm / GitHub Actions 依赖（minor / patch 分组合并）。

## 许可证

MIT，与上游一致。提供的图像资源同样为 MIT。

本分支保留 Marcel Dierkes 的原版权声明并附加自身署名（参见应用内 *About* 与 `Credits.rtf`）。遵照上游的请求 — 不要以相同名称与图标再分发分支版本 — 本分支以显示名 **KeepingYouAwake (Amphetamine)** 与橙色咖啡杯图标发行。

## 旧 macOS 支持

与上游一致：
- [Version 1.6.2](https://github.com/newmarcel/KeepingYouAwake/releases/tag/1.6.2) 是支持 macOS Sierra (10.12) 的最后一版。
- [Version 1.5.2](https://github.com/newmarcel/KeepingYouAwake/releases/tag/1.5.2) 是支持 macOS Yosemite (10.10) / El Capitan (10.11) 的最后一版。
