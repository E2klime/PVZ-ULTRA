class_name ShopItemData
extends Resource

## &"slot", &"start_sun", &"mower_kit", &"hint", &"skin", &"plant"
@export var id: StringName
@export var kind: StringName
@export var name_key: String
@export var desc_key: String
@export var base_price: int = 200
@export var price_step: int = 0
## 0 = unlimited.
@export var max_count: int = 1
@export var skin_color: Color = Color.WHITE
## kind == &"plant": the (legendary) plant this purchase unlocks.
@export var plant_id: StringName = &""

func price_for(owned: int) -> int:
	return base_price + price_step * owned
