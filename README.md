# Bellship

Source for the Roblox game **Bellship**, managed with [Rojo](https://rojo.space).

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder.
2. Start the sync server: `rojo serve`
3. In Roblox Studio, connect with the Rojo plugin.

Build a place file with `rojo build -o build/Bellship.rbxl`.

## Layout

| Folder        | Roblox location                         |
| ------------- | --------------------------------------- |
| `src/server`  | `ServerScriptService.Server`            |
| `src/client`  | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/shared`  | `ReplicatedStorage.Shared`              |
