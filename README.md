# KeepingYouAwake (Amphetamine)

🌐 **English** · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · [Deutsch](README.de.md) · [Français](README.fr.md)

> **Community fork** of [`newmarcel/KeepingYouAwake`](https://github.com/newmarcel/KeepingYouAwake) by [@ryouka0731](https://github.com/ryouka0731), bringing **Amphetamine-style features** to a familiar `caffeinate` wrapper. The original app's name and icon are kept distinct (orange cup, suffixed display name) per the upstream maintainer's request.
>
> EN: This is the *Amphetamine-parity* fork — same caffeinate engine, more triggers and durations.
> 日本語: Amphetamine 機能パリティを目指した fork。caffeinate エンジンはそのままに、トリガと継続時間を強化。
> 中文: 加入 Amphetamine 风格触发器和持续时间的社区分支，caffeinate 内核保持不变。

KeepingYouAwake (Amphetamine) は macOS 10.13 以降向けの軽量メニューバーユーティリティ。事前に決めた時間 — または何らかのトリガが続く間 — Mac をスリープさせない。

## What's added on top of upstream 1.6.8

| # | Feature | PR |
|---|---------|----|
| 1 | Prevent disk sleep (`caffeinate -m`) | [#8](https://github.com/ryouka0731/KeepingYouAwake/pull/8) |
| 2 | Deactivate when battery is fully charged | [#9](https://github.com/ryouka0731/KeepingYouAwake/pull/9) |
| 3 | Activation duration: until end of day (next midnight) | [#10](https://github.com/ryouka0731/KeepingYouAwake/pull/10) |
| 4 | App Intents / Shortcuts.app integration (`Activate`, `Deactivate`, `Toggle`) | [#17](https://github.com/ryouka0731/KeepingYouAwake/pull/17) |
| 5 | Trigger: while joined to a watched Wi-Fi SSID | [#18](https://github.com/ryouka0731/KeepingYouAwake/pull/18) |
| 6 | Trigger: while on AC power (transition-aware) | [#19](https://github.com/ryouka0731/KeepingYouAwake/pull/19) |
| 7 | Drive Alive — keep external drives spinning during activation | [#20](https://github.com/ryouka0731/KeepingYouAwake/pull/20) |
| 8 | Trigger: while a watched application is running (multi-bundle) | [#27](https://github.com/ryouka0731/KeepingYouAwake/pull/27) / [#28](https://github.com/ryouka0731/KeepingYouAwake/pull/28) |
| 9 | Trigger: schedule-based (weekday × time-of-day windows) | [#63](https://github.com/ryouka0731/KeepingYouAwake/pull/63) |
| 10 | Trigger: while a download is in progress (`*.crdownload`, `*.part`, …) | [#64](https://github.com/ryouka0731/KeepingYouAwake/pull/64) |
| 11 | Menu bar countdown (remaining time next to the icon) | [#55](https://github.com/ryouka0731/KeepingYouAwake/pull/55) |
| 12 | Activity log (per-session JSONL audit trail at `~/Library/Application Support/KeepingYouAwake/activity.jsonl`) | [#59](https://github.com/ryouka0731/KeepingYouAwake/pull/59) / [#61](https://github.com/ryouka0731/KeepingYouAwake/pull/61) |

Plus session source tracking so a feature trigger can never deactivate a user-initiated timer, the `KYAActivationSource` invariant now enforced for the external-display trigger as well ([#58](https://github.com/ryouka0731/KeepingYouAwake/pull/58)), and a Sparkle auto-update appcast pipeline ([#66](https://github.com/ryouka0731/KeepingYouAwake/pull/66) — finishing setup steps in `docs/sparkle-auto-update-setup.md`).

## Installation

### Download (recommended)

[Releases page →](https://github.com/ryouka0731/KeepingYouAwake/releases)

Each release attaches a `KeepingYouAwake-<tag>.dmg` and a `.dmg.sha256`. The bundle is **ad-hoc signed** but **not Apple-notarised** (no Developer ID), so the first launch needs:

1. Mount the dmg, drag `KeepingYouAwake.app` into `/Applications`.
2. Right-click the app → **Open** → confirm "Open" in the prompt.
3. (Or, in System Settings → Privacy & Security, click *Open Anyway* after the first failed launch.)

After that, the app launches normally.

### Build from source

```bash
git clone https://github.com/ryouka0731/KeepingYouAwake.git
cd KeepingYouAwake
open KeepingYouAwake.xcworkspace
```

Open in Xcode 16 or newer (the icon uses Apple's Icon Composer format introduced with Xcode 16) and Run. Targets macOS 10.13+.

## Configuring the new triggers

The fork's new feature toggles aren't all wired into the Settings UI yet — they live in `NSUserDefaults` and can be set with `defaults write`:

```bash
# Watched application bundle identifiers (any matching app keeps KYA active)
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.WatchedApplicationBundleIdentifiers \
  -array com.apple.FinalCut com.apple.Logic

# Watched Wi-Fi SSIDs (case-insensitive match)
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.WatchedWiFiSSIDs \
  -array Office-WiFi Home-5G

# Activate while on AC power
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.ActivateOnACPowerEnabled -bool YES

# Drive Alive
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.DriveAliveEnabled -bool YES

# Prevent disk sleep
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.PreventDiskSleepEnabled -bool YES

# Deactivate when battery is fully charged
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.DeactivateOnFullChargeEnabled -bool YES

# Schedule trigger — array of {weekdays:[1..7], startMinutes, endMinutes}
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.ScheduleEnabled -bool YES
# (configure ScheduleWindows via PlistBuddy / `defaults write -array`)

# Activate while a download is in progress
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.DownloadInProgressActivationEnabled -bool YES

# Hide the menu bar countdown (default: shown)
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.MenuBarCountdownDisabled -bool YES
```

`NSWorkspace.shared.open()` of `keepingyouawake:///activate?seconds=N` / `:///deactivate` / `:///toggle` is also exposed as App Intents for Shortcuts.app.

## How does it work?

The app is a thin wrapper around macOS's built-in [`caffeinate`](https://web.archive.org/web/20140604153141/https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/caffeinate.8.html). All upstream caveats apply (e.g. closed-lid sleep on portable Macs is still enforced by macOS).

## Relationship to upstream

This fork tracks `newmarcel/KeepingYouAwake` and ports back any maintenance fixes the original receives. Bug fixes that aren't fork-specific are first proposed upstream where appropriate.

The original `newmarcel/KeepingYouAwake` and `keepingyouawake.app` remain the project of [Marcel Dierkes](https://github.com/newmarcel) and are independently maintained.

## Bot review / CI infrastructure

- **CI** (`.github/workflows/ci.yml`) — every PR runs xcodebuild build, unit tests against the SPM packages, and a URL-scheme E2E that asserts `caffeinate` actually spawns/exits.
- **Release** (`.github/workflows/release.yml`) — every `v*` tag builds a Release-config dmg with ad-hoc signing and uploads it to the matching GitHub Release.
- **CodeQL + OSSF Scorecards** — security audits on PRs and on a weekly schedule.
- **AI review** — CodeRabbit, cubic, Gitar, Socket Security, and Gemini Code Assist all comment on each PR.
- **Dependabot** — npm / GitHub Actions weekly version updates with grouped minor/patch.

## License

MIT. Same license as upstream. Provided image assets are also MIT.

The fork keeps Marcel Dierkes' original copyright and adds its own attribution; see the in-app *About* panel and `Credits.rtf` for full attribution. Upstream's polite request — don't redistribute forks with the same name and icon — is honoured: this fork ships under the display name **KeepingYouAwake (Amphetamine)** and an orange cup icon.

## Old macOS support

Same as upstream:
- [Version 1.6.2](https://github.com/newmarcel/KeepingYouAwake/releases/tag/1.6.2) is the last release that supports macOS Sierra (10.12).
- [Version 1.5.2](https://github.com/newmarcel/KeepingYouAwake/releases/tag/1.5.2) is the last release that supports macOS Yosemite (10.10) / El Capitan (10.11).
