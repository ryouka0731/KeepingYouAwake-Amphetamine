# KeepingYouAwake (Amphetamine)

## Fork Changelog

This fork ([`ryouka0731/KeepingYouAwake-Amphetamine`](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine)) adds Amphetamine-style features on top of the upstream `newmarcel/KeepingYouAwake`. Upstream's history is preserved unchanged below.

### Unreleased

- Turning **Mouse Jiggler** or **Drive Alive** on or off in Settings now applies to the running session immediately. Before, turning the jiggler off kept moving the pointer until the session ended.
- Advanced settings: **Reset to Default** updates the checkboxes right away (upstream bug).
- CI hardening (OpenSSF Scorecard): workflows default to read-only tokens with write access scoped to the jobs that need it; every action is pinned to a commit SHA, and checkout, setup-python, upload-artifact and codeql-action move to their Node 24 majors; Dependabot keeps the pins current; `SECURITY.md` points to private vulnerability reporting.

### v1.7.0-amphetamine.7 (2026-10-06)

#### Security
- Sparkle 2.6.4 → 2.9.6, fixing [GHSA-hg88-v3cw-3qrh](https://github.com/advisories/GHSA-hg88-v3cw-3qrh) (delta-update symlink traversal) and [GHSA-g3hp-f6mg-559v](https://github.com/advisories/GHSA-g3hp-f6mg-559v) (installer XPC listener accepted unvalidated connections). Capped to 2.9.x: Sparkle 2.10 requires macOS 12, above this app's macOS 10.13 minimum. [#107](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/107)

#### Fixes
- **Watched Items settings**: watched Wi-Fi networks can be added again, and the application / download-folder lists show their entries. Since the Active Hours editor (#89), all four lists shared a delegate that made them view-based, so the rows rendered empty and couldn't be edited. [#108](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/108)
- **Watched Items settings**: the pane scrolls when it is taller than the screen allows, instead of running off-screen. [#108](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/108)
- **Watched Items settings**: translated into all 21 app languages (it was English-only). [#108](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/108)

#### Infra
- CI also builds the "(Direct)" scheme that releases ship, so Sparkle/updater breakage fails the PR instead of the release. [#107](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/107)

### v1.7.0-amphetamine.6 (2026-10-06)

#### Fixes
- **Drive Alive keeps external drives active** — besides the startup disk, it rewrites a hidden `.KeepingYouAwake-DriveAlive` file at the root of every mounted external, local, writable volume every 30 s while a session runs, and removes it when the session ends. A non-empty file, directory or symlink already using that name is never overwritten or removed; an empty file of that name is treated as a leftover ping, reused and removed with the session. Resolves the v1.7.0-amphetamine.5 known issue. [#104](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/104)
- Returning to your login session after fast user switching no longer starts an indefinite session when none was running before you switched away (upstream bug). [#105](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/105)
- External audio output trigger: the Core Audio listener holds the monitor weakly, so a device change arriving while the trigger is being turned off can't touch freed memory. [#105](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/105)
- Watched Items: an SSID row abandoned with Escape no longer lingers as an empty row. [#105](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/105)

#### Release tooling
- Appcast build numbers are `major·1000000 + minor·10000 + patch·100 + amphetamine suffix`, keeping update order correct past `amphetamine.9` and across patch releases (unchanged for every release so far); out-of-range components fail the appcast workflow instead of colliding. [#105](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/105)

#### Known issues
- In sandboxed (Xcode-signed) builds, Drive Alive and the download trigger can't reach external volumes or user-picked folders. Released builds are unaffected.

### v1.7.0-amphetamine.5 (2026-10-06)

#### Triggers
- **External audio output trigger** — activate while audio is routed to a non-built-in device (Bluetooth, USB, HDMI, AirPlay, …). Toggle: `ActivateOnExternalAudioOutputEnabled`. [#78](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/78)
- **CPU load trigger** — activate while CPU usage stays above a threshold (default 50 %, `CPULoadActivationThreshold`) for 30 s. Toggle: `ActivateOnCPULoadEnabled`. [#79](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/79)
- **Mouse jiggler** — nudges the pointer by 1 px every 60 s during a session so idle-time "away" detectors stay quiet. Toggle: `MouseJigglerEnabled`. [#77](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/77)
- Disabling a trigger now ends the session it started. [#102](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/102)
- Watched Wi-Fi networks and apps edited at runtime take effect immediately (no relaunch). [#102](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/102)

#### Automation
- **AppleScript / sdef** — `activate kya [for <seconds>]`, `deactivate kya`, `toggle kya`, and `active` / `remaining seconds` / `source` properties. [#84](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/84), [#99](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/99)
- **`kya` CLI** — `kya activate 30m`, `kya deactivate`, `kya toggle`, `kya status [--json]` (Python, no dependencies). [#82](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/82)
- **MCP server** (`kya-mcp-server`) — drive KeepingYouAwake from Claude Code or any MCP client. Requires `mcp>=1.0,<2`. [#80](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/80), [#81](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/81), [#101](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/101)

#### Settings
- **Watched Items pane** — list editors for watched Wi-Fi SSIDs, apps, download folders and schedule windows. [#86](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/86), [#89](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/89)

#### Fixes
- "Activate" from the URL scheme, AppleScript, `kya`, MCP or Shortcuts while already active no longer stops the mouse jiggler, Drive Alive and power monitoring or shows the inactive icon. [#102](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/102)
- **Watched Wi-Fi trigger works on macOS 14+**: KeepingYouAwake now asks for Location access, which macOS requires to read the network name. [#102](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/102)
- Quitting or crashing during a session no longer leaves it reported as active by `kya status` / MCP; dangling activity-log entries are closed on the next launch (`endedReason: "app-terminated"`). [#102](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/102)
- `kya activate` without a duration and MCP `duration: "indefinite"` now really activate indefinitely (they used the default duration). [#102](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/102)
- AppleScript and Shortcuts commands are delivered to this app, never to an upstream KeepingYouAwake that is also installed. [#99](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/99), [#102](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/102)
- Sessions suspended for fast user switching resume with their original trigger. [#102](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/102)
- Menu bar countdown shows next to the icon again. [#75](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/75)
- Release builds use the Direct scheme so Sparkle updates are enabled; the appcast refreshes after each release. [#73](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/73), [#74](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/74), [#76](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/76)

#### Known issues
- **Drive Alive** only keeps the startup disk active; it does not touch external drives yet.

#### Tests / infra
- Main-target XCTest target, SPM test gaps filled, pytest suites for `kya` / MCP, line-coverage gate (37 %), E2E for URL scheme, AppleScript, CLI, activity log, natural expiry, re-activation and crash recovery, Sparkle appcast signature smoke test. [#87](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/87), [#88](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/88), [#90](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/90), [#91](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/91), [#92](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/92), [#93](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/93), [#94](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/94), [#95](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/95), [#96](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/96), [#97](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/97), [#98](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/98), [#102](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/102)

### v1.7.0-amphetamine.4 (2026-05-09)

#### Triggers
- **Schedule trigger** — auto-activate during configurable weekday × time-of-day windows. Defaults: `ScheduleEnabled` (BOOL), `ScheduleWindows` (array of `{weekdays, startMinutes, endMinutes}` dicts; supports past-midnight wrap). [#63](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/63)
- **Download-in-progress trigger** — auto-activate while any file in `DownloadDirectories` (defaults to `~/Downloads`) has a download suffix (`.crdownload`, `.part`, `.download`, `.partial`). Toggle: `DownloadInProgressActivationEnabled`. [#64](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/64)
- **External display trigger source-aware fix** — disconnecting an external monitor no longer kills a user-initiated session that happened to overlap. Honors the `KYAActivationSource` invariant introduced in #27. [#58](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/58)

#### UX
- **Menu bar countdown** — shows `H:MM:SS` / `MM:SS` next to the icon while a finite session is active. Toggle off via `MenuBarCountdownDisabled` (also exposed in Advanced Settings). [#55](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/55), [#62](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/62)
- **Activity log** — every activate/deactivate event is appended to `~/Library/Application Support/KeepingYouAwake/activity.jsonl` (capped at 1000 entries). New menu item **Show Activity Log…** opens it in the user's default editor. Records `endedReason` (`expired` / `user-cancelled` / `trigger-cancelled`) for each closed entry. Closes the entry on natural timer expiration, not just on cancellation. [#59](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/59), [#61](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/61), [#69](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/69), [#72](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/72)
- **Settings UI rows** — new toggles in Advanced for "Hide menu bar countdown", "Activate during scheduled hours", and "Activate while a download is in progress", localized in 22 languages. [#62](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/62), [#65](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/65)

#### Updater (Sparkle auto-update is now fully active)
- **Sparkle URLs re-pointed at the fork** — `KYAAppUpdater` no longer asks upstream's appcast for updates, which was a soft-correctness bug (would have installed upstream binaries over the fork bundle). [#56](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/56)
- **Auto-update appcast pipeline** — new `appcast.yml` workflow + `scripts/generate-appcast.py` generator publishes a signed `appcast.xml` to `gh-pages` after each release. Tarball isolation fix to avoid clobbering the repo's `LICENSE`. [#66](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/66), [#71](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/71)
- **`SUPublicEDKey` baked into the bundle** — paired with `SPARKLE_ED_PRIVATE_KEY` repo secret, Sparkle now verifies every fetched dmg before installing. [#70](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/70)

#### Tests / infra
- Unit tests for fork-added defaults keys and array sanitization (Wi-Fi SSIDs, watched apps). [#57](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/57)
- Unit tests for activity logger (round-trip, cap behaviour, corruption tolerance). [#59](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/59)
- Unit tests for schedule monitor (window matching, wrap-past-midnight). [#63](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/63)
- Unit tests for download activity monitor (suffix detection, transition-only callbacks). [#64](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/64)
- Branch protection on `main` (required Build + Unit tests, strict mode).
- Repo-level auto-merge enabled.

### v1.7.0-amphetamine.3 (2026-05-08)

- Rebrand of the fork: `CFBundleDisplayName = KeepingYouAwake (Amphetamine)`, dual upstream/fork copyright in About panel, multilingual README (EN/JA/ZH-CN/DE/FR), repo renamed to `KeepingYouAwake-Amphetamine`. [#38](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/38)
- Release workflow auto-creates the GitHub Release object on tag push (no more manual `gh release create` before the dmg upload). [#39](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/39)
- macos-15 runner + Xcode 16 (avoids the Xcode 26.0.1 ibtoold crash on `AppIcon.icon`). [#37](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/37)
- Ad-hoc codesigned dmg (still not Apple-notarised — first launch needs right-click → Open).

### v1.7.0-amphetamine.2 (2026-05-08)

- Phase B: session source tracking (`KYAActivationSource`) so a feature trigger can never deactivate a user-initiated timer.
- Multi-bundle watched applications. [#27](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/27), [#28](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/28)
- CI workflow on every PR (build / unit tests / URL-scheme E2E).

### v1.7.0-amphetamine.1 (2026-05-07)

- First Amphetamine-parity release of the fork. Source-only.
  - Prevent disk sleep ([#8](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/8))
  - Deactivate when battery is fully charged ([#9](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/9))
  - Activation duration: until end of day ([#10](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/10))
  - App Intents / Shortcuts.app integration ([#17](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/17))
  - Watched Wi-Fi SSID trigger ([#18](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/18))
  - Activate while on AC power ([#19](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/19))
  - Drive Alive ([#20](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/20))

---

## Upstream Changelog

The remainder of this file mirrors `newmarcel/KeepingYouAwake`'s history.

### v.1.6.8 (2025-09-12)

- added a light/dark/clear app icon for macOS 26 Tahoe

### v1.6.7 (2025-07-18)

- fixed two issues with the "Activate when an external display is connected" advanced setting:
	- fixed an issue where multiple `caffeinate` tasks were spawned when an external display was connected ([#203](https://github.com/newmarcel/KeepingYouAwake/issues/203))
	- fixed an issue where a mirrored display was not treated internally as external display ([#210](https://github.com/newmarcel/KeepingYouAwake/issues/210))
- fixed an issue where the menu bar icon did not update properly when the URL scheme was used to activate or deactivate ([#224](https://github.com/newmarcel/KeepingYouAwake/issues/224))
- updated the Spanish translations ([#223](https://github.com/newmarcel/KeepingYouAwake/pull/223))
	- *Thank you [agusbattista](https://github.com/agusbattista)!*
- added Vietnamese translations ([#222](https://github.com/newmarcel/KeepingYouAwake/pull/222))
	- *Thank you [ksajolaer](https://github.com/ksajolaer)!*
- added Hindi translations ([#232](https://github.com/newmarcel/KeepingYouAwake/pull/232))
	- *Thank you [AnandChowdhary](https://github.com/AnandChowdhary)!*
- added Greek and Finnish translations ([#230](https://github.com/newmarcel/KeepingYouAwake/pull/230))
	- *Thank you [ziz1zaza](https://github.com/ziz1zaza)!*
- since macOS 26 Tahoe allows hiding the app's menu bar icon, the settings window was extended to handle this situation better:
	- the settings window will now be presented when the app is launched again while running
	- added a Quit button to the General settings
- updated the app icon to not be trapped in a grey box on macOS 26 Tahoe

### v1.6.6 (2024-10-26)

- added Slovak translations ([#209](https://github.com/newmarcel/KeepingYouAwake/pull/209))
    - *Thank you Tomáš Švec!*
- updated the Turkish translations ([#212](https://github.com/newmarcel/KeepingYouAwake/pull/212))
	- *Thank you [egesucu](https://github.com/egesucu)!*
- updated the Chinese translations ([#213](https://github.com/newmarcel/KeepingYouAwake/pull/213))
	- *Thank you [LZhenHong](https://github.com/LZhenHong)!*
- updated the Russian translations ([#216](https://github.com/newmarcel/KeepingYouAwake/pull/216))
	- *Thank you [user334](https://github.com/user334)!*
- updated the Ukrainian translations ([#218](https://github.com/newmarcel/KeepingYouAwake/pull/218))
	- *Thank you [gelosi](https://github.com/gelosi)!*
- updated Sparkle to v2.6.4 ([#214](https://github.com/newmarcel/KeepingYouAwake/pull/214))

### v1.6.5 (2023-10-02)

- updated the Traditional Chinese translation ([#198](https://github.com/newmarcel/KeepingYouAwake/pull/198))
    - *Thank you [YuerLee](https://github.com/YuerLee)!*
- updated the French translation ([#201](https://github.com/newmarcel/KeepingYouAwake/pull/201))
    - *Thank you [tmuguet](https://github.com/tmuguet)!*
- removed the advanced setting "Disable menu bar icon highlight color", this behavior can still be enabled using the `defaults` command: `defaults write info.marcel-dierkes.KeepingYouAwake info.marcel-dierkes.KeepingYouAwake.MenuBarIconHighlightDisabled -bool YES`

### v1.6.4 (2022-11-14)

- shows in the "Login Items" > "Open at Login" section in System Settings on macOS Ventura if "Start at Login" is enabled
- fixes a regression introduced in 1.6.3 where the `keepingyouawake:///activate` URL scheme stopped working as expected ([#193](https://github.com/newmarcel/KeepingYouAwake/issues/193))

### v1.6.3 (2022-10-30)

- added Battery preferences with support for Low Power Mode on compatible Macs ([#181](https://github.com/newmarcel/KeepingYouAwake/pull/181))
- added a Japanese translation ([#182](https://github.com/newmarcel/KeepingYouAwake/issues/182))
    - *Thank you [hiroto-t](https://github.com/hiroto-t)!*
- updated the Turkish translation ([#183](https://github.com/newmarcel/KeepingYouAwake/issues/183))
    - *Thank you [egemenu](https://github.com/egemenu)!*
- added an Italian translation ([#184](https://github.com/newmarcel/KeepingYouAwake/issues/184))
    - *Thank you [gmcinalli](https://github.com/gmcinalli)!*
- added an advanced preference to auto-activate when an external screen is connected ([#186](https://github.com/newmarcel/KeepingYouAwake/issues/186), [#84](https://github.com/newmarcel/KeepingYouAwake/issues/84))
	- *Thank you [sturza](https://github.com/sturza)!*
 - added an advanced preference to deactivate while another user account is active

**Please note: The 1.6.3 release does not support macOS Sierra anymore. You can continue using version 1.6.2 on this version of macOS.**

### v1.6.2 (2022-02-20)

- updated the Danish translation ([#171](https://github.com/newmarcel/KeepingYouAwake/pull/171), [#180](https://github.com/newmarcel/KeepingYouAwake/pull/180))
    - *Thank you [JacobSchriver](https://github.com/JacobSchriver)!*
- updated the [Sparkle](https://github.com/sparkle-project/Sparkle) update framework to version 2.0 ([#178](https://github.com/newmarcel/KeepingYouAwake/pull/178))
- added a Ukrainian translation ([#179](https://github.com/newmarcel/KeepingYouAwake/issues/179))
    - *Thank you [gelosi](https://github.com/gelosi)!*

### v1.6.1 (2021-07-24)

- added support for notifications, use `System Preferences` to manage notification settings ([#164](https://github.com/newmarcel/KeepingYouAwake/pull/164))
  - please note, this feature is only available on macOS 11 or newer; the previous experimental notifications support has been removed
- updated the French translation ([#146](https://github.com/newmarcel/KeepingYouAwake/issues/146), [#169](https://github.com/newmarcel/KeepingYouAwake/pull/169))
    - *Thank you [alexandreleroux](https://github.com/alexandreleroux)!*

### v1.6.0 (2020-11-06)

- raised minimum deployment target to macOS Sierra ([#142](https://github.com/newmarcel/KeepingYouAwake/pull/142))
- updated icons using the macOS Big Sur style ([#141](https://github.com/newmarcel/KeepingYouAwake/pull/141))
- added support for the arm64 architecture on macOS Big Sur
- created an official website [https://keepingyouawake.app/](https://keepingyouawake.app/)
- added a Russian translation ([#147](https://github.com/newmarcel/KeepingYouAwake/issues/147), [#155](https://github.com/newmarcel/KeepingYouAwake/pull/155))
    - *Thank you [Kromsator](https://github.com/Kromsator)!*

### v1.5.2 (2020-07-04)

- added the ability to allow the display to sleep ([#148](https://github.com/newmarcel/KeepingYouAwake/issues/148))
	- _Thanks [creamelectricart](https://github.com/creamelectricart)!_

### v1.5.1 (2019-12-26)

- added the ability to customize activation durations in _Preferences_ ([#132](https://github.com/newmarcel/KeepingYouAwake/pull/132))
- added an advanced preference to quit the app when the activation duration is over ([#133](https://github.com/newmarcel/KeepingYouAwake/pull/133))
	- _Thanks [jamesgecko](https://github.com/jamesgecko) for the [suggestion](https://github.com/newmarcel/KeepingYouAwake/issues/128)!_
- added an Indonesian translation ([#137](https://github.com/newmarcel/KeepingYouAwake/pull/137))
    - *Thank you [ibnuh](https://github.com/ibnuh)!*

**Please note: The 1.5.x series of releases will be the last supporting macOS Yosemite and El Capitan. If you see any critical reason for supporting those, please leave a comment on [GitHub](https://github.com/newmarcel/KeepingYouAwake/issues/126).**

### v1.5.0 (2019-01-20)

- added an _Updates_ tab to _Preferences_ ([#107](https://github.com/newmarcel/KeepingYouAwake/pull/107))
- enabled the _Hardened Runtime_ security feature ([#111](https://github.com/newmarcel/KeepingYouAwake/pull/111))
- enabled the _App Sandbox_ security feature ([#112](https://github.com/newmarcel/KeepingYouAwake/pull/112))
	- custom icons need to be placed in `~/Library/Containers/info.marcel-dierkes.KeepingYouAwake/Data/Documents` now and will be migrated during the app update
- _Start at login_ uses a launcher helper app now ([#110](https://github.com/newmarcel/KeepingYouAwake/pull/110))
    - the previous login item is not compatible anymore and **it is recommended to disable _Start at login_ before updating**!
    - please check [this wiki page](https://github.com/newmarcel/KeepingYouAwake/wiki/1.5:-Start-at-Login-Problems) if you encounter problems
- updated Sparkle to the `ui-separation-and-xpc` version ([#109](https://github.com/newmarcel/KeepingYouAwake/pull/109)) ([#113](https://github.com/newmarcel/KeepingYouAwake/pull/113))

### v1.4.3 (2018-08-15)

- the icon can be dragged out of the menubar to quit on macOS Sierra and newer ([#82](https://github.com/newmarcel/KeepingYouAwake/issues/82), suggested by [Eitot](https://github.com/Eitot))
- support for the `keepingyouawake:///toggle` action ([#96](https://github.com/newmarcel/KeepingYouAwake/pull/96)), *thanks [code918](https://github.com/code918)*!
- new localizations
	- Polish ([#90](https://github.com/newmarcel/KeepingYouAwake/pull/90)) _Thank you [karolgorecki](https://github.com/karolgorecki)!_
	- Portuguese ([#94](https://github.com/newmarcel/KeepingYouAwake/pull/94)) _Thank you [luizpedone](https://github.com/luizpedone)!_
	- Update German for informal style ([#74](https://github.com/newmarcel/KeepingYouAwake/pull/74)) _Thank you [Eitot](https://github.com/Eitot)!_
- allows Dark Aqua appearance on macOS Mojave

### v1.4.2 (2017-09-16)

- support cmd+w and cmd+q keyboard shortcuts in the preferences window ([#56](https://github.com/newmarcel/KeepingYouAwake/issues/56))
- preferences now remember the window position
- allow option-click on the menubar icon ([#59](https://github.com/newmarcel/KeepingYouAwake/issues/59))
- fixed the incorrect fullscreen behavior of the preferences window ([#71](https://github.com/newmarcel/KeepingYouAwake/pull/71)), *thanks [Eitot](https://github.com/Eitot)!*
- more localization updates
	- Spanish ([#70](https://github.com/newmarcel/KeepingYouAwake/pull/70))
		- *Thank you [nbalonso](https://github.com/nbalonso)!*
	- Dutch ([#73](https://github.com/newmarcel/KeepingYouAwake/pull/73))
		- *Thank you [Eitot](https://github.com/Eitot)!*
	- improvements to the French translation by [alexandreleroux](https://github.com/alexandreleroux) ([#63](https://github.com/newmarcel/KeepingYouAwake/pull/63))
	- Danish ([#78](https://github.com/newmarcel/KeepingYouAwake/pull/78))
		- *Thank you [JacobSchriver](https://github.com/JacobSchriver)!*
	- Turkish ([#79](https://github.com/newmarcel/KeepingYouAwake/pull/79))
		- *Thank you [durul](https://github.com/durul)!*
	- Chinese (Simplified) ([#87](https://github.com/newmarcel/KeepingYouAwake/pull/87))
		- *Thank you [zangyongyi](https://github.com/zangyongyi)!*
	- Chinese (Traditional zh-Hant-TW) ([#89](https://github.com/newmarcel/KeepingYouAwake/pull/89))
		- *Thank you [passerbyid](https://github.com/passerbyid)!*
- updated Sparkle to 1.18.1

### v1.4.1 (2016-12-30)

- Localization support
	- German
	- French ([Issue #51](https://github.com/newmarcel/KeepingYouAwake/issues/51))
		- *Thank you [rei-vilo](https://github.com/rei-vilo)!*
	- Korean ([Issue #64](https://github.com/newmarcel/KeepingYouAwake/pull/64))
		- *Thank you [Pusnow](https://github.com/Pusnow)!*
- removed advanced preference to allow the display to sleep *(didn't work properly and lead to confusion)*
	- the `info.marcel-dierkes.KeepingYouAwake.AllowDisplaySleep` preference was removed
	- a similar, more powerful replacement feature will be introduced soon

### v1.4 (2016-04-16)

- Added a preferences window that replaces seldom used menu items and surfaces advanced and experimental preferences
- You can now set the default activation duration for the menu bar icon in preferences
- Removed the advanced preference for `info.marcel-dierkes.KeepingYouAwake.PreventSleepOnACPower`
- Added an advanced preference to allow display sleep while still preventing system sleep ([Issue #25](https://github.com/newmarcel/KeepingYouAwake/issues/25))
- Ability to set a battery level on MacBooks where the app will deactivate itself ([Issue #24](https://github.com/newmarcel/KeepingYouAwake/issues/24))
	- *Thank you [timbru31](https://github.com/timbru31) for the suggestion!*
- Upgraded to Sparkle 1.14.0 to fix potential security issues

### v1.3.1 (2015-12-08)

- Fixed Sparkle Updates *(Broken thanks to App Transport Security in OS X 10.11 and GitHub disabling HTTPS for pages)* If you know someone with Version 1.3.0, please let them know that 1.3.1 is available and can be downloaded manually to receive future updates. This is a nightmare come true… 😱
- Fixed rendering for custom icons: They are now rendered as template images
- Added advanced settings to disable the blue highlight rectangle on click. Enable it with *(replace YES with NO to disable it again)*:

		defaults write info.marcel-dierkes.KeepingYouAwake info.marcel-dierkes.KeepingYouAwake.MenuBarIconHighlightDisabled -bool YES



### v1.3 (2015-11-02)

- Basic command line interface through URI schemes
	- *Thank you [KyleKing](https://github.com/KyleKing) for the suggestion!*
	- you can activate/deactivate the sleep timer with unlimited time intervals
	- you can open *KeepingYouAwake* from the command line with a custom sleep timer duration
	- the *seconds*, *minutes* and *hours* parameters are rounded up to the nearest integer number and cannot be combined at the moment

	open keepingyouawake://  
	open keepingyouawake:///activate    # indefinite duration  
	open keepingyouawake:///activate?seconds=5  
	open keepingyouawake:///activate?minutes=5  
	open keepingyouawake:///activate?hours=5  
	open keepingyouawake:///deactivate

- Support for custom menu bar icons. Just place four images named `ActiveIcon.png`, `ActiveIcon@2x.png`, `InactiveIcon.png`, `InactiveIcon@2x.png` in your `~/Library/Application Support/KeepingYouAwake/` folder. The recommended size for these images is 22x20 pts
- hold down the option key and click inside the *"Activate for Duration"* menu to set the default duration for the menu bar icon


### v1.2.1 (2015-01-11)

- Fixed an issue where "Start at Login" would crash when clicked multiple times in a row *(Fixed by [registered99](https://github.com/registered99), thank you!)*
- Less aggressive awake handling when the MacBook lid is closed by using the `caffeinate -di` command instead of `caffeinate -disu`
- You can revert back to the previous behaviour by pasting the following snippet into *Terminal.app*:

		defaults write info.marcel-dierkes.KeepingYouAwake.PreventSleepOnACPower -bool YES

- `ctrl` + `click` will now display the menu

### v1.2 (2014-11-23)
- There are no significant changes since beta1
- Tweaked the experimental *(and hidden)* notifications
- You can enable the notifications preview by pasting the following snippet into *Terminal.app*:

		defaults write info.marcel-dierkes.KeepingYouAwake info.marcel-dierkes.KeepingYouAwake.NotificationsEnabled -bool YES
		
- and to disable it again:
	
		defaults write info.marcel-dierkes.KeepingYouAwake info.marcel-dierkes.KeepingYouAwake.NotificationsEnabled -bool NO


### v1.2beta1
- Activation timer
- [Sparkle](http://sparkle-project.org) integration for updates
	- Sparkle will check for updates once a day
	- A second beta will follow in the coming days to test automatic updates
- This is **beta** software. If you notice any issues, please report them [here](https://github.com/newmarcel/KeepingYouAwake/issues/)

### v1.1 (2014-11-13)
- Signed with Developer ID
- Start At Login menu item added

### v1.0 (2014-10-19)
- Initial Release
- Keeps your Mac awake
