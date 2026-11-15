# Bellship

Roblox game, Rojo project. Code lives in `src/` (server, client, shared); see README for the mapping.

- Studio stays in sync automatically: a watcher (`~/.local/studio-sync/watch.ts --only Bellship`,
  log `bellship.log`) runs `bun tools/push.ts` on every change under `src/`. No Rojo plugin needed.
- The local place file is `Bellship.rbxl` (gitignored). Build/world changes made in Studio live there,
  so save it in Studio; anything that should be in git belongs in `src/`.
- Run Luau in Studio: `STUDIO=Bellship bun tools/mcp.ts luau Edit < code.luau`
  (set `STUDIO_MCP` to the newest `%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe`).
- Strict Luau, format with StyLua, lint with selene. LF line endings.
- Creator Store furniture lives only in the place file, in `ServerStorage.Furniture` (Table = asset
  11802731038, Chair = asset 873982846; scripts stripped). `TableBuilder` clones and stretches it and
  falls back to plain parts if it is missing, e.g. in a fresh `rojo build`.
