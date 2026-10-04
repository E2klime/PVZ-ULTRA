# Crafting and grafting

## Workshop

Open **Crafting Workshop** from the world hub. Victories award compost, scrap, and milestone crystals. First clears grant the mission's full bundle; repeats grant one compost and one scrap; milestone repeats (levels 5, 10, 15, 20, 25) also grant one crystal. Recipe world locks follow campaign progression. Tools stack to nine. An invalid or unaffordable craft deducts nothing.

Eight consumables (only owned tools appear on the battle panel):
- Bottled Sunshine: +200 sun. Spendable and bankable, but **not** counted toward "collect sun" goals (v0.6).
- Sun Magnet (v0.6): collect every sun token on the field; counts as normal collection.
- Glue Trap (v0.6): halve every zombie's speed for 8 seconds.
- Compost Tea: heal all living plants by 750 HP.
- Frost Bottle: freeze enemies for five seconds (giants halve it).
- Pepper Bomb: 900 area damage around the enemy nearest the house.
- House Repair Kit: restore one base integrity, without undoing breach failures.
- Seed Clock: reset seed cooldowns.

Eight permanent seed licenses: Twin Pod, Twin Sunbud, Ironbark Wall, Rime Lettuce, Sun Sovereign, Phoenix Lily, Storm Thistle, Elder Oak. A license can make an evolution-only form selectable; hybrids remain graft-only. Ordinary campaign rewards still unlock core seed plants. A recipe can be crafted only once when it is a permanent license.

### Permanent upgrades (v0.6)

`kind: "upgrade"` recipes are tiered (`tier` field; tier N requires N−1) and stored in `save.upgrades`. Effects are small and never required by any mission; the bot and contract suite run with none installed.

| Upgrade | Tiers | Effect per tier | Hook |
|---|---|---|---|
| Sprinkler | 3 (Pool, Roof, Factory) | seed recharge −5% | `SeedState.recharge()` ← `SaveManager.recharge_mult()` |
| Seed Pouch | 2 (Night, Frost) | opening cooldowns −25% | `SeedState._init` ← `opening_cooldown_mult()` |
| Sun Lens | 2 (Desert, Moon) | sky sun +5 | `Battle` sky drop ← `sky_sun_bonus()` |

The coin shop's "start sun" purchase is a separate system and is not duplicated here. Upgrade costs are the main late-game material sink: a full campaign earns ≈900 compost / 700 scrap / 40 crystal; all 23 recipes once each cost 387 compost / 326 scrap / 47 crystal. Crystal is the deliberate bottleneck: first clears award 40, and since v0.6 replaying a milestone level (every 5th) awards 1 crystal, so the workshop is completable.

## On-board grafts

24 directional ingredient recipes under `data/fusion/*.tres`: the original six plus eighteen new results. Drop the catalyst seed on a mature compatible base, pay the catalyst cost and graft fee, and retain the base's health ratio. Each mission has a hybrid cap. Ingredient order matters. The almanac exposes every recipe and result.

The expansion includes Solar Turret, Ember Pod, Hail Volley, Bee Cannon, Solar Barricade, Frost Barrier, Pepper Hive, Storm Pod, Healing Lantern, Ice Mine, Sun Mine, Pepper Wall, Gale Pod, Ember Vine, Glacial Hive, Thorn Lantern, Ember Snapper, and Needle Storm.

New resources reuse behavior families rather than embedding special cases in `Main.gd`. Solar Turret and Solar Barricade combine their parent behavior with independent sun-production timers.
