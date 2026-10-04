class_name QuestData
extends Resource

@export var id: StringName
@export var title_key: String
@export var desc_key: String
## Name of a counter in SaveManager stats (e.g. "kill_shambler", "wins", "grafts").
@export var stat: StringName
@export var amount: int = 1
@export var reward_coins: int = 50
@export var reward_hint: bool = false
