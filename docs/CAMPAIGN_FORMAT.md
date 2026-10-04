# Campaign authoring format

Eight UTF-8 JSON manifests under `data/campaign/`, each with 25 explicit missions. The loader creates ordinary `LevelData` resources and map nodes. `data/levels/*.tres` and `data/maps/*.tres` are retained legacy data and are not loaded for gameplay.

## World fields

`schema_version` (1), `id`, `name`, `order` (0–7), `previous` (empty for Lawn), `color` (hex), `rule_text`, optional `balance_revision` (e.g. `"v0.6"`), and `levels`. Every balance change after v0.6 is recorded in `docs/testing/balance_log.json`.

## Level fields

- `id`: `<world>_<01..25>`; stable save identity. `number`: within-world ordinal.
- `title`, `briefing`, `joke`: player-visible English text. Existing UI keys retain existing localization. No new translations are claimed.
- `scenario`: authoring label for documentation; runtime uses the actual rules below. Since v0.6 each world orders its scenarios differently inside same-size slot groups ({6,7,10}, {12,13,14,17}, {18,19,20,23}); levels 1–5, 8, 9, 11, 15, 16, 21, 22, 24, 25 keep fixed roles.
- `tuning` (optional, v0.6): list of one-shot tuning markers (e.g. `mowerless_sun`) so retune scripts stay idempotent. Ignored by the runtime.
- Every objective target that is a positive number **must appear verbatim in `briefing`**; titles containing numbers must match too (validator-enforced).
- `mode`: `defense`, `artillery`, or `holdout`. Holdout supplies a mature garden and free 1200-HP click repairs on a 3-second recharge.
- `field_rule`: `normal`, `tide`, `night`, `heat`, `wind`, `frost`, `conveyor`, or `low_gravity`.
- `layout`: exactly five strings of nine characters: `.` grass, `~` water, `#` unplantable. Zombies cross blocked cells normally.
- `wave_specs`: explicit ordered waves. Every wave contains `flag` and `spawns` with `id`, `row` (0–4), and `delay` (seconds from wave start).
- `zombie_pool`: preview/almanac list covering every scheduled ID, not a procedural pool for these missions.
- `fixed_seeds`: supplied locked deck; empty means normal seed selection. `banned_plants`: selection exclusions.
- `preplants`: prepared garden entries (`id`, `row`, `col`); used by holdout levels. They start mature and do not consume planting actions.
- `start_sun`, `sky_sun`, `sky_sun_value`, `sky_sun_interval`, `first_wave_delay`, `wave_interval`, `mowers`.
- `hybrid_cap`, `reward_plant`, `reward_feature`, `reward_coins`, `materials`.
- Artillery missions also specify `artillery_damage` and `artillery_cooldown`; the cannon is free and recharges indefinitely.

## Objective contracts

All objectives are mandatory in addition to clearing the final wave and protecting base integrity.

| Type | Target meaning | When evaluated |
|---|---|---|
| `collect_sun` | Cumulative sun collected in this battle; spending does not reduce it | Win gate |
| `bank_sun` | Current unspent sun | Win gate |
| `plant_limit` | Total successful seed actions; includes rafts, grafts, and evolutions | Placement rejected at cap |
| `loss_limit` | Maximum destroyed or shoveled plants; silent grafts and single-use triggers exempt | Fail immediately when exceeded |
| `graft_count` | Number of actual grafts; evolutions do not count | Win gate |
| `no_breach` | Maximum house breaches; mowers triggering alone are not a breach | Fail when exceeded |
| `time_limit` | Maximum playing time in seconds; pauses do not advance it | Fail when exceeded |

Sun missions remain active after all enemies are gone until the sun condition is fulfilled. Their sky supplies make the target achievable without mandatory workshop tools. A repair kit cannot undo a recorded breach. Restoring a raft after a top plant dies is not a player planting action.

## Pacing and difficulty

Authored spawn composition and lane assignments are deterministic. Small cosmetic spawn-position variation remains. Existing difficulty modifiers affect movement, health response, bite damage, and wave gaps. Extra count pressure is rounded into **basic shambler reinforcements only**. A crowded field delays the next wave; a cleared field shortens downtime to a breather. Elite abilities have limits or bounded periodic costs. Summoners do not spawn more summoners.

## Safe change process

1. Edit just the target world's JSON; do not alter level IDs after release.
2. Update its matching `docs/campaign/<world>.md` briefing/table if needed.
3. Run `python3 tools/tests/validate_campaign.py`.
4. Import with Godot and run `tools/tests/campaign_test.tscn`.
5. Play/bot-test the changed level on Standard and inspect Hard/Hard+ separately.
