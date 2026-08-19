package main

import "clay"

// --- Window & Lifecycle Settings ---
DEFAULT_WINDOW_WIDTH :: 800
DEFAULT_WINDOW_HEIGHT :: 600
TARGET_FPS :: 60

// --- Theme Colors ---
COLOR_BG_APP :: clay.Color{18, 22, 30, 255} // Main application background
COLOR_BG_PLAYER_BOARD :: clay.Color{48, 42, 60, 255} // Player board background
COLOR_BG_PATTERN_SLOT :: clay.Color{68, 60, 82, 255} // Pattern line empty slot
COLOR_BG_FLOOR_SLOT :: clay.Color{75, 52, 64, 255} // Penalty floor line slot
COLOR_BG_FACTORY_AREA :: clay.Color{30, 136, 229, 255} // Factory container accent
COLOR_BG_FACTORY_DISC :: clay.Color{45, 55, 72, 255} // Individual factory disc

// Wall Colors (Azul 5-tile standard cycle)
@(rodata)
WALL_COLORS := [5]clay.Color {
	{41, 128, 185, 255}, // Blue
	{243, 156, 18, 255}, // Yellow
	{231, 76, 60, 255}, // Red
	{44, 62, 80, 255}, // Black
	{207, 216, 220, 255}, // White / Light Slate
}

// --- Corner Radii ---
CORNER_RADIUS_NONE :: clay.CornerRadius{0, 0, 0, 0}
CORNER_RADIUS_TILE :: clay.CornerRadius{2, 2, 2, 2}
CORNER_RADIUS_FACTORY :: clay.CornerRadius{4, 4, 4, 4}
