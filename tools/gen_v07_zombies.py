import re, csv, os
TIERS = {1: "shambler flagbearer intern_imp scrapling sprinter",
 2: "cone_head newspaper hurdler burrower diver snorkeler glider prankster parcel_runner ice_skater mummy camel_rider dreamwalker mirage box_zombie",
 3: "bucket_head shield_carrier angler chimney_sweep disco_manager foreman freezer_technician garden_doctor lantern_thief lifeguard magnet_clerk necromancer pigeon_keeper roof_courier snow_medic snowballer welder cactus_suit astronaut gravity_monk phase_auditor balloon_zombie slingshot_zombie",
 4: "brute scrapbot lunar_herald", 5: "gargantuan_furnace gargantuan_granite gargantuan_storm"}
tier_of = {z: t for t, s in TIERS.items() for z in s.split()}
NEW = {
 "box_zombie": ("res://entities/zombies/zombie.gd", dict(hp=270, armor_hp=420, armor_kind='&"box"', speed=0.15, profile='&"low"', follow_leader="true", threat_cost=2.5, weight=5.0),
   "Cardboard Box Zombie", "Hides in a box right behind another zombie. Straight shots fly over the box - only low shots (Pea Bedding, Thorn Carpet), lobbed shots (catapults) and explosions hit it until the box is torn."),
 "balloon_zombie": ("res://entities/zombies/zombie_sky.gd", dict(hp=270, armor_hp=80, armor_kind='&"balloon"', speed=0.2, profile='&"air"', targets_air="true", threat_cost=2.5, weight=4.0),
   "Balloon Zombie", "Floats over every ground plant and gnaws flying plants. Pop the balloon with anti-air spines, flying plants, wind or explosions."),
 "slingshot_zombie": ("res://entities/zombies/zombie_sky.gd", dict(hp=320, speed=0.18, targets_air="true", ability_interval=2.5, ability_power=40.0, damage=60.0, threat_cost=2.5, weight=4.0),
   "Slingshot Zombie", "Stops to pelt flying plants within 4 tiles with stones. Ground plants are ignored until it reaches them."),
}
for zid, (scr, f, name, desc) in NEW.items():
    lines = ['[gd_resource type="Resource" script_class="ZombieData" format=3]', '',
      '[ext_resource type="Script" path="res://core/data/zombie_data.gd" id="1"]',
      '[ext_resource type="Script" path="%s" id="2"]' % scr, '', '[resource]', 'script = ExtResource("1")',
      'id = &"%s"' % zid, 'name_key = "ZOMBIE_%s_NAME"' % zid.upper(), 'desc_key = "ZOMBIE_%s_DESC"' % zid.upper(),
      'behavior = ExtResource("2")', 'tier = %d' % tier_of[zid]]
    for k, v in f.items():
        lines.append("%s = %s" % (k, repr(v) if isinstance(v, float) else v))
    open("data/zombies/%s.tres" % zid, "w").write("\n".join(lines) + "\n")
for fn in os.listdir("data/zombies"):
    zid = fn[:-5]; p = "data/zombies/" + fn
    s = open(p).read()
    t = tier_of.get(zid, 2)
    if re.search(r"^tier = ", s, re.M):
        s = re.sub(r"^tier = \d+", "tier = %d" % t, s, flags=re.M)
    else:
        s = s.rstrip("\n") + "\ntier = %d\n" % t
    open(p, "w").write(s)
import json
ex = json.load(open("tools/v07_strings.json")) if os.path.exists("tools/v07_strings.json") else {}
for zid, (_, _, name, desc) in NEW.items():
    ex["ZOMBIE_%s_NAME" % zid.upper()] = name; ex["ZOMBIE_%s_DESC" % zid.upper()] = desc
json.dump(ex, open("tools/v07_strings.json", "w"), indent=1, ensure_ascii=False)
print("ok", len(tier_of))
