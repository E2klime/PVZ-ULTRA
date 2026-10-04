"""Generates v0.7 plant/recipe resources + translation rows. Idempotent."""
import csv, os
S = {
 "shooter": "res://entities/plants/plant_shooter.gd", "wall": "res://entities/plants/plant_wall.gd",
 "carpet": "res://entities/plants/plant_carpet.gd", "breath": "res://entities/plants/plant_breath.gd",
 "chrono": "res://entities/plants/plant_chrono.gd", "aura": "res://entities/plants/plant_aura.gd",
 "producer": "res://entities/plants/plant_producer.gd",
}
def col(c): return "Color(%g, %g, %g, 1)" % c
G = '[&"grass"]'; GW = '[&"grass", &"water"]'
P = [
 # id, script, fields, name, desc
 ("pumpkin_shell", "wall", dict(cost=125, recharge=20.0, start_cooldown=10.0, max_hp=4000, role='&"wall"', layer='&"shell"', badge='"Shell"', color_main=(0.95,0.55,0.12), color_accent=(0.55,0.75,0.2)),
  "Pumpkin Shell", "Worn over another plant. Zombies must chew through the shell first. Plant it on empty ground or over any plant."),
 ("thorn_carpet", "carpet", dict(cost=100, recharge=7.5, max_hp=300, role='&"trap"', layer='&"under"', badge='"Under · Hits boxes"', damage=20, attack_interval=1.0, color_main=(0.45,0.4,0.3), color_accent=(0.75,0.75,0.65)),
  "Thorn Carpet", "Spiky mat planted under other plants. Pierces every ground zombie walking over it, even boxed ones. Can't be eaten."),
 ("pea_bedding", "shooter", dict(cost=75, recharge=7.5, max_hp=300, role='&"shooter"', layer='&"under"', attack_kind='&"low"', badge='"Under · Low shots"', damage=15, attack_interval=1.6, projectile_speed=520.0, color_main=(0.4,0.72,0.28), color_accent=(0.3,0.5,0.2)),
  "Pea Bedding", "A carpet of tiny pods planted under another plant. Fires low shots that hit Cardboard Box zombies. Only eaten when nothing stands on it."),
 ("garlic_drone", "shooter", dict(cost=125, recharge=10.0, max_hp=300, role='&"shooter"', layer='&"air"', allowed_surfaces=GW, attack_kind='&"air"', badge='"Flying · Garlic"', tags='[&"garlic"]', damage=14, attack_interval=1.8, projectile_speed=520.0, color_main=(0.95,0.93,0.82), color_accent=(0.6,0.55,0.75)),
  "Garlic Drone", "Flying garlic bulb. Its cloves hit any zombie and make it gag and switch lanes. Ground zombies can't reach it - only balloons and slingshots."),
 ("turbo_bean", "aura", dict(cost=150, recharge=20.0, max_hp=300, role='&"support"', layer='&"air"', allowed_surfaces=GW, badge='"Flying · Speed aura"', speed_aura=1.5, aura_radius=1, color_main=(0.95,0.75,0.15), color_accent=(0.85,0.3,0.1)),
  "Turbo Bean", "Flying bean with a jet sprout. Plants in the 3x3 area around it attack and produce 50% faster."),
 ("cloud_bloom", "producer", dict(cost=75, recharge=10.0, max_hp=300, role='&"producer"', layer='&"air"', allowed_surfaces=GW, badge='"Flying · Sun"', sun_amount=25, sun_interval=24.0, color_main=(0.92,0.95,1.0), color_accent=(1.0,0.85,0.3)),
  "Cloud Bloom", "A flower riding a little cloud. Makes sun from above, safe from ground zombies, and fits over any plant."),
 ("clod_catapult", "shooter", dict(cost=125, recharge=7.5, max_hp=300, role='&"shooter"', attack_kind='&"lob"', badge='"Lob · Splash"', damage=35, attack_interval=2.6, aoe_radius=0.6, projectile_speed=520.0, color_main=(0.55,0.75,0.3), color_accent=(0.55,0.38,0.22)),
  "Clod Catapult", "Lobs dirt clods over shields and screens. Hits Cardboard Box zombies and splashes nearby zombies."),
 ("spine_cactus", "shooter", dict(cost=125, recharge=7.5, max_hp=300, role='&"shooter"', attack_kind='&"anti_air"', badge='"Anti-air · Pierce"', damage=22, attack_interval=1.5, pierce=1, projectile_speed=720.0, color_main=(0.35,0.7,0.35), color_accent=(0.95,0.5,0.7)),
  "Spine Cactus", "Shoots piercing spines that also pop balloons and hit high-flying zombies."),
 # legendaries
 ("aegis_pumpkin", "wall", dict(cost=250, recharge=40.0, start_cooldown=20.0, max_hp=8000, role='&"wall"', layer='&"shell"', rarity='&"legendary"', max_on_board=2, badge='"Legendary shell"', thorns_damage=30, regen_per_sec=40.0, fusion_ready_time=99.0, color_main=(1.0,0.78,0.25), color_accent=(0.45,0.6,0.95)),
  "Aegis Pumpkin", "Legendary golden shell. Regenerates when left alone and reflects bites back at zombies."),
 ("thunder_root", "carpet", dict(cost=275, recharge=40.0, start_cooldown=20.0, max_hp=600, role='&"trap"', layer='&"under"', rarity='&"legendary"', max_on_board=1, badge='"Legendary · Under"', damage=55, attack_interval=3.0, chain_count=5, stun_time=0.6, fusion_ready_time=99.0, color_main=(0.55,0.4,0.85), color_accent=(0.95,0.95,0.4)),
  "Thunder Root", "Legendary root planted under another plant. Bolts race along the lane, striking and stunning up to 6 ground zombies."),
 ("sky_dragon", "breath", dict(cost=325, recharge=45.0, start_cooldown=25.0, max_hp=900, role='&"shooter"', layer='&"air"', allowed_surfaces=GW, rarity='&"legendary"', max_on_board=1, badge='"Legendary · Flying"', tags='[&"fire"]', damage=60, attack_interval=3.2, attack_range=4.0, burn_dps=15.0, burn_time=3.0, fusion_ready_time=99.0, color_main=(0.95,0.3,0.45), color_accent=(0.4,0.8,0.3)),
  "Sky Dragon Fruit", "Legendary flying dragon fruit. Breathes fire 4 tiles down its lane, burning everything - balloons included."),
 ("chrono_clover", "chrono", dict(cost=300, recharge=45.0, start_cooldown=25.0, max_hp=500, role='&"support"', rarity='&"legendary"', max_on_board=1, badge='"Legendary · Time"', attack_interval=14.0, slow_factor=0.5, slow_duration=4.0, stun_time=2.0, fusion_ready_time=99.0, color_main=(0.35,0.85,0.55), color_accent=(0.95,0.85,0.35)),
  "Chrono Clover", "Legendary four-leaf clock. Every 14s it slows every zombie on the lawn and shaves 2s off all seed recharges."),
 ("bean_patriarch", "aura", dict(cost=275, recharge=45.0, start_cooldown=20.0, max_hp=1200, role='&"support"', rarity='&"legendary"', max_on_board=1, badge='"Legendary · Row & column"', speed_aura=1.35, aura_radius=9, sun_amount=25, sun_interval=18.0, fusion_ready_time=99.0, color_main=(0.75,0.55,0.25), color_accent=(0.95,0.85,0.4)),
  "Bean Patriarch", "Legendary elder bean. Speeds up every plant in its row and column by 35% and drops sun."),
 ("starfall_melon", "shooter", dict(cost=350, recharge=45.0, start_cooldown=25.0, max_hp=600, role='&"shooter"', attack_kind='&"lob"', rarity='&"legendary"', max_on_board=1, badge='"Legendary · Lob"', damage=110, attack_interval=3.4, aoe_radius=1.2, slow_factor=0.6, slow_duration=2.0, projectile_speed=480.0, fusion_ready_time=99.0, color_main=(0.35,0.3,0.75), color_accent=(1.0,0.85,0.35)),
  "Starfall Melon", "Legendary catapult that lobs a starry melon. Huge splash, slows survivors and crushes boxes."),
 # hybrids
 ("thorn_pumpkin", "wall", dict(cost=200, max_hp=5000, role='&"wall"', layer='&"shell"', is_seed='false', is_hybrid='true', badge='"Hybrid shell"', thorns_damage=20, color_main=(0.8,0.45,0.12), color_accent=(0.45,0.3,0.2)),
  "Thorn Pumpkin", "Hybrid shell bristling with thorns: every bite hurts the biter."),
 ("chili_drone", "shooter", dict(cost=225, max_hp=300, role='&"shooter"', layer='&"air"', allowed_surfaces=GW, attack_kind='&"air"', is_seed='false', is_hybrid='true', badge='"Hybrid · Flying · Fire"', tags='[&"garlic", &"fire"]', damage=22, attack_interval=1.6, burn_dps=8.0, burn_time=3.0, color_main=(0.92,0.3,0.15), color_accent=(0.95,0.93,0.82)),
  "Chili Drone", "Hybrid flying drone. Fire cloves burn, make zombies gag and switch lanes."),
 ("lava_catapult", "shooter", dict(cost=225, max_hp=300, role='&"shooter"', attack_kind='&"lob"', is_seed='false', is_hybrid='true', badge='"Hybrid · Lob · Fire"', tags='[&"fire"]', damage=50, attack_interval=2.6, aoe_radius=0.8, burn_dps=10.0, burn_time=3.0, projectile_speed=520.0, color_main=(0.85,0.35,0.15), color_accent=(0.4,0.3,0.25)),
  "Lava Catapult", "Hybrid catapult lobbing molten clods: splash plus burning."),
 ("frost_bedding", "shooter", dict(cost=150, max_hp=300, role='&"shooter"', layer='&"under"', attack_kind='&"low"', is_seed='false', is_hybrid='true', badge='"Hybrid · Under · Slow"', tags='[&"ice"]', damage=18, attack_interval=1.5, slow_factor=0.55, slow_duration=2.5, projectile_speed=520.0, color_main=(0.5,0.8,0.95), color_accent=(0.3,0.5,0.7)),
  "Frost Bedding", "Hybrid under-plant. Low icy shots slow boxed and ground zombies."),
]
R = [("pumpkin_shell","bramble_vine","thorn_pumpkin",50), ("garlic_drone","pepper_stinger","chili_drone",50),
     ("clod_catapult","ember_berry","lava_catapult",25), ("pea_bedding","frost_mint","frost_bedding",25)]
for pid, sc, f, name, desc in P:
    lines = ['[gd_resource type="Resource" script_class="PlantData" format=3]', '',
             '[ext_resource type="Script" path="%s" id="1_b"]' % S[sc],
             '[ext_resource type="Script" path="res://core/data/plant_data.gd" id="2_d"]', '', '[resource]',
             'script = ExtResource("2_d")', 'id = &"%s"' % pid,
             'name_key = "PLANT_%s_NAME"' % pid.upper(), 'desc_key = "PLANT_%s_DESC"' % pid.upper(),
             'behavior = ExtResource("1_b")']
    for k, v in f.items():
        if k in ("allowed_surfaces",): v = "Array[StringName](%s)" % v
        elif k == "tags": v = "Array[StringName](%s)" % v
        elif isinstance(v, tuple): v = col(v)
        elif isinstance(v, float): v = repr(v)
        lines.append("%s = %s" % (k, v))
    open("data/plants/%s.tres" % pid, "w").write("\n".join(lines) + "\n")
for b, c, r, fee in R:
    open("data/fusion/%s.tres" % r, "w").write('[gd_resource type="Resource" script_class="FusionRecipe" format=3]\n\n[ext_resource type="Script" path="res://core/data/fusion_recipe.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\nbase_id = &"%s"\ncatalyst_id = &"%s"\nresult_id = &"%s"\nfee = %d\n' % (b, c, r, fee))
# translations
rows = list(csv.reader(open("localization/translations.csv", encoding="utf-8")))
keys = {r[0]: i for i, r in enumerate(rows)}
def put(k, en):
    if k in keys: rows[keys[k]][1] = en
    else:
        keys[k] = len(rows); rows.append([k, en, "", "", "", ""])
for pid, sc, f, name, desc in P:
    put("PLANT_%s_NAME" % pid.upper(), name); put("PLANT_%s_DESC" % pid.upper(), desc)
import json
extra = json.load(open("tools/v07_strings.json")) if os.path.exists("tools/v07_strings.json") else {}
for k, v in extra.items(): put(k, v)
hdr, body = rows[0], sorted(rows[1:], key=lambda r: r[0])
w = csv.writer(open("localization/translations.csv", "w", encoding="utf-8", newline=""), lineterminator="\n")
w.writerow(hdr); w.writerows(body)
print("plants", len(P), "recipes", len(R), "strings", len(body))
