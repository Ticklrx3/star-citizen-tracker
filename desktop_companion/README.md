# SC Tracker Companion

A lightweight Windows shell for the Star Citizen Tracker. It does **not** inject into Star Citizen, read game memory, automate gameplay, or modify game files. It displays the existing web tracker in a persistent desktop WebView and adds global hotkeys for an always-on-top quick-entry panel.

## Hotkeys

- **Ctrl + Shift + T** — show/hide the Quick Entry overlay.
- **Ctrl + Shift + F** — show/hide the full Tracker companion window.

Edit `companion_config.json` to change either hotkey or the window sizes.

## First run

Double-click `install_and_run.bat`. It creates a local Python environment, installs `pywebview` and `pynput`, then opens the companion.

Sign in once inside the companion. Persistent WebView storage is kept in `.companion_webview` beside the app so the Streamlit/Supabase browser session can persist between launches.

## Build an EXE

Double-click `build_windows_exe.bat`. The output will appear under `dist/` as `SC_Tracker_Companion.exe` together with the config file.

## How the two windows work

The full window loads the normal Streamlit tracker, so Dashboard, contracts, ore, commodities, mining locations, loot/shops, blueprints, Saved Records, export, profile, and the new Starmap & Route Planner all remain available.

The quick overlay loads the same site with `?companion=quick`. After authentication it presents compact Contract, Ore, and Commodity entry forms plus the active saved route and route-progress controls.

## Game-safety boundary

This companion is intentionally an external overlay/window. It does not patch `StarCitizen.exe`, inject DLLs, inspect process memory, simulate game controls, or bypass Easy Anti-Cheat. The hotkeys only show and hide the companion's own windows.
