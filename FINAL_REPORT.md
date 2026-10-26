# Royal Combat (Chess Arena) — Final Report

Date: 26 Oct 2026 · Flutter 3.41.2 stable · Platforms: Android + Windows

## Round 4 (26 Oct 2026) — background artwork, bigger home buttons

**Application icon (desktop):** `logo.png` (project root, 1024×1024 crest) was
converted into a proper multi-size `app_icon.ico` (16–256 px) and is now the
embedded icon of `RoyalCombat.exe` — so the EXE file, the window title bar,
the taskbar, the Desktop/Start-Menu shortcuts and the installer
(`RoyalCombat_Setup.exe`) all display the Royal Combat crest. Mobile launcher
icons were already correct and were not touched.

**`background.png` everywhere (non-game panels):** the supplied
`background.png` (project root, 1672×941) was added to the bundled assets and
is now the full-screen background of every non-game screen — splash, home
menu, Play-vs-Computer / Pass-&-Play setup, Learn, lesson detail, Match
History and Settings. It is rendered with `BoxFit.cover` + centered
alignment (aspect ratio preserved, symmetric cropping, no stretching, no
separate card) via the new shared `lib/widgets/app_background.dart`
(`AppBackground`).

**Hidden during gameplay:** the chess arena deliberately does not use
`AppBackground` — when a match starts, the artwork is completely absent
behind the board/pieces/clocks (verified: clean gradient arena). Exiting the
match (or finishing it and returning to any panel) re-shows the artwork
automatically, because every route paints its own background — route state
drives it, nothing extra to remember.

**Contrast & readability over the artwork:** `AppBackground` overlays a
translucent theme-tinted scrim (palette top/bottom colors at ~62–80%) so
text, icons, headings and panels stay sharp in all three board themes while
the image remains clearly visible. Menu buttons' translucent panel fill was
strengthened slightly (0.92/0.74) for reliable contrast on the busy image.

**Bigger home page buttons:** all five menu buttons are now uniform-width
(clamped 280–400px to fit any phone), 64px tall with 19px labels and larger
icons, evenly spaced (9px gaps) inside a wider 520px column — verified
aligned and polished on desktop and phone. Other screens' buttons are
unchanged (`RoyalButton` gained an optional `height` parameter, default
unchanged).

**Home footer:** the bottom text now reads "Developed by Khan" (same font
and size the version line used).

**Arena cleanup:** the rank numbers (1–8) and file letters (a–h) on the
board edge were removed — the arena now shows only the board and the
players. Implemented by turning off the board widget's optional coordinate
overlay (still available via `showCoordinates: true` if ever wanted).

## Round 3 (26 Oct 2026) — navigation sounds, interactive piece lessons, headings

**Back buttons now click:** all five sub-screens (Learn, Learn detail,
Settings, Match History, Play-vs-Computer / Pass-&-Play setup) play
`ui_tap.wav` on the ← button — the same sound as every other navigation
control. Previously the arrow buttons were silent.

**Settings → Match Defaults clicks:** selecting Easy / Medium / Hard and
choosing any time-control chip (No clock … 15 min) now plays the standard UI
click. Both selections verified registering on-device with no errors.

**Board theme sound fixed:** choosing a board theme used to fire the
"popwindow" effect; it now plays only the standard UI click — nothing else,
no overlaps (verified: theme switch produced no error or stray sound
triggers in logs, and the theme applies instantly in all three variants).

**New: "Learn How Pieces Move" interactive lessons** (`Learn` screen, above
the lesson library) — six themed demo panels (Pawn, King, Queen, Rook,
Bishop, Knight), each with a live mini board in the active theme:
- Every legal destination is marked (dot = move, ring = capture) and accent
  arrows trace the movement paths (rook/queen/bishop rays run to their true
  board edges; the knight shows all 8 L-targets jumping over blockers).
- Accurate rules: pawn = one forward, two on its first move, diagonal
  captures only, never backwards; king = one square any direction; queen =
  straight lines any distance incl. diagonals; rook = ranks/files only;
  bishop = diagonals only; knight = L-shape, the only leaper.
- Fully interactive: tapping a marked square glides the piece there with the
  same smooth animation as the real board (280ms easeOutCubic), plays the
  matching move/capture sound, removes captured dummies, and recomputes the
  markers; a reset chip restores the start position (with a click).
- Implemented in `lib/widgets/piece_movement_demo.dart` (movement engine +
  `_PathArrowPainter`), consistent with all 3 board themes and both layouts.

**Headings only (readability):** top panel headings were enlarged/strengthened
without touching any body text or layout: Learn/Settings/Match History
titles → 28px Algerian, letter-spacing 1.8 + soft accent glow; setup titles →
30px, spacing 2 + glow; lesson detail titles → 23px + glow; small section
labels ("BOARD THEME", "LESSON LIBRARY", …) → 13.5px extra-bold,
letter-spacing 2.2, accent-tinted. Verified in both theme families on phone
and desktop.

**Bonus bug found & fixed during verification — piece art rendering:** nine
wood-theme piece SVGs (all pawns, queens, kings, bishops — both colors)
declared their fills via CSS `<style>` classes, which `flutter_svg` cannot
parse ("unhandled element" warning); every class-filled path silently fell
back to black — e.g. white pawns rendered with black bodies on the game
board and the demo boards. All affected SVGs were converted to inline
`fill` attributes (same colors), plus a regression test asserting no piece
SVG uses `<style>`. Pieces now render in their intended colors everywhere
(game board, demos, theme previews, captured trays).

## Round 2 (26 Oct 2026) — sound overhaul, timer fix, readability, desktop board

**Sounds (all existing bundled assets reused — no invented files):**
- `ui_tap.wav` is now the single universal control sound: every button, chip,
  switch, dialog action, promotion pick and game-screen control icon answers
  with it (control icons previously had no sound at all). Fire-and-forget
  playback — never blocks or delays gameplay/timers.
- Piece movement: plain moves play `move.wav` (was already wired, verified no
  UI-tap overlaps); captures play `capture.wav`; checks play `check.wav`.
- **Elimination:** when a decisive move kills a player (checkmate — and
  resignation), a distinct deep elimination sting plays. No dedicated
  elimination recording exists in the assets, so the existing `capture.wav` is
  reused at playback rate 0.8 (deeper tone) and full volume — distinct from the
  ordinary capture sound. The old tap-like check tone at mate was removed.
- **Game start:** `starting.wav` now plays exactly when a match starts
  (`GameScreen.initState`). It previously played every time the main menu
  opened and on the game-over Rematch button — both removed. The match-start
  choreography ("both players move closer to each other") was added and
  preserved: top/bottom player panels slide toward the board while the sting
  plays, with a subtle board scale-in.
- **Win/lose:** `victory.wav` (you win) and `defeat.wav` (you lose) are now
  played once by the game-over screen (500ms in, after the elimination sting
  finishes) — impossible to double-fire; draws play a soft `popwindow`
  instead of the old UI tap.
- Overlap protection: `SoundManager` now debounces identical effects (60–600ms
  per effect) so no duplicated triggers can stack.

**Timer fix (real-time, accurate):**
- Root cause: nothing listened to `TimerManager`'s notifications — clocks only
  repainted when something else (a move, a tap) rebuilt the screen, so they
  froze while you thought and then jumped.
- Every clock now repaints on every 100ms tick via a scoped `AnimatedBuilder`
  (only the clock subtree rebuilds — the board/animations are untouched).
- Tick accounting now charges actual elapsed wall-clock time instead of a
  fixed 100ms per callback, so GC/isolate hiccups can't make the clock drift.
- Verified on device: after the AI moved (its clock stopped at 04:59), the
  human clock counted down continuously with no interaction: 02:29 → 02:25
  across untouched captures; also 5:00 → 02:58 over an untouched idle period.

**AI thinking pace:** the computer now ponders for a deliberate, human-feeling
beat of up to half a second (search result held until a 450ms think window
elapses; slower searches are never padded). On-device, the AI's reply Nc6
landed within ~0.5s and its clock consumed only ~1s per move.

**Readability:** button labels and small decorative caps text no longer use the
blocky GoudyStout font — labels are bold platform-default (big Algerian titles
kept for brand). Verified on phone and desktop screenshots.

**Desktop board size:** the wide layout previously rendered the two player
panels twice (left column AND side panel). The left-column duplicates were
removed (all info still lives in the side panel), so the board now fills
almost the entire left panel — ~15% larger and centered, square aspect and
all pieces preserved, right-side panel layout untouched.

## Summary

The app was rebuilt from scratch (original Dart sources were unrecoverable from
this machine), then hard-tested on the connected Android phone
(`KVCYGYUGGIAAGYTS`) and on Windows. Both platforms are verified working with
real, interactive sessions — not just successful builds.

## Deliverables (exact paths)

| Artifact | Path | Size |
|---|---|---|
| Android APK (release, installed on phone) | `C:\Users\ShahrukhKhan\Desktop\chess_arena\build\app\outputs\flutter-apk\app-release.apk` | 67.4 MB |
| Windows EXE | `C:\Users\ShahrukhKhan\Desktop\chess_arena\desktop_app\build\windows\x64\runner\Release\RoyalCombat.exe` | (launch with the folder) |
| Windows portable ZIP | `C:\Users\ShahrukhKhan\Desktop\chess_arena\RoyalCombat_Windows_Portable.zip` | 30.2 MB |
| Windows installer | `C:\Users\ShahrukhKhan\Desktop\chess_arena\installer\RoyalCombat_Setup.exe` | 28.9 MB |

## Changes & features

**Rebuilt app (mirrors the original architecture)** — `main.dart`, `models/`
(game_state, move, player), `screens/` (splash, main_menu, setup, game,
game_over, learn, learn_detail, match_history, settings), `services/`
(settings_manager, sound_manager, timer_manager + chess_ai,
match_history_service), `widgets/` (button, chess_board, piece, timer).

- **Game modes:** Play vs Computer (Easy / Medium / Hard) and Pass & Play.
  AI = minimax with alpha-beta pruning, quiescence search and piece-square
  tables, computed off the UI thread in a `compute()` isolate.
- **Rules:** full legal-move engine via `chess` 0.7.0 — castling, en passant,
  promotion, check/checkmate/stalemate, 50-move rule, threefold repetition.
- **Time controls:** No clock, 1/3/5/10/15 min, optional +5s Fischer increment.
- **3 board themes** (Wood, Green/Black "Midnight Ice" palette variants) — every
  fix and feature applies to all themes.
- **Match History** persisted locally; **Learn Chess** lessons; sound effects;
  move history panel; undo, hint, flip, resign, exit-with-confirm.
- **"Developed by Khan" panel** added to Settings: themed card with logo ring,
  signature typography, consistent across all three themes (verified on-device).
- **Branding:** launcher icons generated (adaptive + monochrome);
  Android label fixed from "Royal Gambit" to "Royal Combat"; window title and
  EXE renamed to `RoyalCombat.exe`.

## Bugs found & fixed (all regression-tested)

1. **Crash on first legal-move marker** — `legalTargetsFrom` null check.
2. **En-passant capture on wrong file** — victim square used `fromSquare[0]`
   instead of `toSquare[0]`; fixed in both `playMove` and `_synchronizePieces`.
3. **Test expectation** — check square must be the king's square (`e1`).
4. **Settings persistence race** — setters didn't await the save; now async.
5. **Battery/hang: pulse animation** ran forever even idle — now created in
   `initState` and only repeats while check/hint highlight is active.
6. **Device startup hang with legacy prefs** — old installs stored `board_theme`
   as `int`, crashing `getString` before `runApp()` (app stuck on splash).
   Fixed with tolerant typed reads that also heal legacy data.
7. **Piece SVG asset-key mismatch** (`whitek.svg` vs `whiteking.svg`) — name
   mapping added for pieces and captured-piece icons.
8. **RoyalButton label truncation** — FittedBox scale-down.
9. **Setup screen invisible "+0s" chip** (text color == background) — dark text.
10. **Settings difficulty wrap ("Mediu m")** — FittedBox label.
11. **Difficulty chip overlapped by clock** in game screen — relocated.
12. **Board frame stretched non-square** — wrapped in `Center(AspectRatio)`.
13. **Frozen clock display** (round 2) — nothing subscribed to `TimerManager`;
    clocks froze while the player was thinking and jumped on the next
    interaction. Fixed with per-tick `AnimatedBuilder` rebuilds + wall-clock
    tick accounting.

## Test results

- `flutter analyze lib test` → **No issues found**
- `flutter test` → **All tests passed (31 tests, 4 files)** — chess rules,
  AI legality/mate-finding, settings persistence + legacy-data tolerance,
  match history, board widget rendering/taps/highlights, button behavior,
  the three new piece-demo tests (pawn forward/capture markers, capture
  removes enemy + relocation, knight jumps keep all 8 L-targets despite
  blockers) and the SVG `<style>` regression test.
- **On-device (Android)**: install OK; all six piece demos verified visually
  (pawn/king/queen/rook/bishop/knight boards with arrows, dots, rings);
  knight capture on f6 + reset chip verified interactively; Settings
  difficulty (Easy→Hard→Medium) and time-control selections registered with
  zero `E flutter` logcat entries; headings verified in both themes.
- **On Windows**: `RoyalCombat.exe` launches; Learn screen (demos with fixed
  piece colors), back-button navigation and the Settings screen verified by
  window captures; portable ZIP refreshed from this build.
- **Round 4 verification**: desktop window captures of menu (background +
  bigger uniform buttons + "Developed by Khan" footer), setup and Settings
  with the artwork; a real match started (arena clean, no coordinates, no
  background) and exited (artwork restored automatically); phone menu and
  setup verified on the updated APK.

## Limitations

- **Windows installer (added 26 Oct 2026):** a real setup wizard was built with
  Inno Setup 6.7.3 (`installer\RoyalCombat.iss` → `installer\RoyalCombat_Setup.exe`).
  It installs to `%ProgramFiles%\RoyalCombat`, creates Desktop + Start Menu
  shortcuts with the game icon, and ships an uninstaller (Add/Remove Programs).
  Rebuild it after any future Windows build with:
  `& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" installer\RoyalCombat.iss`.
  The installer is unsigned, so first run may show the SmartScreen prompt
  ("More info → Run anyway").
- **Windows build quirk:** the `desktop_app\build` folder must be deleted if
  CMake cache contains stale machine paths, and `build\native_assets\windows`
  must exist before `flutter build windows` (created automatically in this
  session's final build).
- AI plays at club-level strength; no online multiplayer (was not in scope).

## Notes

- Package id on Android remains `com.example.chess_arena`; legacy preferences
  on the phone were auto-healed on first launch of the new build.
- No git repository — all changes are plain files on disk.
