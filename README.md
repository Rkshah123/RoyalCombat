# ♟️ Royal Combat (Chess Arena)

A polished cross-platform chess game built with **Flutter** — play against a
tuned computer opponent or pass-and-play with a friend on the same device.

![Platforms](https://img.shields.io/badge/platform-Android%20%7C%20Windows-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter)
![Tests](https://img.shields.io/badge/tests-31%20passing-brightgreen)

## ✨ Features

- **Play vs Computer** — Easy / Medium / Hard. The AI is a minimax engine with
  alpha-beta pruning, quiescence search and piece-square tables, running off
  the UI thread in a background isolate.
- **Pass & Play** — two humans, one device.
- **Full rules engine** — castling, en passant, promotion, check /
  checkmate / stalemate, 50-move rule and threefold repetition.
- **Time controls** — No clock, 1/3/5/10/15 minutes, optional +5s Fischer
  increment, with live ticking clocks for both players.
- **Learn Chess** — interactive piece-by-piece lessons with playable demo
  boards (pawn, king, queen, rook, bishop, knight).
- **Match History** — every finished game is saved locally with mode,
  result, date and duration.
- **Sound design** — move, capture, check, victory/defeat stings and UI
  navigation sounds.
- **Three board themes** with light/dark palettes, an arena-style background
  artwork on all menu screens, and a clean gameplay view.
- **Quality-of-life** — undo, hint, board flip, resign, exit confirmation,
  responsive layout for phones and desktop windows.

## 📥 Downloads

Grab the latest build from [**Releases**](../../releases):

| Asset | For |
|---|---|
| `RoyalCombat-x.y.z-android.apk` | Android — sideload the APK |
| `RoyalCombat-x.y.z-windows-setup.exe` | Windows — full installer (creates Start Menu + Desktop shortcuts) |
| `RoyalCombat-x.y.z-windows-portable.zip` | Windows — extract & run, no install |

> The Windows binaries are not code-signed, so SmartScreen may show
> *"Windows protected your PC"* on first run — choose **More info → Run
> anyway**.

## 🚀 Building from source

Requirements: Flutter SDK 3.4+ (stable), Android SDK (for the APK) and
Visual Studio Build Tools with C++ workload (for Windows).

```bash
flutter pub get
flutter test                # 31 tests
flutter build apk --release          # Android
flutter build windows --release      # Windows (run inside desktop_app/)
```

The Windows desktop app lives in [`desktop_app/`](desktop_app) as a
self-contained Flutter project (same source, its own Windows runner).

## 🗂️ Project structure

```
lib/                  # shared application source
  screens/            # splash, menu, setup, game, game-over, learn, history, settings
  services/           # settings, sounds, timers, chess AI, match history
  widgets/            # board, buttons, pieces, background, demos
assets/               # audio, fonts, images (background, logo, piece themes)
android/              # Android platform shell
desktop_app/          # Windows desktop Flutter project
installer/            # Inno Setup script for the Windows installer
test/                 # unit + widget tests
```

## 📄 License

Copyright © 2026 Khan. All rights reserved.
