package main

FactoriesLayoutOptions :: struct {
	x_count:          int,
	y_count:          int,
	factories_number: int,
}

PlayerBoardLayoutOptions :: struct {
	wall_dimension:        int,
	pattern_line_max_size: int,
	floor_size:            int,
	areas_gap_in_tiles:    f32,
}

get_factories_layout_options :: proc(width, height: f32) -> (flo: FactoriesLayoutOptions) {
	flo.factories_number = 6 // TODO: support 3 and 4 player counts
	if width >= height {
		flo.x_count = 3
		flo.y_count = 2
	} else {
		flo.x_count = 2
		flo.y_count = 3
	}
	return
}

get_player_board_layout_options :: proc(width, height: f32) -> (plo: PlayerBoardLayoutOptions) {
	plo.wall_dimension = 5
	plo.floor_size = 7
	plo.pattern_line_max_size = 5 // TODO: minified layout
	plo.areas_gap_in_tiles = 0.5
	return
}

get_tile_max_size :: proc(width, height: f32) -> f32 {
	flo := get_factories_layout_options(width, height)
	plo := get_player_board_layout_options(width, height)

	if width >= height {
		// Horizontal Layout: [Player 1] [Gap] [Factories Area] [Gap] [Player 0]
		board_tiles_w := f32(plo.pattern_line_max_size + plo.wall_dimension)
		total_gaps_w := 4 * plo.areas_gap_in_tiles
		factories_w := f32(flo.x_count)

		total_units_w := (2 * board_tiles_w) + total_gaps_w + factories_w
		total_units_h := f32(flo.factories_number * flo.y_count)

		return min(width / total_units_w, height / total_units_h)
	} else {
		// Vertical Layout: [Player 0] / [Gap] / [Factories Area] / [Gap] / [Player 1]
		board_tiles_h := f32(plo.wall_dimension) + 1 // Wall + Floor row
		total_gaps_h := 4 * plo.areas_gap_in_tiles
		factories_h := f32(flo.y_count)

		total_units_w := f32(flo.factories_number * flo.x_count)
		total_units_h := (2 * board_tiles_h) + total_gaps_h + factories_h

		return min(width / total_units_w, height / total_units_h)
	}
}
