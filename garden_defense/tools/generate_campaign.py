from pathlib import Path
import json, random, re, argparse
ROOT=Path(__file__).resolve().parents[1]
_parser=argparse.ArgumentParser(description="Reproduce the v0.5 baseline; overwrites campaign manifests and expansion resources.")
_parser.add_argument('--overwrite', action='store_true', help='Explicitly overwrite existing campaign content')
_args=_parser.parse_args()
if (ROOT/'data/campaign/lawn.json').exists() and not _args.overwrite:
    _parser.error('Campaign already exists. Edit the manifests directly, or deliberately pass --overwrite.')
# Enemy records: ID, family, trait, HP, armor, speed, power, joke/counterplay.
enemies=[
('newspaper','adaptive','rage',420,0,.16,40,'Loses the crossword, doubles the speed. Finish him before half health.'),
('garden_doctor','support','heal',360,0,.15,65,'Prescribes compost to everyone except you. Heals nearby zombies; focus fire.'),
('parcel_runner','trickster','vault',310,0,.27,40,'Delivery instructions: leave over the wall. Tall walls stop the first vault.'),
('prankster','trickster','sidestep',330,0,.19,40,'Changes lanes without indicating. Cover adjacent lanes.'),
('diver','trickster','dive',400,0,.18,40,'Two seconds underwater, six excuses. Briefly untargetable in water.'),
('snorkeler','trickster','swimmer',350,100,.18,40,'Paid for the fast lane at the pool. Moves faster while swimming.'),
('lifeguard','support','shield_aura',500,150,.14,35,'Protects everyone except the swimmers. Grants bounded armor nearby.'),
('angler','ranged','lob',390,0,.15,65,'Catch of the day: your front plant. Lobs damage within five cells.'),
('lantern_thief','ranged','drain',320,0,.20,25,'Solar tax collector. Steals small sun payments; keep reserves.'),
('necromancer','support','summon',650,0,.13,40,'Raises staffing levels, literally. Summons at most three interns.'),
('dreamwalker','trickster','phase',420,0,.16,40,'Sleepwalks through obstacles for two seconds. Keep a rear defense.'),
('disco_manager','support','haste',450,100,.16,25,'Mandatory fun advances nearby coworkers. Eliminate the squad leader.'),
('mummy','adaptive','revive',620,0,.13,40,'A return policy older than commerce. Revives once; mowers bypass it.'),
('camel_rider','trickster','vault',500,150,.24,40,'The camel is also a zombie. Vaults once unless stopped by a tall plant.'),
('mirage','trickster','phase',380,0,.22,40,'Not a hallucination, unfortunately. Briefly phases; area timing matters.'),
('cactus_suit','adaptive','resist',420,600,.13,40,'Dress code: sharp casual. Armor reduces projectile damage; use explosions.'),
('chimney_sweep','bomber','bomb',500,0,.17,600,'Three-second fuse, zero safety training. Kill before it reaches a plant.'),
('glider','trickster','vault',350,0,.30,40,'Took the scenic route over your wall. Tall plants intercept the landing.'),
('roof_courier','trickster','sidestep',480,200,.22,40,'Every staircase is the wrong staircase. Switches lanes periodically.'),
('pigeon_keeper','support','summon',600,0,.15,40,'The pigeons filed for remote work. Sends three interns instead.'),
('ice_skater','trickster','skater',400,100,.22,40,'No brakes, no refund. Slows down when chilled.'),
('freezer_technician','ranged','freeze_seed',460,250,.14,60,'Refrigerates your seed packet. Ranged hits briefly lock its recharge.'),
('snow_medic','support','heal',560,100,.14,100,'Ice packs for the already cold. Heals nearby damaged zombies.'),
('snowballer','ranged','lob',380,0,.20,95,'One snowball, several complaints. Lobs at the front plant.'),
('welder','support','repair',500,450,.13,90,'Repairs helmets, not relationships. Restores existing armor nearby.'),
('magnet_clerk','ranged','drain',440,200,.18,40,'Accepts only solar currency. Drains bounded amounts of sun.'),
('foreman','support','haste',620,300,.15,45,'The deadline is your doorstep. Moves nearby zombies forward.'),
('scrapbot','adaptive','split',650,400,.14,40,'Break it and receive two smaller problems. Splits unless mowed.'),
('astronaut','trickster','vault',520,250,.23,40,'One small leap for an unpaid intern. A tall plant stops the jump.'),
('gravity_monk','trickster','sidestep',620,200,.16,40,'Enlightenment is apparently in the next lane. Covers need to overlap.'),
('phase_auditor','trickster','phase',600,300,.18,40,'Your defenses failed a metaphysical inspection. Phases periodically.'),
('lunar_herald','support','summon',800,400,.12,40,'Announces doom in triplicate. Limited summons; prioritize the herald.'),
('intern_imp','base','',160,0,.28,40,'Small, fast, and still on probation. Cheap area damage solves the meeting.'),
('scrapling','base','',200,80,.25,40,'Some assembly regrettably included. Fragile offspring of Scrapbot.'),
('gargantuan_granite','garg','granite',1800,0,.095,40,'Throws two interns at half health. Freeze the giant and guard your rear lanes.'),
('gargantuan_furnace','garg','furnace',2300,700,.085,40,'Short-range furnace pulses. Frost pauses the heater; explosives break armor.'),
('gargantuan_storm','garg','storm',2700,900,.08,40,'Half-health EMP briefly delays seeds; pulses hit nearby lanes. Spread defenses.')]
worlds=[
('lawn','1 · Suburban Lawn','#74ac4f','normal','Five lanes, blocked flowerbeds, and the least professional neighborhood watch.'),
('pool','2 · Poolside Panic','#4d9db0','tide','Water needs Lily Rafts. A tide pulse delivers 75 sun every 28 seconds.'),
('night','3 · Midnight Cemetery','#655480','night','No natural sky sun. Moonlight pulses give 50 sun; producers are essential.'),
('desert','4 · Desert Detour','#c99753','heat','Heat visits one announced lane every 28 seconds, damaging plants by 25.'),
('roof','5 · Rooftop Ruckus','#a27667','wind','Announced gusts push zombies back in one lane. Construction blocks some tiles.'),
('frost','6 · Frozen Allotment','#80bacc','frost','Cold pulses delay all seed cooldowns by 1.5 seconds and slow one zombie lane.'),
('factory','7 · Compost Factory','#738a82','conveyor','Conveyor pulses advance one announced lane by 35 pixels. Keep rear firepower.'),
('moon','8 · Lunar Greenhouse','#79759f','low_gravity','Gravity pulses shift an announced lane into the next lane. Use overlapping cover.')]
# Each world has 25 authored story titles, paired with distinct scenario beats.
titles=[
['Welcome Mat','Sun Is Not a Subscription','Cone of Shame','The Lawn Doctor','Express Delivery','Twenty Is Plenty','No Refunds on Roots','Wrong Lane, Mate','The Solar Savings Account','Overtime for the Mowers','Interns at the Gate','Crossword Violence','Bring Your Own Salad','Five Casualties Maximum','The Graft Draft','Garden Artillery Club','Fence Permit Pending','The Night Shift Preview','Bucket List','Seed Packet Diet','Save the Picnic','Four Thousand Reasons','The Unpaid Internship','Neighborhood Meeting','Granite Eviction Notice'],
['Water You Doing','Raft Before Reason','The Deep End','Certified Lifeguard','Fishy Business','Twenty Floating Decisions','No Splashing the Sunbuds','Lane Rope Optional','Solar Pool Heater','Adults Swim Last','Diving for Complaints','Fast Lane Snorkel','Poolside Buffet','Five Floaters Maximum','Grafted Water Lilies','Depth Charge Tuesday','Island Gardening','Lights Out at the Lido','Bucket and Spade','Raft Rationing','Save the Lifeguard Chair','Four Thousand Sunblock','Interns Overboard','Everyone Out of the Pool','Granite Makes a Splash'],
['Graveyard Orientation','Moonlight on Credit','Lantern Tax','HR Necromancy','Dreamwalk This Way','Twenty Tombstone Planters','Root of All Evil','Disco in the Wrong Grave','The Midnight Reserve','No Mower After Midnight','Interns from Accounting','Mandatory Disco','Funeral Arrangement','Five Eulogies Maximum','Graftyard Shift','Ghostbuster Without Plants','Graves Need Permits','Power Cut Picnic','Bucket Beyond the Grave','Seeds for the Sleepless','Protect the Night Watch','Four Thousand Moons','Resurrection Paperwork','Last Dance at Dawn','Granite Grave Mistake'],
['Sand in the Seed Packet','Solar Oven Economics','Mummy Returns Department','Camel Parking Only','Mirage Management','Twenty Oasis Permits','Roots Have Rights','Dunes Without Indicators','The Oasis Reserve','No Mower in the Desert','Internship Excavation','Cactus Dress Code','Oasis Tasting Menu','Five Wilted Reports','Graft Like an Egyptian','Sandblast Artillery','Ruins Under Renovation','Sunset Without Sun','Bucket Archaeology','Drought Rations','Save the Oasis','Four Thousand Degrees','Twice Dead, Once Paid','Desert Rush Hour','Furnace Inspection Day'],
['Stairs Not Included','Solar Panels Not Included','Chimney Safety Seminar','Glider Parking','Courier Takes the Lift','Twenty Rooftop Pots','Roots on the Roof','Pigeon Traffic Control','Emergency Roof Reserve','Mowers Fear Heights','Interns on the Fire Escape','The Pigeon Union','Rooftop Cafe','Five Falling Flowerpots','Graft Above the Clouds','Anti-Air Salad Battery','Construction Permit Pending','Night on the Tiles','Bucket Under a Leak','Seeds in Carry-On','Save the Roof Garden','Four Thousand Skylights','Special Delivery Upstairs','Rush Hour on the Roof','Furnace on the Fire Escape'],
['Cold Open','Sun in the Freezer','Skating Without Consent','Appliance Repair Visit','Snowball Negotiations','Twenty Ice Pots','Frostbite for Vegetables','Snow Medic Shortcut','Winter Fuel Reserve','Mowers on Thin Ice','Interns in Thermal Socks','Snowball Fight Club','Frozen Dinner Selection','Five Cold Cases','Grafting in Mittens','Snow Cannon Without Plants','Closed for Defrosting','Polar Night Picnic','Bucket with a Frozen Handle','Seed Packet Hypothermia','Save the Winter Garden','Four Thousand Warm Thoughts','Medic on Ice','The Blizzard Committee','Furnace Defrost Cycle'],
['Factory Orientation','Solar Salary Negotiations','Welding the Wrong Helmet','Magnetic Accounting','Foreman Says Hurry','Twenty Production Units','Root Cause Analysis','Assembly Line Detour','Emergency Power Reserve','Mowers on Strike','Interns in Hard Hats','Scrapbot Warranty Claim','Canteen Fixed Menu','Five Workplace Incidents','Graft Quality Assurance','Industrial Salad Cannon','Floor Closed for Maintenance','Night Shift Blackout','Bucket ISO Certification','Lean Seed Manufacturing','Save the Union Garden','Four Thousand Solar Credits','Some Disassembly Required','Mandatory Overtime','Storm Safety Audit'],
['One Small Plant','Sun Has Roaming Charges','Astronaut Internship','Gravity Is Optional','Audit of Reality','Twenty Lunar Licenses','Roots in a Vacuum','The Enlightened Detour','Orbital Solar Reserve','Mowers Cannot Breathe','Interns in Orbit','The Herald of Late Fees','Space Food Selection','Five Cosmic Casualties','Zero-Gravity Grafting','Orbital Garden Cannon','Moon Craters Need Permits','Eclipse Picnic','Bucket with Life Support','Seed Payload Limit','Save the Last Greenhouse','Four Thousand Stars','Multiverse Staffing Crisis','The Three-Giant Summit','Final Notice: Get Off My Moon']]
beats=['intro','economy','introduce','introduce','introduce','limit','preserve','introduce','bank','mowerless','rush','elite','fixed','loss','graft','artillery','blocked','blackout','armor','limited_fixed','holdout','collect','summons','gauntlet','boss']
jokes=[
'The welcome mat says hello, not all-you-can-eat.', 'Sunlight remains free. The zombie subscription is harder to cancel.',
'Local traffic cone promoted to middle management.', 'The doctor recommends more brains. Seek a second opinion.',
'Your delivery is three lanes away and marked delivered.', 'Twenty plants. Infinite unsolicited gardening opinions.',
'The roots have formed a union. Please keep them alive.', 'Turn signals are apparently a living-person feature.',
'Four thousand sun in savings. Still cannot afford a garden shed.', 'The mowers have requested a mental-health day.',
'An internship with excellent exposure and no pulse.', 'This wave has read the terms and conditions. You have not.',
'The chef insists the menu is a tactical constraint.', 'Five losses are a tragedy. Six are a failed level.',
'Botany: now with legally questionable welding.', 'No plants today. The salad has authorized artillery.',
'These tiles are reserved for a future parking lot.', 'Solar power at night: accounting would like a word.',
'Buckets protect brains, not fragile workplace morale.', 'The seeds were packed by a minimalist.',
'The garden is already planted. Your job description says keep it that way.', 'Collect 4000 sun. Do not stare directly at the counter.',
'Fresh interns have arrived. Their onboarding is your problem.', 'The committee has decided to attack simultaneously.',
'The giant brought a club. The homeowners association brought a fine.']
# Write new static enemies as ordinary resources, visible in the existing almanac.
for ix,(id,fam,trait,hp,armor,speed,power,desc) in enumerate(enemies):
    behavior='zombie.gd' if fam=='base' else (id+'.gd' if fam=='garg' else 'zombie_'+fam+'.gd')
    title=id.replace('_',' ').title()
    props={'hp':hp,'armor_hp':armor,'speed':speed,'damage':100 if fam!='garg' else 500,'eat_interval':.5 if fam!='garg' else 2.0,'threat_cost':round((hp+armor)/300,1),'weight':6.0,'ability_power':power,'ability_interval':10 if fam!='garg' else 15,'body_scale':1.5 if fam=='garg' else .72 if id in ('intern_imp','scrapling') else 1.0}
    lines=['[gd_resource type="Resource" script_class="ZombieData" format=3]',f'[ext_resource type="Script" path="res://core/data/zombie_data.gd" id="1"]',f'[ext_resource type="Script" path="res://entities/zombies/{behavior}" id="2"]','[resource]','script = ExtResource("1")',f'id = &"{id}"',f'name_key = {json.dumps(title)}',f'desc_key = {json.dumps(desc)}','behavior = ExtResource("2")',f'ability_kind = &"{trait}"']
    lines += [f'{k} = {v}' for k,v in props.items()]
    if armor: lines+=['armor_kind = &"bucket"']
    if fam=='garg': lines+=['immune_to = Array[StringName]([&"devour", &"push", &"pull"])']
    if trait in ('summon','split'): lines += [f'summon_id = &"{"scrapling" if trait=="split" else "intern_imp"}"']
    lines += [f'color_skin = Color({.45+(ix%4)*.08}, {.57+(ix%3)*.06}, {.44+(ix%5)*.05}, 1)',f'color_cloth = Color({.25+(ix%7)*.07}, {.28+(ix%5)*.08}, {.3+(ix%6)*.08}, 1)']
    (ROOT/'data/zombies'/f'{id}.tres').write_text('\n'.join(lines)+'\n')
local_jokes=[
['The HOA has banned brains after 9 PM.','Your neighbor insists this is normal lawn aeration.','The fence contractor accepts payment in screams.','A tasteful garden gnome has declined to intervene.','Neighborhood watch is currently watching from indoors.'],
['No diving, except the guy who ignored the sign.','The pool filter is reconsidering its career.','The lifeguard whistle is decorative, apparently.','The shallow end has surprisingly deep staffing issues.','A rubber duck has filed the only useful incident report.'],
['The cemetery quiet hours have been postponed indefinitely.','Necromancy is not covered by the employee handbook.','The ghost requested a window seat in a building without windows.','The disco has a strict bring-your-own-pulse policy.','The grave digger has started charging by the encore.'],
['The cactus is the only local with appropriate work clothes.','The oasis is rated one star for excessive zombies.','The mummy has a lifetime warranty and intends to use it.','The camel refuses to validate parking.','Sand is nature’s most persistent customer-support ticket.'],
['The elevator is out; so is common sense.','The pigeons have delegated all liability to management.','The roof warranty specifically excludes giant clubs.','The chimney sweep has interpreted clean-up as demolition.','A penthouse view apparently includes incoming zombies.'],
['The snowman says this is a hostile work environment.','Cold storage was never meant to store your seed packets.','The skating rink has removed the safety rail for budget reasons.','The thermostat is now a negotiation partner.','The hot cocoa fund has been diverted to emergency botany.'],
['The safety poster says zero accidents since twelve seconds ago.','The foreman has optimized away the coffee break.','The compost machine insists this is all organic.','The welding mask does not improve the wearer’s judgment.','The assembly line has assembled a queue of complaints.'],
['The greenhouse airlock is not an all-you-can-eat entrance.','Gravity has submitted a flexible-working request.','The lunar landlord wants the crater back by Monday.','Space is silent; the seed packet is loudly disappointed.','Mission control has replied with a gardening emoji.']]
# Campaign plant rewards arrive before their first mechanics lesson.
rewards={('lawn',1):'bark_wall',('lawn',2):'thorn_mine',('lawn',3):'ember_berry',('lawn',5):'frost_mint',('lawn',7):'snapper_trap',('lawn',9):'bramble_vine',('lawn',11):'lantern_bloom',('lawn',13):'gale_fern',('lawn',17):'pepper_stinger',('lawn',19):'hive_pod',('lawn',21):'dandelion_puff',('pool',1):'lily_raft',('pool',5):'rime_lettuce',('night',25):'sun_sovereign',('desert',25):'phoenix_lily',('factory',25):'storm_thistle',('moon',20):'elder_oak'}
all_levels=[]
for wi,(world,name,color,rule,rule_text) in enumerate(worlds):
    native=[e[0] for e in enemies[wi*4:wi*4+4]]
    entries=[]
    for j,beat in enumerate(beats,1):
        rng=random.Random((wi+1)*1000+j)
        layout=[list('.........') for _ in range(5)]
        if world=='pool':
            for rr in range(1,4):
                for cc in range(2+(j+rr)%3,8-(j+rr)%2): layout[rr][cc]='~'
            # Islands and canals vary per mission rather than repeating two pool shapes.
            for k in range(1+j%4):
                rr=1+(j+k)%3; cc=2+(j*3+k*2)%6
                layout[rr][cc]='.' if layout[rr][cc]=='~' else '~'
            if j>10: layout[0 if j%2 else 4][2+j%5]='~' 
        if beat=='blocked' or (world in ('roof','desert','moon') and j%4==0):
            for rr in range(5): layout[rr][6+(rr+j)%3]='#'
        if world=='moon' and j%3==0:
            layout[(j//3)%5][4]='#'
        layout=[''.join(r) for r in layout]
        pool=['shambler']
        if j>=3: pool+=['cone_head']
        if j>=8: pool+=['bucket_head']
        count=0 if j < 3 else min(4, j-2)
        pool+=native[:count]
        if j>=11: pool+=['intern_imp']
        if j>=19: pool+=['shield_carrier']
        if wi>=1 and j>=12: pool+=['hurdler']
        if wi>=2 and j>=18: pool+=['burrower']
        if wi>=4 and j>=24: pool+=['brute']
        if j>=24: pool+=['sprinter']
        objectives=[]; fixed=[]; banned=[]; pre=[]; mode='defense'
        sky=world!='night'; sun=(250 if wi==0 and j<=2 else 350+wi*110); sun_value=25; sky_gap=7.5; first=40.0; gap=34.0
        waves=4+min(4,j//6)+(1 if wi>=4 else 0)
        if beat=='limit': objectives=[{'type':'plant_limit','target':20}]; sun+=150
        if beat=='preserve': objectives=[{'type':'loss_limit','target':3}]; sun+=100
        if beat=='bank': objectives=[{'type':'bank_sun','target':4000}]; sun_value=75; sky_gap=5; sky=True; waves+=2
        if beat=='loss': objectives=[{'type':'loss_limit','target':5}]
        if beat=='graft': objectives=[{'type':'graft_count','target':2}]; fixed=['sunbud','pod_shooter','frost_mint','bark_wall']; sun+=250
        if beat=='artillery': mode='artillery'; sun=0; sky=False; waves=6; first=8; gap=24; pool=['shambler','cone_head',native[0],native[1]]
        if beat=='fixed': fixed=['sunbud','pod_shooter','bark_wall','thorn_mine','ember_berry']; sun+=100
        if beat=='blackout': sky=False; fixed=['sunbud','pod_shooter','bark_wall','frost_mint']; sun+=150
        if beat=='mowerless': objectives=[{'type':'no_breach','target':0}]; sun+=200
        if beat=='limited_fixed': fixed=['sunbud','pod_shooter','bark_wall','frost_mint']; objectives=[{'type':'plant_limit','target':20}]; sun+=200
        if beat=='holdout':
            mode='holdout'; sky=False; objectives=[{'type':'loss_limit','target':5}]; first=10; gap=28
            # Prepared guns face right: no rear-entry burrowers or phase bypasses in a non-replantable garden.
            pool=['shambler','cone_head','bucket_head',native[0]]
            for rr in range(5):
                for cc,p in [(0,'sunbud'),(1,'twin_pod'),(2,'twin_pod'),(3,'frost_mint'),(5,'ironbark_wall')]:
                    pre.append({'id':p,'row':rr,'col':cc})
            # Prepared garden is dry; no hidden requirement to bring raft seeds.
            layout=['.........']*5
        if beat=='collect': objectives=[{'type':'collect_sun','target':4000}]; sky=True; sun_value=100; sky_gap=5; waves+=2
        if beat=='rush': first=25; gap=25; objectives=[{'type':'time_limit','target':600}]
        if beat=='armor': pool=['shambler','bucket_head','shield_carrier',native[3]]
        if beat=='summons': pool=['shambler',native[3],native[1],'intern_imp']
        boss='gargantuan_granite' if wi<3 else 'gargantuan_furnace' if wi<6 else 'gargantuan_storm'
        if beat=='boss': pool.append(boss); sun+=400; first=50; waves=8; objectives=[{'type':'no_breach','target':0}] if wi==7 else []
        if beat=='gauntlet' and wi==7: pool+=['gargantuan_granite','gargantuan_furnace','gargantuan_storm']; waves=9; sun+=300
        specs=[]
        for wave in range(waves):
            lane_order=[(j+wave+k*2+wi)%5 for k in range(5)]
            if wi==0 and j<=2:
                lane_order=[2] if wave==0 else ([1,2,3] if wave==1 else [0,1,2,3,4])
            n=2+wi//2+j//12+wave//3
            if wi==0 and j<=2: n=1+wave
            if beat in ('rush','gauntlet'): n+=2
            if beat=='holdout': n=min(n,8)
            units=[]
            for k in range(n):
                # Stable authored placements; opening waves teach the native enemy in one lane.
                choices=[p for p in pool if not p.startswith('gargantuan')]
                z='shambler' if wave==0 and k<2 else rng.choice(choices)
                if k%2==0 and beat!='armor': z='shambler'
                if beat=='introduce' and wave==1 and k==0: z=native[min(3,(j-3)%4)]
                units.append({'id':z,'row':lane_order[k%len(lane_order)],'delay':round(k*(1.4 if beat=='rush' else 2.0),1)})
            if j==12 and wi==1 and wave==2: units.append({'id':'hurdler','row':2,'delay':6})
            if j==18 and wi==2 and wave==2: units.append({'id':'burrower','row':1,'delay':6})
            if j==24 and wi==4 and wave==waves-1: units.append({'id':'brute','row':2,'delay':6})
            if wave==waves-1: units.append({'id':'flagbearer','row':j%5,'delay':0})
            if beat=='boss' and wave in (waves-3,waves-1): units.append({'id':boss,'row':(j+wave)%5,'delay':8.0})
            if beat=='gauntlet' and wi==7 and wave in (2,5,8): units.append({'id':['gargantuan_granite','gargantuan_furnace','gargantuan_storm'][wave//3],'row':wave%5,'delay':9})
            specs.append({'flag':wave==waves-1 or wave%4==3,'spawns':units})
        # Every enemy referenced in actual waves must be included in the preview pool.
        actual=list(dict.fromkeys(p['id'] for s in specs for p in s['spawns']))
        for p in actual:
            if p not in pool: pool.append(p)
        briefing=rule_text+' '+{
        'intro':'Establish economy and cover all five lanes.','economy':'Build sun production before doubling your shooters.',
        'introduce':'A new specialist joins the queue. Read its almanac counter before starting.',
        'limit':'Win with at most 20 planting actions, including grafts and rafts.',
        'preserve':'Lose no more than 3 plants to attacks or shoveling. Single-use plants do not count.',
        'bank':'Hold 4000 unspent sun and clear all waves. Collection continues after the last zombie.',
        'mowerless':'No mowers. Any breach fails the mission.','rush':'Clear the fast waves within 600 seconds.',
        'elite':'Cover the specialist wave; avoid relying on a single front wall.',
        'fixed':'The supplied seed menu is fixed. Supplies are borrowed even if not yet unlocked.',
        'loss':'Lose no more than 5 plants. Transformations and deliberate single-use plants are exempt.',
        'graft':'Create at least 2 grafts and clear the waves. Same-plant twin hybrids count too.',
        'artillery':'No plants or seeds required. Click a board tile to fire a free recharging area cannon.',
        'blocked':'Dark crossed tiles cannot be planted. Zombies still travel through them.',
        'blackout':'No sky sun. Start from the supplied savings and plant your own economy.',
        'armor':'Armor soaks projectiles. Save explosives for tightly grouped helmets.',
        'limited_fixed':'Fixed four-seed deck and a total limit of 20 planting actions.',
        'holdout':'No planting. A mature garden is provided. Collect sun and protect it; click a damaged plant for a free 1200-HP repair every 3 seconds. Crafted tools are optional.',
        'collect':'Collect a total of 4000 sun in this battle. Spending does not reduce this total.',
        'summons':'Summoners and small runners require rear coverage, not just one front tank.',
        'gauntlet':'Long mixed assault. On the Moon, all three Gargantuans arrive in separate waves.',
        'boss':'Two giant arrivals with a rebuilding window. Counter its special ability, then clear the field.'}[beat]
        entry=dict(id=f'{world}_{j:02}',number=j,title=f'{wi+1}-{j:02} · {titles[wi][j-1]}',briefing=briefing,joke=jokes[j-1]+' '+local_jokes[wi][(j-1)%5],scenario=beat,mode=mode,field_rule=rule,layout=layout,objectives=objectives,wave_specs=specs,zombie_pool=pool,fixed_seeds=fixed,banned_plants=banned,preplants=pre,start_sun=sun,sky_sun=sky,sky_sun_value=sun_value,sky_sun_interval=sky_gap,first_wave_delay=first,wave_interval=gap,hybrid_cap=0 if j<5 and wi==0 else 6+wi,mowers=beat!='mowerless',reward_plant=rewards.get((world,j),''),reward_feature='graft' if (world,j)==('lawn',4) else '',reward_coins=70+wi*35+j*3,materials={'compost':3+wi//2,'scrap':2+wi//2,'crystal':1 if j%5==0 else 0},artillery_damage=550+wi*100,artillery_cooldown=1.8)
        entries.append(entry);all_levels.append(entry)
    manifest=dict(schema_version=1,id=world,name=name,order=wi,previous=worlds[wi-1][0] if wi else '',color=color,rule_text=rule_text,levels=entries)
    (ROOT/'data/campaign'/f'{world}.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    doc=['# '+name,'',rule_text,'','All 25 levels are mandatory; clear the previous world to unlock this world.','','| Level | Title | Mode | Objectives | Waves | First-clear plant |','|---|---|---|---|---:|---|']
    for l in entries:
        obj=', '.join(f"{o['type']}={o['target']}" for o in l['objectives']) or 'Clear waves'
        doc.append(f"| {l['number']} | {l['title']} | {l['mode']} | {obj} | {len(l['wave_specs'])} | {l['reward_plant'] or '—'} |")
    doc += ['','## Mission briefings']
    for l in entries: doc += [f"\n### {l['title']}",l['briefing'],f"Opening line: {l['joke']}"]
    (ROOT/'docs/campaign'/f'{world}.md').write_text('\n'.join(doc)+'\n')
# Graft expansion uses existing behavior implementations, with distinct stat combinations.
hybrids=[
('solar_turret','sunbud','pod_shooter','shooter',dict(damage=25,sun_amount=25,sun_interval=20)),
('ember_pod','pod_shooter','ember_berry','shooter',dict(damage=28,burn_dps=14,burn_time=3)),
('hail_volley','twin_pod','frost_mint','shooter',dict(damage=18,shots=3,slow_factor=.65,slow_duration=3)),
('bee_cannon','pod_shooter','hive_pod','hive',dict(damage=25,summon_max=4,attack_interval=2.5)),
('solar_barricade','bark_wall','sunbud','wall',dict(max_hp=4200,sun_amount=50,sun_interval=24)),
('frost_barrier','bark_wall','frost_mint','wall',dict(max_hp=4800,thorns_damage=55)),
('pepper_hive','hive_pod','pepper_stinger','hive',dict(damage=40,summon_max=5,attack_interval=2.4)),
('storm_pod','pod_shooter','lantern_bloom','storm',dict(damage=35,chain_count=2,chain_range=2.2,attack_interval=2.4)),
('healing_lantern','lantern_bloom','sunbud','support',dict(buff_mult=1.55,regen_per_sec=10,max_hp=650)),
('ice_mine','thorn_mine','frost_mint','mine',dict(damage=1000,arm_time=5,aoe_radius=1.3,slow_factor=.4,slow_duration=6)),
('sun_mine','thorn_mine','sunbud','mine',dict(damage=1400,arm_time=4,aoe_radius=1.2,sun_amount=125)),
('pepper_wall','bark_wall','pepper_stinger','wall',dict(max_hp=5000,thorns_damage=130)),
('gale_pod','gale_fern','pod_shooter','shooter',dict(damage=22,push_distance=30,attack_interval=1.8)),
('ember_vine','bramble_vine','ember_berry','aoe',dict(damage=40,burn_dps=25,burn_time=4,aoe_radius=1.2,attack_interval=2.6)),
('glacial_hive','hive_pod','frost_mint','hive',dict(damage=32,summon_max=4,attack_interval=2.0)),
('thorn_lantern','lantern_bloom','bark_wall','support',dict(max_hp=2300,buff_mult=1.4,thorns_damage=50)),
('ember_snapper','snapper_trap','ember_berry','trap',dict(damage=1800,chew_time=14,max_hp=600)),
('needle_storm','pepper_stinger','lantern_bloom','storm',dict(damage=55,chain_count=3,chain_range=2.8,attack_interval=2.8))]
# A hybrid economy shooter/wall needs a small shared utility component.
for ix,(id,base,cat,fam,stats) in enumerate(hybrids):
    behavior='plant_dual_'+fam+'.gd' if id in ('solar_turret','solar_barricade') else 'plant_'+fam+'.gd'
    lines=['[gd_resource type="Resource" script_class="PlantData" format=3]','[ext_resource type="Script" path="res://core/data/plant_data.gd" id="1"]',f'[ext_resource type="Script" path="res://entities/plants/{behavior}" id="2"]','[resource]','script = ExtResource("1")',f'id = &"{id}"',f'name_key = {json.dumps(id.replace("_"," ").title())}',f'desc_key = {json.dumps("Graft "+base+" + "+cat+". "+str(stats))}','behavior = ExtResource("2")','is_seed = false','is_hybrid = true',f'role = &"{fam}"','color_main = Color(0.4, 0.65, 0.6, 1)','color_accent = Color(0.9, 0.7, 0.2, 1)']
    lines += [f'{k} = {v}' for k,v in stats.items()]
    (ROOT/'data/plants'/f'{id}.tres').write_text('\n'.join(lines)+'\n')
    recipe=['[gd_resource type="Resource" script_class="FusionRecipe" format=3]','[ext_resource type="Script" path="res://core/data/fusion_recipe.gd" id="1"]','[resource]','script = ExtResource("1")',f'base_id = &"{base}"',f'catalyst_id = &"{cat}"',f'result_id = &"{id}"',f'fee = {25+ix//6*25}']
    (ROOT/'data/fusion'/f'{id}.tres').write_text('\n'.join(recipe)+'\n')
print(f'Generated {len(all_levels)} explicit levels, {len(enemies)} new enemies, {len(hybrids)} new grafts.')
