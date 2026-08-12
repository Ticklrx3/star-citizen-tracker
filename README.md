# Star Citizen Tracker + Companion Release

This release adds two connected features to the existing tracker:

1. **Interactive Starmap & Route Planner** in the Streamlit app.
2. **Windows desktop companion** with a full tracker window and an always-on-top Quick Entry hotkey overlay.

## Web app update

Upload the included root-level `app.py` to the existing GitHub repository as the live `app.py`.

The new Starmap & Route Planner appears in the normal sidebar for both signed-in users and recruiter demo mode. It uses live UEX hierarchy data when available and automatically falls back to a packaged schematic location set if UEX cannot be reached. Clicking a plotted location appends it to the planned route. Stops can be reordered, removed, looped back to the start, downloaded as JSON, saved, and marked active for the desktop companion.

The starmap is intentionally a **schematic navigation layout**. It uses real location hierarchy and routeable-location metadata but does not claim exact in-game Cartesian coordinates.

## One Supabase migration

Run `database/schema_migration_v11_saved_routes.sql` once in the Supabase SQL Editor. It adds only the `saved_routes` table and RLS policies; it does not rebuild or erase existing tables.

Without the migration, the starmap still works during the current Streamlit session, but cross-device saved routes and the companion's active-route display will not persist.

## Windows companion

Open `desktop_companion/`.

- Run `install_and_run.bat` for the easiest first launch.
- **Ctrl + Shift + T** toggles the always-on-top Quick Entry overlay.
- **Ctrl + Shift + F** toggles the full companion window.
- The full window is the real deployed tracker, so every current tracker feature remains available in the companion.
- The quick overlay loads the compact `?companion=quick` interface with Contract, Ore, Commodity entry, and active-route progress.

To create a standalone executable on Windows, run `build_windows_exe.bat`.

## Safety boundary

The companion is an external desktop WebView. It does not modify Star Citizen files, inject into the game process, read process memory, automate controls, or bypass Easy Anti-Cheat. The global hotkeys only show and hide the companion's own windows.

For best overlay behavior, use Star Citizen in Borderless or Windowed Fullscreen mode if exclusive fullscreen prevents always-on-top windows from appearing.
