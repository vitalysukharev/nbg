package main

import "clay"

// --- Window & Lifecycle Settings ---
WINDOW_TITLE :: "Clay - Board Game UI"
DEFAULT_WINDOW_WIDTH :: 800
DEFAULT_WINDOW_HEIGHT :: 600
TARGET_FPS :: 60

// --- Game Rules & Board Constraints ---
MIN_PLAYER_COUNT :: 2
MAX_PLAYER_COUNT :: 4
WALL_DIMENSION :: 5
FLOOR_SIZE :: 7
AREAS_GAP_IN_TILES :: 0.5

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
WALL_COLORS := [WALL_DIMENSION]clay.Color{
	{41, 128, 185, 255},  // Blue
	{243, 156, 18, 255},  // Yellow
	{231, 76, 60, 255},   // Red
	{44, 62, 80, 255},    // Black
	{207, 216, 220, 255}, // White / Light Slate
}

// Labels for pattern line capacities (1-indexed)
@(rodata)
PATTERN_LINE_LABELS := [WALL_DIMENSION]string{"1", "2", "3", "4", "5"}

// --- Geometry & Typography Metrics ---
CORNER_RADIUS_TILE :: clay.CornerRadius{2, 2, 2, 2}
CORNER_RADIUS_FACTORY :: clay.CornerRadius{4, 4, 4, 4}
CORNER_ROUND_SEGMENTS :: 8
DEFAULT_FONT_SIZE :: 10.0
MIN_PATTERN_COUNT_FONT_SIZE :: 8.0
PATTERN_COUNT_FONT_RATIO :: 0.45
