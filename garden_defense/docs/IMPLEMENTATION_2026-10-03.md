# Implementation snapshot — 2026-10-03

## Added in this build
- Two selectable campaign maps: Lawn and Poolside.
- Pressure-based wave director with accelerating cadence, elite-budget cap, lane balancing, warning window, bounded anti-overlap delay, and compact assault scheduling.
- Three-point gate integrity. A normal escape costs one point; high-threat enemies cost two. Mowers still intercept first.
- Runtime ×1/×2 speed control and a dedicated pause button/menu.
- New illustrated menu background and lightweight animated leaf/pollen ambience.
- Save migration to remember the current node independently for each map.

## Scope note
Poolside currently uses the core five-lane grass-board rules. The archived GDD's water rows, support pads, and swimming enemy states are intentionally not claimed as complete.

## Source art workflow
The generated menu illustration is stored as `assets/art/menu_garden.jpg`. UI is code-built rather than image-generated. Character cut-out rigs, atlas slicing, and Adobe/Krita cleanup remain production-pipeline tasks described in the archived GDD.
