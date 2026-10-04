class_name MapData
extends Resource

@export var id: StringName
@export var name_key: String
@export var rows: int = 5
@export var cols: int = 9
@export var sky_sun: bool = true
@export var is_night: bool = false
@export var available: bool = false
@export var tint: Color = Color(0.4, 0.7, 0.3)
@export var start_node: StringName
@export var nodes: Array[MapNodeData] = []

func get_node_data(node_id: StringName) -> MapNodeData:
	for n: MapNodeData in nodes:
		if n.id == node_id:
			return n
	return null

func predecessors(node_id: StringName) -> Array[MapNodeData]:
	var out: Array[MapNodeData] = []
	for n: MapNodeData in nodes:
		if node_id in n.next_ids:
			out.append(n)
	return out

@export var order: int = 0
@export var previous_world: StringName = &""
@export var rule_text: String = ""
