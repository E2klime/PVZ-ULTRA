class_name MapNodeData
extends Resource

enum NodeType { LEVEL, SHOP, GATE, BONUS, HUB_LINK }

@export var id: StringName
@export var type: NodeType = NodeType.LEVEL
@export var position: Vector2
@export var level_id: StringName
@export var next_ids: Array[StringName] = []
@export var requires_stars: int = 0
## All of these must be completed.
@export var requires_nodes: Array[StringName] = []
@export var optional: bool = false
