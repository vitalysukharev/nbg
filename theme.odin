package main

import "clay"

// --- Theme Colors ---
COLOR_BG_APP :: clay.Color{18, 22, 30, 255} // Main application background
COLOR_BG_PLAYER_BOARD :: clay.Color{48, 42, 60, 255} // Player board background
COLOR_BG_PATTERN_SLOT :: clay.Color{68, 60, 82, 255} // Pattern line empty slot
COLOR_BG_FLOOR_SLOT :: clay.Color{75, 52, 64, 255} // Penalty floor line slot
COLOR_BG_FACTORY_AREA :: clay.Color{30, 136, 229, 255} // Factory container accent
COLOR_BG_FACTORY_DISC :: clay.Color{45, 55, 72, 255} // Individual factory disc
COLOR_TEXT_PATTERN_COUNT :: clay.Color{210, 215, 230, 255} // Text for minified pattern line count

// Wall Colors (Azul 5-tile standard cycle)
@(rodata)
WALL_COLORS := [WALL_DIMENSION]clay.Color {
	{41, 128, 185, 255}, // Blue
	{243, 156, 18, 255}, // Yellow
	{231, 76, 60, 255}, // Red
	{44, 62, 80, 255}, // Black
	{207, 216, 220, 255}, // White / Light Slate
}

// Labels for pattern line capacities (1-indexed)
@(rodata)
PATTERN_LINE_LABELS := [WALL_DIMENSION]string{"1", "2", "3", "4", "5"}

// Placeholder colors distinguish factory tiles from the board palette.
factory_tile_color :: proc(disc_idx, row, col: int) -> clay.Color {
	return {
		f32(40 + (disc_idx * 35) % 200),
		f32(60 + (row * 60) % 180),
		f32(80 + (col * 100) % 160),
		255,
	}
}

// --- Geometry & Typography Metrics ---
CORNER_RADIUS_TILE :: clay.CornerRadius{2, 2, 2, 2}
CORNER_RADIUS_FACTORY :: clay.CornerRadius{4, 4, 4, 4}
CORNER_ROUND_SEGMENTS :: 8
AREAS_GAP_IN_TILES :: 0.5
FACTORY_TILE_GAP_IN_TILES :: 0.1
FACTORY_PADDING_IN_TILES :: 0.1
FACTORY_GAP_IN_TILES :: 0.2
DEFAULT_FONT_SIZE :: 10.0
MIN_PATTERN_COUNT_FONT_SIZE :: 8.0
PATTERN_COUNT_FONT_RATIO :: 0.45
