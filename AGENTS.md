# AGENTS.md — poem_map (大唐诗词可视化)

## Environment

- **Godot 4.x** (4.6.3) at `/usr/local/bin/godot` — GDScript only, no C#/C++
- **Python**: `.venv/bin/python` (never `python3`)
- **LSP**: Godot LSP on port 6005 is the absolute source of truth for syntax/type/reference errors. Do NOT verify syntax with shell commands. If LSP shows no errors, the code is correct.
- **Web testing**: use Chrome (Vivaldi kills threads silently). After edits to `.tscn`, reload the editor project + `Shift+Cmd+R` in browser.

## Key Commands

```bash
# Single test
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gselect=<test_file>.gd

# All tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests

# Toggle Logging autoload (web export needs it, CLI scripts must NOT have it)
.venv/bin/python tools/toggle_export_fix.py add      # enable Logging autoload
.venv/bin/python tools/toggle_export_fix.py remove   # disable Logging autoload
.venv/bin/python tools/toggle_export_fix.py status

# Rebuild file indices (needed after adding/removing assets)
.venv/bin/python tools/build_data_index.py    # → data/_file_index.json
.venv/bin/python tools/build_sound_index.py   # → assets/sounds/_file_index.json

# Inject preloads for HTML5 export (after code changes)
.venv/bin/python tools/inject_preloads.py
```

## Architecture

### Autoload Order (25 singletons, order matters!)
```
GameConfig → Logging → GameSave → ENUMS → EventBus → GameState → TimeService →
Database → SizeService → NavigationService → TextPoolManager → AudioManager →
PlayerState → ConsequenceExecuter → EventManager → ActionManager → ImageManager →
RuntimeProbe → HoverPopupManager → BlurManager → AncientOptionBtnManager →
MonthEndSettlement → StyleManager → AnimationController → PlotController
```

### Entrypoints
- **Game**: `main.tscn` (`uid://cvv8lap5eqnr1`) → `main.gd` (pure map mode)
- **Debug CLI**: `Cmd+F2` opens `controller.gd` (send signals, give traits, push events, execute DSL)
- **CSV sync CLI**: `godot -s res://core/csv_cloud_sync_cli.gd`
- **Event generation**: `.venv/bin/python tools/generate_orthogonal_events.py`

### DSL Syntax (CRITICAL — wrong separators break everything)
```
|  = layer 1 separator (expression level)
;  = layer 2 separator (parameter level)
/  = layer 3 separator (array element level)

Example: prop_add(name=money; val=100) | trait_add(name=reputation_rising)
```
- `prop_add` only with positive values, `prop_sub` only with negative values
- Prefer named_amounts archetypes over raw numbers: `tools/data/named_amounts.json`

### Data Pipeline
```
Google Sheets → csv_cloud_loader.gd → local CSV → DSLParser → .tres → runtime
```
**NEVER edit `.tres` files that are generated from CSV** — they will be overwritten on next sync. Always edit the source CSV.

### Core Loop
```
Action → inject temp tags → event scan (weighted by tag match count) → filter by requirements → show event → player choice → execute consequences → time advance (旬-based)
```

### Three-Layer Iron Curtain Contract (event lifecycle)
| Layer | Timing | Role |
|-------|--------|------|
| `on_enter` | Before display | Stage setting only (init flags, inject context) |
| Option `requirements` | Button creation | Read-only guard, no side effects |
| `choice_result` | After choice | Execute consequences |

### Tag System
4-part tags: `domain:category:type:specific` — e.g. `actor:status:temporary:drunk`
Old 3-part tags are normalized via `TagManager.normalize_3part_depreciated_tag()`.

### URN System
All resources identified as `urn:poem_map:<resource-type>:<resource-id>` (30+ types).

## Gotchas

- **Circular import**: If code seems correct but fails silently, suspect a cyclic dependency between autoload singletons.
- **Web export autoload quirk**: `Logging` must be an autoload for web export (`class_name` registration), but must NOT be an autoload for headless CLI scripts. Use `toggle_export_fix.py` to swap.
- **File indices**: HTML5 lacks `DirAccess` — data/sound loading falls back to `_file_index.json`. Run the build scripts after any asset changes.
- **MCP runtime probe**: `get_live_logs` may capture the initial menu screen instead of the game — verify the game is actually running.
- **UI input**: User is on a Mac trackpad. If UI issues arise, consider trackpad-specific behavior.
- **.tscn reload**: Modifying `.tscn` files requires reloading the Godot project (not just re-saving the script).
- **CSV separators**: Some legacy docs mention commas as item separators — they are wrong. Always use `|` / `;` / `/`.

## Conventions

See `CONVENTIONS.md` for workflow conventions (debug protocol, feature doc requirements, 20/80 principle, etc.).
Feature-specific docs live in `DOCUMENTATIONS/feature_intents/`.
