# Changelog

All notable changes to this project will be documented in this file.

## [1.0.4] - 2026-11-24

### Changed
- Picks up game-common 1.20.0: a deferred action no longer runs once the
  game is closed or a new game has started, and the game is saved a few
  seconds after a move instead of after every one, and at once on close,
  suspend or power-off.

## [1.0.3] - 2026-11-24

### Changed
- Picks up game-common 1.19.0: with the Dashboard installed, the title bar's
  close icon becomes a house that goes back to it.

## [1.0.2] - 2026-11-24

### Changed
- Picks up game-common 1.18.0: a status line cut off with "…" opens in full
  when tapped, so a long hint can be read.

## [1.0.1] - 2026-11-18

### Changed
- Picks up game-common 1.17.0 (a board redraw fix used by chess, binairo and
  tatami; no change in this game).

## [1.0.0] - 2026-11-10

### Added
- First release: a guessing game for two players with a reader each. Both
  readers build the same gallery of drawn faces from the game code, and give
  each player a secret character. Ask yes/no questions about looks, grey out
  the faces they rule out, and make your final guess: your reader checks it.
- 16 or 24 faces, names that read the same in every language, My character
  with its looks spelled out for honest answers, auto-save.
