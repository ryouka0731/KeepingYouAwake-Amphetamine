# KeepingYouAwake (Amphetamine)

🌐 [English](README.md) · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · **Deutsch** · [Français](README.fr.md)

> **Community-Fork** von [`newmarcel/KeepingYouAwake`](https://github.com/newmarcel/KeepingYouAwake), gepflegt von [@ryouka0731](https://github.com/ryouka0731), der dem vertrauten `caffeinate`-Wrapper **Amphetamine-ähnliche Funktionen** hinzufügt. Auf Wunsch des Upstream-Maintainers werden Name und Icon der App bewusst unterschiedlich gehalten (oranger Becher, Suffix im Anzeigenamen).

KeepingYouAwake (Amphetamine) ist ein schlankes Menüleisten-Tool für macOS 10.13+, das einen Mac für eine vordefinierte Dauer — oder solange ein Trigger aktiv ist — am Schlafmodus hindert.

## Was zusätzlich zu Upstream 1.6.8 enthalten ist

| # | Funktion | PR |
|---|----------|----|
| 1 | Festplattenschlaf verhindern (`caffeinate -m`) | [#8](https://github.com/ryouka0731/KeepingYouAwake/pull/8) |
| 2 | Bei vollständig geladenem Akku deaktivieren | [#9](https://github.com/ryouka0731/KeepingYouAwake/pull/9) |
| 3 | Aktivierungsdauer: Bis Tagesende (nächster Mitternacht) | [#10](https://github.com/ryouka0731/KeepingYouAwake/pull/10) |
| 4 | App-Intents- / Shortcuts.app-Integration (`Activate` / `Deactivate` / `Toggle`) | [#17](https://github.com/ryouka0731/KeepingYouAwake/pull/17) |
| 5 | Trigger: Verbindung mit überwachter Wi-Fi-SSID | [#18](https://github.com/ryouka0731/KeepingYouAwake/pull/18) |
| 6 | Trigger: Netzbetrieb (Übergangs-erkennung) | [#19](https://github.com/ryouka0731/KeepingYouAwake/pull/19) |
| 7 | Drive Alive — externe Laufwerke während der Aktivierung in Bewegung halten | [#20](https://github.com/ryouka0731/KeepingYouAwake/pull/20) |
| 8 | Trigger: laufende überwachte Anwendung (mehrere Bundle-IDs) | [#27](https://github.com/ryouka0731/KeepingYouAwake/pull/27) / [#28](https://github.com/ryouka0731/KeepingYouAwake/pull/28) |
| 9 | Trigger: Zeitplan (Wochentag × Uhrzeit-Fenster) | [#63](https://github.com/ryouka0731/KeepingYouAwake/pull/63) |
| 10 | Trigger: laufender Download (`*.crdownload`, `*.part`, …) | [#64](https://github.com/ryouka0731/KeepingYouAwake/pull/64) |
| 11 | Restzeit-Countdown in der Menüleiste neben dem Symbol | [#55](https://github.com/ryouka0731/KeepingYouAwake/pull/55) |
| 12 | Aktivitätsprotokoll (`~/Library/Application Support/KeepingYouAwake/activity.jsonl`) | [#59](https://github.com/ryouka0731/KeepingYouAwake/pull/59) / [#61](https://github.com/ryouka0731/KeepingYouAwake/pull/61) |

Plus Session-Source-Tracking, damit Feature-Trigger niemals eine vom Benutzer gestartete Sitzung versehentlich beenden (Externer-Display-Trigger wurde dafür in [#58](https://github.com/ryouka0731/KeepingYouAwake/pull/58) source-aware nachgezogen). Außerdem ein Sparkle-Auto-Update-Workflow für `appcast.xml` ([#66](https://github.com/ryouka0731/KeepingYouAwake/pull/66) — verbleibende manuelle Schritte in `docs/sparkle-auto-update-setup.md`).

## Installation

### Download (empfohlen)

[Releases →](https://github.com/ryouka0731/KeepingYouAwake/releases)

Jedes Release enthält eine `KeepingYouAwake-<tag>.dmg` und eine `.dmg.sha256`. Mangels Apple Developer ID wird das Bundle nur ad-hoc signiert, nicht von Apple notarisiert. Erststart:

1. dmg mounten, `KeepingYouAwake.app` nach `/Applications` ziehen.
2. **Rechtsklick → Öffnen** → im Dialog *Öffnen* bestätigen.
3. (Oder in Systemeinstellungen → Datenschutz & Sicherheit → *Trotzdem öffnen*.)

Danach startet die App normal.

### Aus Quellcode bauen

```bash
git clone https://github.com/ryouka0731/KeepingYouAwake.git
cd KeepingYouAwake
open KeepingYouAwake.xcworkspace
```

Mit Xcode 16 oder neuer öffnen (das Icon nutzt das mit Xcode 16 eingeführte Icon-Composer-Format) und ausführen. Zielplattform: macOS 10.13+.

## Trigger konfigurieren

Funktionen, die noch keine Settings-UI haben, lassen sich per `defaults write` setzen:

```bash
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.WatchedApplicationBundleIdentifiers \
  -array com.apple.FinalCut com.apple.Logic

defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.WatchedWiFiSSIDs \
  -array Office-WiFi Home-5G

defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.ActivateOnACPowerEnabled -bool YES

defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.DriveAliveEnabled -bool YES

defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.PreventDiskSleepEnabled -bool YES

defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.DeactivateOnFullChargeEnabled -bool YES

# Zeitplan-Trigger (Fenster via PlistBuddy konfigurieren)
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.ScheduleEnabled -bool YES

# Aktivieren während ein Download läuft
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.DownloadInProgressActivationEnabled -bool YES

# Menüleisten-Countdown ausblenden (Standard: anzeigen)
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.MenuBarCountdownDisabled -bool YES
```

Das URL-Schema `keepingyouawake:///activate?seconds=N` / `:///deactivate` / `:///toggle` ist auch über App-Intents in Shortcuts.app verfügbar.

## Funktionsweise

Die App ist ein dünner Wrapper um macOS' eingebautes [`caffeinate`](https://web.archive.org/web/20140604153141/https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/caffeinate.8.html). Alle Upstream-Einschränkungen gelten weiterhin (z. B. Schlaf bei geschlossenem Deckel von macOS erzwungen).

## Verhältnis zum Upstream

Dieser Fork verfolgt `newmarcel/KeepingYouAwake` und übernimmt Wartungs-Fixes von dort. Bug-Fixes, die nicht fork-spezifisch sind, werden gegebenenfalls zuerst dem Upstream vorgeschlagen.

Das Originalprojekt `newmarcel/KeepingYouAwake` und `keepingyouawake.app` werden weiterhin unabhängig von [Marcel Dierkes](https://github.com/newmarcel) gepflegt.

## Bot-Review / CI

- **CI** (`.github/workflows/ci.yml`) — jedes PR durchläuft xcodebuild build, Unit-Tests gegen die SPM-Pakete und einen URL-Scheme-E2E.
- **Release** (`.github/workflows/release.yml`) — jeder `v*`-Tag baut eine Release-DMG, ad-hoc signiert und auf das passende GitHub-Release hochgeladen.
- **CodeQL + OSSF Scorecards** — Sicherheits-Audits bei PRs und wöchentlich.
- **AI-Review** — CodeRabbit, cubic, Gitar, Socket Security und Gemini Code Assist kommentieren jedes PR.
- **Dependabot** — wöchentliche Aktualisierungen von npm und GitHub Actions, gruppiert nach Minor/Patch.

## Lizenz

MIT, identisch zum Upstream. Bildmaterialien ebenfalls unter MIT.

Der Fork behält Marcel Dierkes' ursprüngliche Copyright-Angabe und ergänzt eine eigene (siehe in der App: *About* und `Credits.rtf`). Die höfliche Bitte des Upstreams — keine Re-Distribution unter gleichem Namen und Icon — wird umgesetzt: dieser Fork erscheint als **KeepingYouAwake (Amphetamine)** mit oranger Becher-Icon.

## Ältere macOS-Versionen

Wie beim Upstream:
- [Version 1.6.2](https://github.com/newmarcel/KeepingYouAwake/releases/tag/1.6.2) ist die letzte Version mit Sierra-Unterstützung (10.12).
- [Version 1.5.2](https://github.com/newmarcel/KeepingYouAwake/releases/tag/1.5.2) ist die letzte Version mit Yosemite (10.10) / El Capitan (10.11).
