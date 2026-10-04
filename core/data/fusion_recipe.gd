class_name FusionRecipe
extends Resource

@export var base_id: StringName
@export var catalyst_id: StringName
@export var result_id: StringName
@export var fee: int = 25
@export var hidden_until_discovered: bool = true

func recipe_id() -> StringName:
	return StringName("%s+%s" % [base_id, catalyst_id])
