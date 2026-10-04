# v0.5 implementation handoff

## Delivered gameplay

The former two-world prototype now loads eight campaign manifests with 25 levels each. Level progression checks the previous mission's clear, and world progression requires all 25 clears of the previous world. Every mission has explicit wave entries, a field layout, economy/timing settings, briefing, joke, and rewards.

Battle rules moved into purpose-built modules: `ObjectiveTracker`, `FieldRules`, `MissionActions`, `CraftingSystem`, and `CampaignProgress`. `Battle` orchestrates these and retains the pre-existing board/entity/input/FX engine. `ui/main.gd` stays a 41-line router.

The workshop spends first-clear/replay materials, crafts six consumables, and permanently licenses eight seed forms. Eighteen graft resources expand the directional recipe library to 24. New zombie records use reusable behavior families; the three Gargantuans have separate variant scripts and a shared giant stage module.

Victory is gated by both wave clearance and all mandatory objectives. Objectives use local counters. Planting caps reject the next action; loss, breach, and deadline failures end the battle. Sun objectives can continue after wave clearance. Debug instant-win was disabled to avoid silently bypassing campaign conditions.

## Not included / production boundary

- No new painted artwork or bespoke world background paintings. Existing art and procedural entity fallbacks are intentional for this gameplay-focused release.
- No new translated strings beyond English. Existing translations/settings are preserved.
- No audio-production pass, mobile-device QA, storefront integration, or platform executable in this source archive.
- Not all 200 levels have been human-playtested. Hard and Hard+ still require an extended balance pass.
- A simple completion message is implemented, not an animated ending cinematic.

Historical documents and legacy `.tres` levels/maps remain for reference but are not the current campaign source of truth.
