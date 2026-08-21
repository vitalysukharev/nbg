package main

FactoriesLayoutOptions :: struct {
	tile_x_count:     int,
	tile_y_count:     int,
	disc_cols:        int,
	disc_rows:        int,
	factories_number: int,
}

PlayerBoardLayoutOptions :: struct {
	wall_dimension:        int,
	pattern_line_max_size: int,
	floor_size:            int,
	areas_gap_in_tiles:    f32,
	is_minified:           bool,
}

get_player_board_dimensions :: proc(plo: PlayerBoardLayoutOptions) -> (width_in_tiles, height_in_tiles: f32) {
	upper_w := f32(plo.pattern_line_max_size + plo.wall_dimension) + plo.areas_gap_in_tiles
	width_in_tiles = max(upper_w, f32(plo.floor_size))
	height_in_tiles = f32(plo.wall_dimension) + plo.areas_gap_in_tiles + 1
	return
}

get_factories_dimensions :: proc(flo: FactoriesLayoutOptions) -> (width_in_tiles, height_in_tiles: f32) {
	width_in_tiles = f32(flo.disc_cols * flo.tile_x_count)
	height_in_tiles = f32(flo.disc_rows * flo.tile_y_count)
	return
}

get_factories_layout_options :: proc(width, height: f32, player_count: int) -> FactoriesLayoutOptions {
	factories_count := 2 * player_count + 2
	if width >= height {
		disc_cols := 2 if player_count >= 3 else 1
		return FactoriesLayoutOptions{
			tile_x_count     = 3,
			tile_y_count     = 2,
			disc_cols        = disc_cols,
			disc_rows        = factories_count / disc_cols,
			factories_number = factories_count,
		}
	} else {
		disc_rows := 2 if player_count >= 3 else 1
		return FactoriesLayoutOptions{
			tile_x_count     = 2,
			tile_y_count     = 3,
			disc_cols        = factories_count / disc_rows,
			disc_rows        = disc_rows,
			factories_number = factories_count,
		}
	}
}

get_player_board_layout_options :: proc(is_minified: bool) -> PlayerBoardLayoutOptions {
	return PlayerBoardLayoutOptions{
		wall_dimension        = WALL_DIMENSION,
		floor_size            = FLOOR_SIZE,
		areas_gap_in_tiles    = AREAS_GAP_IN_TILES,
		is_minified           = is_minified,
		pattern_line_max_size = 1 if is_minified else WALL_DIMENSION,
	}
}

is_horizontal_layout_minified :: proc(width, height: f32, player_count: int) -> bool {
	flo := get_factories_layout_options(width, height, player_count)
	plo_reg := get_player_board_layout_options(false)

	board_w, board_h := get_player_board_dimensions(plo_reg)
	factories_w, factories_h := get_factories_dimensions(flo)

	total_units_w_reg := (2 * board_w) + (2 * plo_reg.areas_gap_in_tiles) + factories_w
	players_col_h := f32(2) * board_h + plo_reg.areas_gap_in_tiles if player_count >= 3 else board_h
	total_units_h := max(factories_h, players_col_h)

	// If width does not allow regular layout without shrinking below the height-constrained max tile size
	return width / total_units_w_reg < height / total_units_h
}

get_tile_max_size :: proc(width, height: f32, player_count: int) -> f32 {
	flo := get_factories_layout_options(width, height, player_count)
	plo_reg := get_player_board_layout_options(false)
	plo_min := get_player_board_layout_options(true)

	reg_board_w, board_h := get_player_board_dimensions(plo_reg)
	min_board_w, _ := get_player_board_dimensions(plo_min)
	factories_w, factories_h := get_factories_dimensions(flo)
	gap := plo_reg.areas_gap_in_tiles

	if width >= height {
		// Horizontal Layout: [Left Opponents] [Gap] [Factories Column] [Gap] [Right Players]
		is_minified := is_horizontal_layout_minified(width, height, player_count)
		board_w := min_board_w if is_minified else reg_board_w

		total_units_w := (2 * board_w) + (2 * gap) + factories_w
		players_col_h := f32(2) * board_h + gap if player_count >= 3 else board_h
		total_units_h := max(factories_h, players_col_h)

		return min(width / total_units_w, height / total_units_h)
	} else {
		// Vertical Layout: [Top Opponents] / [Gap] / [Factories Row] / [Gap] / [Bottom Players]
		top_w, bottom_w: f32

		switch player_count {
		case 2:
			top_w = reg_board_w
			bottom_w = reg_board_w
		case 3:
			top_w = (2 * min_board_w) + gap
			bottom_w = reg_board_w
		case 4:
			top_w = (2 * min_board_w) + gap
			bottom_w = (2 * min_board_w) + gap
		case:
			top_w = reg_board_w
			bottom_w = reg_board_w
		}

		total_units_w := max(factories_w, top_w, bottom_w)
		total_units_h := (2 * board_h) + (2 * gap) + factories_h

		return min(width / total_units_w, height / total_units_h)
	}
}
