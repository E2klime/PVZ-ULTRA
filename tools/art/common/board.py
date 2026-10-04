"""Board geometry mirrored from core/board.gd (single source for the art pipeline)."""
from __future__ import annotations

ROWS: int = 5
COLS: int = 9
CELL: tuple[int, int] = (130, 140)
ORIGIN: tuple[int, int] = (310, 200)
SIZE: tuple[int, int] = (COLS * CELL[0], ROWS * CELL[1])  # 1170 x 700
RECT: tuple[int, int, int, int] = (ORIGIN[0], ORIGIN[1], ORIGIN[0] + SIZE[0], ORIGIN[1] + SIZE[1])
FEET_OFFSET: float = CELL[1] * 0.32
VIEW: tuple[int, int] = (1920, 1080)
