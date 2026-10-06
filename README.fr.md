# KeepingYouAwake (Amphetamine)

🌐 [English](README.md) · [日本語](README.ja.md) · [简体中文](README.zh-CN.md) · [Deutsch](README.de.md) · **Français**

> **Fork communautaire** de [`newmarcel/KeepingYouAwake`](https://github.com/newmarcel/KeepingYouAwake) maintenu par [@ryouka0731](https://github.com/ryouka0731), qui apporte des **fonctionnalités à la Amphetamine** au familier wrapper `caffeinate`. Le nom et l'icône de l'application sont volontairement distincts (tasse orange, suffixe sur le nom d'affichage) à la demande du mainteneur amont.

KeepingYouAwake (Amphetamine) est un petit utilitaire de barre de menus pour macOS 10.13+ qui empêche un Mac d'entrer en veille pendant une durée prédéfinie — ou tant qu'un déclencheur reste actif.

## Ce qui est ajouté par rapport à l'amont 1.6.8

| # | Fonctionnalité | PR |
|---|----------------|----|
| 1 | Empêcher la veille du disque (`caffeinate -m`) | [#8](https://github.com/ryouka0731/KeepingYouAwake/pull/8) |
| 2 | Désactiver lorsque la batterie est pleine | [#9](https://github.com/ryouka0731/KeepingYouAwake/pull/9) |
| 3 | Durée d'activation : jusqu'à la fin de la journée (prochain minuit) | [#10](https://github.com/ryouka0731/KeepingYouAwake/pull/10) |
| 4 | Intégration App Intents / Shortcuts.app (`Activate` / `Deactivate` / `Toggle`) | [#17](https://github.com/ryouka0731/KeepingYouAwake/pull/17) |
| 5 | Déclencheur : connecté à un SSID Wi-Fi surveillé | [#18](https://github.com/ryouka0731/KeepingYouAwake/pull/18) |
| 6 | Déclencheur : sur secteur (transition reconnue) | [#19](https://github.com/ryouka0731/KeepingYouAwake/pull/19) |
| 7 | Drive Alive — garder les disques externes actifs pendant l'activation | [#20](https://github.com/ryouka0731/KeepingYouAwake/pull/20) |
| 8 | Déclencheur : application surveillée en cours d'exécution (plusieurs bundle ID) | [#27](https://github.com/ryouka0731/KeepingYouAwake/pull/27) / [#28](https://github.com/ryouka0731/KeepingYouAwake/pull/28) |
| 9 | Déclencheur : planification (jour de la semaine × créneau horaire) | [#63](https://github.com/ryouka0731/KeepingYouAwake/pull/63) |
| 10 | Déclencheur : téléchargement en cours (`*.crdownload`, `*.part`, …) | [#64](https://github.com/ryouka0731/KeepingYouAwake/pull/64) |
| 11 | Compte à rebours dans la barre des menus à côté de l'icône | [#55](https://github.com/ryouka0731/KeepingYouAwake/pull/55) |
| 12 | Journal d'activité (`~/Library/Application Support/KeepingYouAwake/activity.jsonl`) | [#59](https://github.com/ryouka0731/KeepingYouAwake/pull/59) / [#61](https://github.com/ryouka0731/KeepingYouAwake/pull/61) |

Avec un suivi de la source de session pour qu'un déclencheur de fonctionnalité ne puisse jamais désactiver une session lancée par l'utilisateur (le déclencheur d'écran externe a été aligné sur ce contrat dans [#58](https://github.com/ryouka0731/KeepingYouAwake/pull/58)). Plus une chaîne d'auto-mise à jour Sparkle ([#66](https://github.com/ryouka0731/KeepingYouAwake/pull/66) — étapes manuelles restantes dans `docs/sparkle-auto-update-setup.md`).

## Installation

### Téléchargement (recommandé)

[Page Releases →](https://github.com/ryouka0731/KeepingYouAwake/releases)

Chaque release joint un `KeepingYouAwake-<tag>.dmg` et un `.dmg.sha256`. Faute d'Apple Developer ID, le bundle est signé en ad-hoc et **non notarisé**. Premier lancement :

1. Monter le dmg, glisser `KeepingYouAwake.app` dans `/Applications`.
2. **Clic droit → Ouvrir** → confirmer dans la boîte de dialogue.
3. (Ou Réglages Système → Confidentialité et sécurité → *Ouvrir quand même*.)

Ensuite, l'application se lance normalement.

### Construire depuis les sources

```bash
git clone https://github.com/ryouka0731/KeepingYouAwake.git
cd KeepingYouAwake
open KeepingYouAwake.xcworkspace
```

Ouvrir avec Xcode 16 ou supérieur (l'icône utilise le format Icon Composer introduit avec Xcode 16) et lancer. Cible : macOS 10.13+.

## Configurer les déclencheurs

Les bascules sans UI Settings se définissent via `defaults write` :

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

# Déclencheur de planification (configurer les fenêtres via PlistBuddy)
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.ScheduleEnabled -bool YES

# Activer pendant un téléchargement en cours
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.DownloadInProgressActivationEnabled -bool YES

# Masquer le compte à rebours dans la barre des menus (par défaut : affiché)
defaults write info.marcel-dierkes.KeepingYouAwake \
  info.marcel-dierkes.KeepingYouAwake.MenuBarCountdownDisabled -bool YES
```

Le schéma URL `keepingyouawake:///activate?seconds=N` / `:///deactivate` / `:///toggle` est également exposé en App Intents pour Shortcuts.app.

## Fonctionnement

L'app est un mince wrapper autour de [`caffeinate`](https://web.archive.org/web/20140604153141/https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/caffeinate.8.html), commande native de macOS. Les limitations amont s'appliquent toujours (par ex. veille à couvercle fermé imposée par macOS).

## Relation avec l'amont

Ce fork suit `newmarcel/KeepingYouAwake` et reprend les correctifs de maintenance amont. Les corrections non spécifiques au fork sont d'abord proposées à l'amont quand cela a du sens.

Le projet original `newmarcel/KeepingYouAwake` et `keepingyouawake.app` restent maintenus indépendamment par [Marcel Dierkes](https://github.com/newmarcel).

## Revue de bots / CI

- **CI** (`.github/workflows/ci.yml`) — chaque PR exécute xcodebuild build, les tests unitaires SPM et un E2E URL-scheme.
- **Release** (`.github/workflows/release.yml`) — chaque tag `v*` construit un dmg Release ad-hoc signé et l'attache à la Release GitHub correspondante.
- **CodeQL + OSSF Scorecards** — audits de sécurité sur PR et hebdomadairement.
- **Revue IA** — CodeRabbit, cubic, Gitar, Socket Security et Gemini Code Assist commentent chaque PR.
- **Dependabot** — mises à jour npm / GitHub Actions hebdomadaires, regroupées en minor/patch.

## Licence

MIT, identique à l'amont. Ressources visuelles également MIT.

Le fork conserve la mention de copyright originale de Marcel Dierkes et ajoute la sienne (voir *About* dans l'app et `Credits.rtf`). Sur la demande polie de l'amont — ne pas redistribuer un fork sous le même nom et la même icône — ce fork s'appelle **KeepingYouAwake (Amphetamine)** et arbore une icône de tasse orange.

## Anciennes versions de macOS

Comme l'amont :
- [Version 1.6.2](https://github.com/newmarcel/KeepingYouAwake/releases/tag/1.6.2) est la dernière à prendre en charge Sierra (10.12).
- [Version 1.5.2](https://github.com/newmarcel/KeepingYouAwake/releases/tag/1.5.2) est la dernière à prendre en charge Yosemite (10.10) / El Capitan (10.11).
