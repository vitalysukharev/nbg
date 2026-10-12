package main

import "clay"

// --- Theme Colors ---
COLOR_BG_APP :: clay.Color{232, 210, 179, 255} // Light wood fallback
COLOR_BG_PLAYER_BOARD :: clay.Color{222, 214, 190, 255} // Ivory board fallback
COLOR_BG_PATTERN_SLOT :: clay.Color{74, 67, 54, 65} // Recess over the board texture
COLOR_BG_FLOOR_SLOT :: clay.Color{138, 76, 61, 65} // Warm penalty row recess
COLOR_BG_FACTORY_AREA :: clay.Color{18, 22, 30, 0} // Let individual trays define the area
COLOR_BG_FACTORY_DISC :: clay.Color{45, 55, 72, 255} // Individual factory disc
COLOR_TEXT_PATTERN_COUNT :: clay.Color{65, 63, 59, 255} // Ink on the ivory board
COLOR_TEXT_FLOOR_PENALTY :: clay.Color{113, 54, 41, 255}

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

@(rodata)
FLOOR_PENALTY_LABELS := [FLOOR_SIZE]string{"−1", "−1", "−2", "−2", "−2", "−3", "−3"}

// --- Geometry & Typography Metrics ---
CORNER_RADIUS_TILE :: clay.CornerRadius{2, 2, 2, 2}
CORNER_RADIUS_FACTORY :: clay.CornerRadius{4, 4, 4, 4}
CORNER_ROUND_SEGMENTS :: 8
AREAS_GAP_IN_TILES :: 0.5
PLAYER_BOARD_PADDING_IN_TILES :: 1.6 // Keep slots clear of the frame and corner ornaments.
FLOOR_LABEL_GAP_IN_TILES :: 0.1
FLOOR_LABEL_HEIGHT_IN_TILES :: 0.7
FACTORY_TILE_GAP_IN_TILES :: 0.1
FACTORY_PADDING_IN_TILES :: 0.1
FACTORY_GAP_IN_TILES :: 0.2
UI_FONT_PATH :: "assets/fonts/spectral-semibold.fnt"
DEFAULT_FONT_SIZE :: 12.0
MIN_PATTERN_COUNT_FONT_SIZE :: 11.0
PATTERN_COUNT_FONT_RATIO :: 0.6
MIN_FLOOR_PENALTY_FONT_SIZE :: 10.0
FLOOR_PENALTY_FONT_RATIO :: 0.6
