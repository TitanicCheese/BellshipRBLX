# Bellship

Roblox game, Rojo project. Code lives in `src/` (server, client, shared); see README for the mapping.

- Studio stays in sync automatically: a watcher (`~/.local/studio-sync/watch.ts --only Bellship`,
  log `bellship.log`) runs `bun tools/push.ts` on every change under `src/`. No Rojo plugin needed.
- The local place file is `Bellship.rbxl` (gitignored). Build/world changes made in Studio live there,
  so save it in Studio; anything that should be in git belongs in `src/`.
- Run Luau in Studio: `STUDIO=Bellship bun tools/mcp.ts luau Edit < code.luau`
  (set `STUDIO_MCP` to the newest `%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe`).
- Strict Luau, format with StyLua, lint with selene. LF line endings.
- Everything is built from parts in code except the chair: the user picked a Creator Store chair,
  stored only in the place file as `ServerStorage.Furniture.Chair` (turned to face -Z, pivot at the
  bottom centre, `SeatHeight`/`SeatSize`/`SeatOffset` attributes). `TableBuilder` clones it with an
  invisible Seat, and falls back to `builtChair` in a fresh `rojo build`.
