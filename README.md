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
