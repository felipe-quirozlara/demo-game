# Simple Platformer (LÖVE)

This is a minimal 2D platformer demo built with LÖVE (love2d) and Lua.

Controls
- A / Left Arrow: move left
- D / Right Arrow: move right
- Space: jump
- Esc: quit

How to run
1. Install LÖVE from https://love2d.org/ (choose the Windows build).
2. From PowerShell, run:

```powershell
# change to project directory
cd c:\code\demo-game
# run with love (assuming love is on PATH)
love .
```

Project structure
- `main.lua` - entry point
- `conf.lua` - window config
- `src/player.lua` - player logic and drawing
- `src/level.lua` - simple platform level and collision helpers

Notes
- This is intentionally small and easy to extend. Suggested next steps: add sprites, smoother acceleration, wall jumps, moving platforms, and collectibles.
 
Persistence (Rogue-lite changes)
- The game now keeps player money between runs (rogue-lite style). Money is saved to a small file using LÖVE's save system.
- Save file: `player_save.lua` in LÖVE's save directory for the game (usually in `%appdata%/LOVE/demo-game/` on Windows).
- Money is persisted immediately when the player picks up coins and also loaded when the game starts.

If you want to reset the money, delete the save file in the LÖVE save folder or implement a reset option in-game.
