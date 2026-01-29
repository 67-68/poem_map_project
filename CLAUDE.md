# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Godot 4.5 game project** called "poem_map" - a visual poetry exploration game focused on Tang Dynasty poets (618-907 AD). The project uses GDScript and follows Godot's scene-based architecture.

## Development Environment

- **Engine**: Godot 4.5 with Forward Plus rendering
- **Editor**: VSCode with Godot tools extension (configured in `.vscode/settings.json`)
- **Main Scene**: `main.tscn` (UID: `cvv8lap5eqnr1`)
- **Autoloads**: Configured in `project.godot`:
  - `Global` (`core/global.gd`) - Global state and signals
  - `Logging` (`core/logger.gd`) - Logging system
  - `TimeService` (`core/time_service.tscn`) - Time management
  - `DataService_` (`core/data_service.gd`) - Central data service

## Key Architectural Patterns

### Data Layer Architecture
- **Base Model Pattern**: `GameEntity` → `WorldEvent` → `PoetData`/`PoemData`/`PoetLifePoint`
- **Repository Pattern**: `BaseRepository` → `PoemRepository`/`PoetRepository`/`PathPointRepository`
- **Service Layer**: `DataService` manages all repositories and data loading
- **Data Loading**: `DataLoader` handles JSON parsing with `GameEntity` instantiation

### Global State Management
- `Global.gd` contains game constants (start_year=618, end_year=907), current state (year, mood, selected poet), color definitions, and signal system
- Signals are used for cross-component communication (e.g., `year_changed`, `poet_selected`)

### Time System
- `TimeService` manages game time progression with play/pause/jump functionality
- Time changes emit global signals that other systems subscribe to

### Data Model Hierarchy
```
GameEntity (base class)
├── uuid, name, description, icon, owner_uuids, tags
│
└── WorldEvent (extends GameEntity)
    ├── position, year, location_uuid
    │
    ├── PoetData (extends WorldEvent)
    │   ├── color, birth_year, death_year, path_point_keys
    │   └── Represents Tang Dynasty poets
    │
    ├── PoemData (extends WorldEvent)
    │   ├── popularity, background, emotion
    │   └── Represents individual poems
    │
    └── PoetLifePoint (extends WorldEvent)
        └── Represents life events/path points for poets
```

## Key Systems

1. **Map System** (`world/map.gd`): Displays poet character points on a Tang Dynasty map
2. **Path System**: Creates emotional paths between life points using path finding algorithm
3. **Time Slider**: Allows navigation through historical timeline (618-907 AD)
4. **Emotion Visualization**: Color gradients represent poet emotions (sad/happy)
5. **Weather/Effects**: Rain, daylight, background color changes
6. **Poem Animation** (`features/poem_animation.gd`): Animated poem display system
7. **Character Points** (`world/character_point.gd`): Interactive poet points with click/tween animations

## Data Files

- **Poet Data**: `assets/data/poet_data.json` - Tang Dynasty poet information
- **Poem Data**: `assets/data/poem_data.json` - Poem information and metadata
- **Path Points**: `assets/data/path_points.json` - Life event locations and connections
- **Profile Images**: `assets/profile/{poet_id}.png` - Poet profile images (referenced in popup.md)

## Development Commands

Since this is a Godot project:
- Open `project.godot` in Godot Editor to run/debug
- Main entry point is `main.tscn`
- Export builds through Godot's standard export workflows
- No package managers or build scripts required

## Code Style & Conventions

- GDScript with type hints where appropriate
- Chinese comments mixed with English (common in data-related code)
- Signal-based event system for component communication
- Repository pattern for data access (see `core/base_repository.gd`)
- Utility classes as `RefCounted` extensions (`core/util.gd`)
- Autoload singletons for global services

## Important File Paths

- **Entry Point**: `main.tscn`
- **Global State**: `core/global.gd`
- **Data Service**: `core/data_service.gd`
- **Main Map Controller**: `world/map.gd`
- **Data Models**: `characters/` directory
- **Core Systems**: `core/` directory
- **UI Components**: `ui/` directory
- **World Components**: `world/` directory

## Version History

See `change_log.md` for feature additions per version. Key milestones:
- v0.4.0: Time service, path finding algorithm, time on lifePathPoint data structure
- v0.3.0: Daylight, rain, in-game controller, camera movement
- v0.2.0: Data classes changed to Godot resources, emotion visualization improvements
- v0.1.0: Initial data parsing, character points, time slider, trail system