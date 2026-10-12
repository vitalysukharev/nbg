package main

// Shared geometry keeps the browser build independent of raylib.
Sprite_Rect :: struct {
	x, y, width, height: f32,
}

Sprite_Kind :: enum {
	Tile,
	Factory,
	Player_Board,
	Table,
}

// Clay imageData points to one of these stable sprite descriptors.
UI_Sprite :: struct {
	kind:        Sprite_Kind,
	source:      Sprite_Rect,
	color_index: int,
	border:      i32,
}

// Pixel rectangles from assets/example-tiles.json, in wall palette order.
// The desktop preview loads a PNG copy; the browser can decode the WebP atlas.
@(rodata)
TILE_SPRITES := [WALL_DIMENSION]UI_Sprite {
	{kind = .Tile, source = {8, 8, 112, 112}, color_index = 0},
	{kind = .Tile, source = {136, 8, 112, 112}, color_index = 1},
	{kind = .Tile, source = {264, 8, 112, 112}, color_index = 2},
	{kind = .Tile, source = {392, 8, 112, 112}, color_index = 3},
	{kind = .Tile, source = {520, 8, 112, 112}, color_index = 4},
}

// Nine-slice backgrounds keep their edges rectangular at either orientation.
@(rodata)
FACTORY_SPRITE := UI_Sprite {
	kind = .Factory,
	source = {0, 0, 192, 128},
	border = 8,
}

@(rodata)
PLAYER_BOARD_SPRITE := UI_Sprite {
	kind = .Player_Board,
	source = {0, 0, 384, 256},
	border = 40,
}

@(rodata)
TABLE_SPRITE := UI_Sprite {
	kind = .Table,
	source = {0, 0, 512, 512},
}

@(rodata)
SPRITE_TEXTURE_PATHS := [Sprite_Kind]cstring {
	.Tile = "assets/example-tiles.png",
	.Factory = "assets/example-factory.png",
	.Player_Board = "assets/example-player-board.png",
	.Table = "assets/light-wood-table.png",
}
