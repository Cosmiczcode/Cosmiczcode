# Simulator UI – Shop, Index & Daily Rewards

Code-built Roblox UI in the style of the reference screenshots: top bar, left menu, HUD,
plus working **Shop**, **Index** and **Daily Rewards** windows. It scales to fit any screen.

## Install (easiest)
1. Download `SimulatorUI.rbxmx`.
2. In Roblox Studio, right-click **Workspace** → **Insert from File…** → pick the file.
3. Move the three scripts out of the `SimulatorUI` folder:
   | Script | Move to |
   |---|---|
   | `SimUIConfig` (ModuleScript) | **ReplicatedStorage** |
   | `SimUIClient` (LocalScript) | **StarterPlayer › StarterPlayerScripts** |
   | `SimUIServer` (Script) | **ServerScriptService** |
4. Game Settings → Security → turn on **Enable Studio Access to API Services** (lets daily rewards save).
5. Press Play.

Using Rojo instead? `rojo serve` with the included `default.project.json`.

## Customize (all in `SimUIConfig`)
- **Icons** – the custom art in the screenshots is image assets from a paid pack, so emoji are used
  until you upload your own images and paste `rbxassetid://…` into `Config.Icons`.
- **Items** – your Index items (name, rarity, image). Placeholders are generated until you add some.
- **DailyRewards** – what each of the 7 days gives.
- **Shop / GamePasses / LevelProducts** – Developer Product & Game Pass IDs and displayed prices.
- **Stats** – which `leaderstats` / player attributes the money, rebirths, level and XP read from.

## Hooking into your game (server)
```lua
game.ServerStorage.SimUI_DiscoverItem:Fire(player, "Item Name")   -- unlock in Index
game.ServerStorage.SimUI_GrantReward.Event:Connect(function(player, reward)
    -- reward.Type == "Product" (reward.Key), "Levels", "Stat" or "Custom"
end)
```
Client buttons without a window (My Base, Upgrades, Pass, Rebirth) fire
`PlayerGui.SimulatorUI.ButtonClicked` with the button name.

If your game already sets `MarketplaceService.ProcessReceipt`, set `Config.HandleReceipts = false`.

Rebuild the `.rbxmx` after editing `src/`: `python3 tools/build_rbxmx.py`
