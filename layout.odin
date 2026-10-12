package main

Factory_Layout :: struct {
	tile_cols: int,
	tile_rows: int,
	disc_cols: int,
	disc_rows: int,
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

// A row or column has one fewer gap than items.
get_line_extent :: proc(count: int, item_size, gap: f32) -> f32 {
	return f32(count) * item_size + f32(count - 1) * gap
}

get_player_board_dimensions :: proc(
	board: Player_Board_Mode,
) -> (
	width_in_tiles, height_in_tiles: f32,
) {
	pattern_width := 1 if board == .Compact else WALL_DIMENSION
	upper_w := f32(pattern_width + WALL_DIMENSION) + AREAS_GAP_IN_TILES
	width_in_tiles = max(upper_w, FLOOR_SIZE)
	height_in_tiles = WALL_DIMENSION + AREAS_GAP_IN_TILES +
		1 + FLOOR_LABEL_GAP_IN_TILES + FLOOR_LABEL_HEIGHT_IN_TILES
	width_in_tiles += 2 * PLAYER_BOARD_PADDING_IN_TILES
	height_in_tiles += 2 * PLAYER_BOARD_PADDING_IN_TILES
	return
}

get_factory_layout :: proc(is_horizontal: bool, player_count: int) -> Factory_Layout {
	factory_count := 2 * player_count + 2
	disc_cols := 2 if player_count >= 3 else 1
	result := Factory_Layout {
		tile_cols = 3,
		tile_rows = 2,
		disc_cols = disc_cols,
		disc_rows = factory_count / disc_cols,
	}
	// Portrait uses the transpose of the landscape grid.
	if !is_horizontal {
		result.tile_cols, result.tile_rows = result.tile_rows, result.tile_cols
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
	padding := f32(2 * FACTORY_PADDING_IN_TILES)
	width =
		(get_line_extent(factories.tile_cols, 1, FACTORY_TILE_GAP_IN_TILES) + padding) * tile_size
	height =
		(get_line_extent(factories.tile_rows, 1, FACTORY_TILE_GAP_IN_TILES) + padding) * tile_size
	return
}

get_factories_dimensions :: proc(
	factories: Factory_Layout,
	tile_size: f32 = 1,
) -> (
	width, height: f32,
) {
	disc_w, disc_h := get_factory_disc_dimensions(factories, tile_size)
	gap := FACTORY_GAP_IN_TILES * tile_size
	width = get_line_extent(factories.disc_cols, disc_w, gap)
	height = get_line_extent(factories.disc_rows, disc_h, gap)
	return
}

get_board_layout_dimensions :: proc(
	layout: Board_Layout,
) -> (
	width_in_tiles, height_in_tiles: f32,
) {
	opponent_w, opponent_h := get_player_board_dimensions(layout.opponent_board)
	local_w, local_h := get_player_board_dimensions(layout.local_board)
	factory_w, factory_h := get_factories_dimensions(layout.factories)
	opponent_count := min(layout.player_count - 1, 2)
	local_count := layout.player_count - opponent_count
	gap := f32(AREAS_GAP_IN_TILES)

	if layout.is_horizontal {
		width_in_tiles = opponent_w + local_w + factory_w + 2 * gap
		opponent_h = get_line_extent(opponent_count, opponent_h, gap)
		local_h = get_line_extent(local_count, local_h, gap)
		height_in_tiles = max(opponent_h, local_h, factory_h)
	} else {
		opponent_w = get_line_extent(opponent_count, opponent_w, gap)
		local_w = get_line_extent(local_count, local_w, gap)
		width_in_tiles = max(opponent_w, local_w, factory_w)
		height_in_tiles = opponent_h + local_h + factory_h + 2 * gap
	}
	return
}

calculate_board_layout :: proc(
	viewport_width, viewport_height: f32,
	player_count: int,
) -> Board_Layout {
	assert(player_count >= MIN_PLAYER_COUNT && player_count <= MAX_PLAYER_COUNT)
	width, height := max(viewport_width, 0), max(viewport_height, 0)
	is_horizontal := width >= height
	result := Board_Layout {
		player_count   = player_count,
		is_horizontal  = is_horizontal,
		factories      = get_factory_layout(is_horizontal, player_count),
		opponent_board = .Regular,
		local_board    = .Regular,
	}

	if result.is_horizontal {
		board_w, board_h := get_board_layout_dimensions(result)
		if width / board_w < height / board_h {
			result.opponent_board = .Compact
			result.local_board = .Compact
		}
	} else {
		if player_count >= 3 {
			result.opponent_board = .Compact
		}
		if player_count == 4 {
			result.local_board = .Compact
		}
	}
	board_w, board_h := get_board_layout_dimensions(result)
	result.tile_size = max(0, min(width / board_w, height / board_h))
	return result
}
