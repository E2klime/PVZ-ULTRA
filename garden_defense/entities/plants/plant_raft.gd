class_name PlantRaft
extends Plant
## Lily Raft: floating platform for pool cells. Other plants are planted on top
## of it; the raft itself is a weak blocker that zombies chew through.

func sway_amount() -> float:
	return 0.3
