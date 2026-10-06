# KeepingYouAwake (Amphetamine)

🌐 [English](README.md) · **日本語** · [简体中文](README.zh-CN.md) · [Deutsch](README.de.md) · [Français](README.fr.md)

> [`newmarcel/KeepingYouAwake`](https://github.com/newmarcel/KeepingYouAwake) のコミュニティフォーク (メンテナ: [@ryouka0731](https://github.com/ryouka0731))。慣れ親しんだ `caffeinate` ラッパーに **Amphetamine 風の機能** を追加しています。upstream メンテナの依頼に従い、アプリの表示名とアイコン (橙色のカップ) は本家と区別しています。

KeepingYouAwake (Amphetamine) は macOS 10.13 以降向けの軽量なメニューバーユーティリティです。決めた時間のあいだ、または条件 (トリガー) を満たしているあいだ、Mac をスリープさせません。

## upstream 1.6.8 から追加された機能

### 自動で有効にするトリガー

| 機能 | PR |
|------|----|
| 指定した Wi-Fi ネットワーク (SSID) に接続中 | [#18](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/18) |
| AC 電源に接続中 | [#19](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/19) |
| 指定したアプリのいずれかが起動中 | [#27](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/27) / [#28](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/28) |
| 曜日 × 時間帯のスケジュール (深夜 0 時をまたぐ時間帯にも対応) | [#63](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/63) |
| ダウンロード進行中 (`*.crdownload`、`*.part` など) | [#64](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/64) |
| 音声を外部デバイス (Bluetooth、USB、HDMI、AirPlay など) に出力中 | [#78](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/78) |
| CPU 使用率がしきい値 (既定 50%) を 30 秒以上超えているあいだ | [#79](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/79) |

トリガーで始まったセッションは、そのトリガーの条件が終わると自動で終了します。手動で始めたセッションをトリガーが止めることはありません。トリガーを設定でオフにすると、そのトリガーが始めたセッションも終了します。

### スリープ防止の強化

| 機能 | PR |
|------|----|
| ディスクのスリープも防止 (`caffeinate -m`) | [#8](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/8) |
| Drive Alive — 有効中は起動ディスクと外付けドライブを回し続ける | [#20](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/20) / [#104](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/104) |
| マウスジグラー — 有効中は 60 秒ごとにポインタを 1px 動かし、アイドル検出 (チャットの「離席中」など) を防ぐ | [#77](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/77) |
| バッテリーが満充電になったら停止 | [#9](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/9) |
| 継続時間「今日の終わりまで」(次の午前 0 時まで) | [#10](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/10) |

### 表示・記録

| 機能 | PR |
|------|----|
| メニューバーのアイコン横に残り時間をカウントダウン表示 | [#55](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/55) |
| アクティビティログ — 開始・終了とその理由を JSONL に記録 (メニューの **アクティビティログを表示…**) | [#59](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/59) / [#72](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/72) |
| 設定の **監視対象** タブ — Wi-Fi・アプリ・ダウンロードフォルダ・時間帯を編集 | [#86](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/86) / [#89](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/89) / [#108](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/108) |

### 外部からの操作

| 機能 | PR |
|------|----|
| ショートカット.app のアクション (Activate / Deactivate / Toggle KeepingYouAwake) | [#17](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/17) |
| AppleScript | [#84](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/84) |
| `kya` コマンドラインツール | [#82](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/82) |
| MCP サーバー (`kya-mcp-server`) — Claude Code などの AI ツールから操作 | [#81](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/81) |
| Sparkle による自動アップデート | [#66](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/66) / [#107](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/pull/107) |

リリースごとの変更点は [CHANGELOG.md](CHANGELOG.md) を参照してください。

## インストール

### ダウンロード (推奨)

[Releases ページ →](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/releases)

各リリースに `KeepingYouAwake-<tag>.dmg` と `.dmg.sha256` を添付しています。Apple Developer ID を持っていないため、**ad-hoc 署名のみで公証されていません**。初回だけ次の手順で起動してください。

1. dmg を開き、`KeepingYouAwake.app` を `/Applications` にドラッグします。
2. アプリを **右クリック → 開く** し、ダイアログで「開く」を選びます。
3. (または、一度起動に失敗したあとで **システム設定 → プライバシーとセキュリティ → このまま開く** を選びます。)

2 回目以降は普通に起動できます。インストール後のアップデートは、設定の **アップデート** タブ (Sparkle) から受け取れます。

### ソースからビルド

```bash
git clone https://github.com/ryouka0731/KeepingYouAwake-Amphetamine.git
cd KeepingYouAwake-Amphetamine
open KeepingYouAwake.xcworkspace
```

Xcode 16 以降で開いて実行します (アイコンが Xcode 16 で導入された Icon Composer 形式のため)。自動アップデート付きの配布版と同じものをビルドするには、スキーム **KeepingYouAwake (Direct)** を選びます。

## 設定

ほとんどの機能は設定画面から設定できます。

- **高度な設定** タブ — AC 電源・外部ディスプレイ・スケジュール・ダウンロード・外部音声出力・CPU 負荷の各トリガーのオン・オフ、ディスクスリープ防止、Drive Alive、マウスジグラー、満充電で停止、メニューバーのカウントダウン表示。
- **監視対象** タブ — 監視する Wi-Fi ネットワーク、アプリ、ダウンロードフォルダ、有効にする時間帯。**Wi-Fi とアプリのトリガーにはオン・オフのスイッチがなく、ここに項目を登録すると有効になります** (スケジュールとダウンロードのトリガーは、ここで時間帯やフォルダを登録したうえで「高度な設定」でオンにします)。

**Wi-Fi トリガーについて:** 「監視対象」の Wi-Fi ネットワークの **+** から、いま接続中のネットワークを選んで追加できます (名前を直接入力することもできます)。macOS 14 以降では、接続中の Wi-Fi 名を読むために位置情報の許可が必要です。初めて **+** を押すと許可を求めるダイアログが出るので、許可してください。位置情報は記録も送信もしません。

設定画面にない項目は `defaults write` で変更できます。

```bash
# CPU 負荷トリガーのしきい値 (%、1〜99、既定 50)
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.CPULoadActivationThreshold -float 70
```

## 外部からの操作

### URL スキーム

```bash
open "keepingyouawake:///activate?seconds=1800"   # 30 分 (seconds=0 で無期限)
open "keepingyouawake:///deactivate"
open "keepingyouawake:///toggle"
```

### AppleScript

```applescript
tell application "KeepingYouAwake" to activate kya for 1800   -- 秒数を省略すると無期限
tell application "KeepingYouAwake" to deactivate kya
tell application "KeepingYouAwake" to get active of kya       -- remaining seconds / source も取得可
```

### `kya` コマンドラインツール

```bash
uv tool install "git+https://github.com/ryouka0731/KeepingYouAwake-Amphetamine.git#subdirectory=tools/cli"

kya activate 30m          # 2h、45s、1h30m なども可。省略すると無期限
kya activate --until-end-of-day
kya deactivate
kya status                # 有効なら終了コード 0、無効なら 1
```

詳しくは [tools/cli/README.md](tools/cli/README.md) を参照してください。

### MCP サーバー (Claude Code など)

```bash
uv tool install "git+https://github.com/ryouka0731/KeepingYouAwake-Amphetamine.git#subdirectory=tools/mcp-server"
```

`kya_activate` / `kya_deactivate` / `kya_toggle` / `kya_status` などのツールを提供します。設定方法は [tools/mcp-server/README.md](tools/mcp-server/README.md) を参照してください。

## 動作の仕組み

macOS 標準の [`caffeinate`](https://web.archive.org/web/20140604153141/https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/caffeinate.8.html) を呼び出す薄いラッパーです。upstream と同じ制約があります (たとえば、MacBook の蓋を閉じると macOS 自身がスリープを強制します)。

## upstream との関係

このフォークは `newmarcel/KeepingYouAwake` を追いかけ、upstream のメンテナンス修正を取り込みます。フォーク固有でないバグ修正は、適切な場合 upstream にも提案します。

オリジナルの `newmarcel/KeepingYouAwake` と `keepingyouawake.app` は、引き続き [Marcel Dierkes 氏](https://github.com/newmarcel) のプロジェクトです。

## 開発・CI

- **CI** (`.github/workflows/ci.yml`) — PR ごとに、ビルド (配布用の Direct スキームを含む)、ユニットテスト (カバレッジ 37% 以上)、Python ツールのテスト、URL スキーム・CLI・アクティビティログの E2E、Sparkle の appcast の署名検証を実行します。
- **リリース** (`.github/workflows/release.yml`) — `v*` タグの push で dmg をビルドして GitHub Release に添付し、Sparkle の appcast を更新します。
- **セキュリティ** — CodeQL と OpenSSF Scorecard を実行しています。Actions は commit SHA で、CI の Python パッケージはハッシュで固定し、Dependabot が更新します。脆弱性の報告方法は [SECURITY.md](SECURITY.md) を参照してください。
- **AI レビュー** — CodeRabbit / cubic / Sourcery などが各 PR にコメントします。

## ライセンス

MIT (upstream と同じ)。画像アセットも MIT です。

フォークは Marcel Dierkes 氏の著作権表示を残したうえで、フォークとしての表示を追加しています (アプリ内の *About* と `Credits.rtf`)。同じ名前・アイコンでフォークを再配布しないという upstream の依頼を尊重し、表示名 **KeepingYouAwake (Amphetamine)** と橙色のカップアイコンで配布しています。

## 古い macOS への対応

upstream と同じです。

- [Version 1.6.2](https://github.com/newmarcel/KeepingYouAwake/releases/tag/1.6.2) が macOS Sierra (10.12) に対応する最後のバージョンです。
- [Version 1.5.2](https://github.com/newmarcel/KeepingYouAwake/releases/tag/1.5.2) が macOS Yosemite (10.10) / El Capitan (10.11) に対応する最後のバージョンです。
