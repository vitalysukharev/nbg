package main

Factory_Layout :: struct {
	tile_x_count: int,
	tile_y_count: int,
	disc_cols:    int,
	disc_rows:    int,
}

Player_Board_Mode :: enum {
	Regular,
	Compact,
}

// Layout choices shared by sizing and UI construction.
Board_Layout :: struct {
	player_count:   int,
	is_horizontal:  bool,
	tile_size:      f32,
	factories:      Factory_Layout,
	opponent_board: Player_Board_Mode,
	local_board:    Player_Board_Mode,
}

get_player_board_dimensions :: proc(
	board: Player_Board_Mode,
) -> (
	width_in_tiles, height_in_tiles: f32,
) {
	pattern_width := 1 if board == .Compact else WALL_DIMENSION
	upper_w := f32(pattern_width + WALL_DIMENSION) + AREAS_GAP_IN_TILES
	width_in_tiles = max(upper_w, FLOOR_SIZE)
	height_in_tiles = WALL_DIMENSION + AREAS_GAP_IN_TILES + 1
	return
}

get_factory_layout :: proc(
	is_horizontal: bool,
	player_count: int,
) -> Factory_Layout {
	factory_count := 2 * player_count + 2
	disc_cols := 2 if player_count >= 3 else 1
	result := Factory_Layout {
		tile_x_count = 3,
		tile_y_count = 2,
		disc_cols    = disc_cols,
		disc_rows    = factory_count / disc_cols,
	}
	// Portrait uses the transpose of the landscape grid.
	if !is_horizontal {
		result.tile_x_count, result.tile_y_count = result.tile_y_count, result.tile_x_count
		result.disc_cols, result.disc_rows = result.disc_rows, result.disc_cols
	}
	return result
}

// Dimensions are in tiles by default; pass a tile size to obtain pixels.
get_factory_disc_dimensions :: proc(
	factories: Factory_Layout,
	tile_size: f32 = 1,
) -> (
	width, height: f32,
) {
	width =
		(f32(factories.tile_x_count) + 2 * FACTORY_PADDING_IN_TILES +
		f32(factories.tile_x_count - 1) * FACTORY_TILE_GAP_IN_TILES) * tile_size
	height =
		(f32(factories.tile_y_count) + 2 * FACTORY_PADDING_IN_TILES +
		f32(factories.tile_y_count - 1) * FACTORY_TILE_GAP_IN_TILES) * tile_size
	return
}

get_factories_dimensions :: proc(
	factories: Factory_Layout,
	tile_size: f32 = 1,
) -> (
	width, height: f32,
) {
	disc_w, disc_h := get_factory_disc_dimensions(factories, tile_size)
	width = f32(factories.disc_cols) * disc_w + f32(factories.disc_cols - 1) * FACTORY_GAP_IN_TILES * tile_size
	height = f32(factories.disc_rows) * disc_h + f32(factories.disc_rows - 1) * FACTORY_GAP_IN_TILES * tile_size
	return
}

calculate_board_layout :: proc(viewport_width, viewport_height: f32, player_count: int) -> Board_Layout {
	assert(player_count >= MIN_PLAYER_COUNT && player_count <= MAX_PLAYER_COUNT)
	width, height := max(viewport_width, 0), max(viewport_height, 0)
	is_horizontal := width >= height
	factories := get_factory_layout(is_horizontal, player_count)
	board_w, board_h := get_player_board_dimensions(.Regular)
	compact_w, _ := get_player_board_dimensions(.Compact)
	factory_units_w, factory_units_h := get_factories_dimensions(factories)
	gap := f32(AREAS_GAP_IN_TILES)
	result := Board_Layout {
		player_count   = player_count,
		is_horizontal  = is_horizontal,
		factories      = factories,
		opponent_board = .Regular,
		local_board    = .Regular,
	}

	width_limit, height_limit: f32
	if result.is_horizontal {
		players_h := 2 * board_h + gap if player_count >= 3 else board_h
		height_limit = height / max(players_h, factory_units_h)
		width_limit = width / (2 * board_w + 2 * gap + factory_units_w)
		if width_limit < height_limit {
			result.opponent_board = .Compact
			result.local_board = .Compact
			width_limit = width / (2 * compact_w + 2 * gap + factory_units_w)
		}
	} else {
		players_w := board_w
		if player_count >= 3 {
			result.opponent_board = .Compact
			players_w = max(board_w, 2 * compact_w + gap)
		}
		if player_count == 4 {
			result.local_board = .Compact
		}
		width_limit = width / max(players_w, factory_units_w)
		height_limit = height / (2 * board_h + 2 * gap + factory_units_h)
	}
	result.tile_size = max(0, min(width_limit, height_limit))
	return result
}
