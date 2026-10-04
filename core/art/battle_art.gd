class_name BattleArt
extends RefCounted
## Builds the battle's art layers around the board (keeps battle.gd free of art code).
## Draw order: surround+ground -> edge overlay -> board (water, coping, hover)
## -> contact shadows -> y-sorted entities (with one grass fringe per lane).

static func build(world: Node2D, board: Board, entities: Node2D, level: LevelData) -> WorldArtConfig:
	var cfg := WorldArtLoader.load_for(level)
	world.add_child(LawnRenderer.new(cfg))
	world.add_child(LawnEdgeOverlay.new(cfg))
	world.add_child(board)
	world.add_child(LawnLighting.new(cfg, entities))
	world.add_child(entities)
	for r: int in Board.ROWS:
		entities.add_child(LawnFringe.new(cfg, board, entities, r))
		for c: int in Board.COLS:
			if level and level.is_blocked(r, c):
				entities.add_child(BlockedProp.new(cfg, r, c))
	if cfg.light_tint != Color.WHITE:
		var cm := CanvasModulate.new()
		cm.color = cfg.light_tint
		world.add_child(cm)
	return cfg
