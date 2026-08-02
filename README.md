# Adaptive Gaming Power

Automatically use a full-performance profile while plugged in and an efficient profile on battery, with per-game GPU routing and safe-windowed launch helpers.

The project is the portable version of the original GamingPowerProfiles, GameModeControl, SteamLaunchPolicy, SafeWindowedSteamLaunch, display-safety, and hidden-task work.

## Features

- Detects AC versus battery without changing display resolution.
- Uses supported `powercfg` processor and PCIe settings.
- Routes explicitly configured game executables to high-performance GPU on AC and power-saving GPU on battery.
- Discovers Steam libraries and emits an inventory; it does not guess which executable is the real game client.
- Avoids launchers, installers, crash reporters, and anti-cheat helpers by default.
- Supports safe-windowed launch arguments per configured game.
- Installs a hidden sign-in plus recurring profile task.
- Saves a targeted backup of power settings and GPU preferences.
- Includes a small Windows control panel for Auto, AC, Battery, Status, and inventory refresh.

## Start

1. Copy `config/games.example.json` to `config/games.json`.
2. Run the inventory:

```powershell
.\src\Inventory-Games.ps1
```

3. Add only real game executables to the configuration.
4. Audit:

```powershell
.\src\GamingPower.ps1 -Mode Status -ConfigPath .\config\games.json
```

5. Install from elevated PowerShell:

```powershell
.\src\GamingPower.ps1 -Mode Install -ConfigPath .\config\games.json -Apply
```

6. Open the control panel:

```powershell
.\src\Open-GameModeControl.ps1 -ConfigPath .\config\games.json
```

## Limits

Windows per-app GPU preference is advisory; vendor drivers and hybrid-graphics firmware may make the final decision. Battery CPU caps trade frame rate for runtime and heat. Anti-cheat launchers can reject forced command-line flags, so safe-windowed arguments are opt-in per game.

## License

MIT.

