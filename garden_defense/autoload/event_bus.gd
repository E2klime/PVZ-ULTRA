extends Node
## Global signals. Keep it thin: only cross-system events live here.

signal screen_requested(screen: StringName, args: Dictionary)
signal coins_changed(total: int)
signal stars_changed(total: int)
signal zombie_killed(zombie_id: StringName)
signal plant_planted(plant_id: StringName)
signal plant_fused(result_id: StringName)
signal recipe_discovered(recipe_id: StringName)
signal sun_collected(amount: int)
signal level_finished(level_id: StringName, won: bool)
signal quest_ready(quest_id: StringName)
