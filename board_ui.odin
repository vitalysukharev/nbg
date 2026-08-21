package main
 
import "clay"

// Reusable spacing elements between layout containers
ui_gap_x :: proc(width: f32) {
	clay.Element(
		{
			layout = {
				sizing = {
					width = clay.SizingFixed(width),
					height = clay.SizingGrow(),
				},
			},
		},
	)
}

ui_gap_y :: proc(height: f32) {
	clay.Element(
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(height),
				},
			},
		},
	)
}

render_player_board :: proc(player_idx: u32, plo: PlayerBoardLayoutOptions, tile_size: f32) {
	board_w_units, board_h_units := get_player_board_dimensions(plo)
	board_w := board_w_units * tile_size
	board_h := board_h_units * tile_size

	clay.Begin(
		{
			id = clay.ID_LOCAL("PlayerBoard", player_idx),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {width = clay.SizingFixed(board_w), height = clay.SizingFixed(board_h)},
			},
			backgroundColor = COLOR_BG_PLAYER_BOARD,
		},
	)
	defer clay.End()

	// Upper part: Pattern Lines on left, Wall on right
	clay.Begin(
		{
			id = clay.ID_LOCAL("UpperArea"),
			layout = {
				layoutDirection = .LeftToRight,
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(f32(plo.wall_dimension) * tile_size),
				},
			},
		},
	)
	{
		// 1. Pattern Lines (Minified: 1 column of 5 tiles with count text; Regular: Triangle 1..5)
		if plo.is_minified {
			clay.Begin(
				{
					id = clay.ID_LOCAL("Board"),
					layout = {
						layoutDirection = .TopToBottom,
						sizing = {
							width = clay.SizingFixed(tile_size),
							height = clay.SizingGrow(),
						},
					},
				},
			)
			for row in 0 ..< plo.wall_dimension {
				clay.Begin(
					{
						id = clay.ID_LOCAL("MinRow", u32(row)),
						layout = {
							sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
							childAlignment = {x = .Center, y = .Center},
						},
						backgroundColor = COLOR_BG_PATTERN_SLOT,
						cornerRadius = CORNER_RADIUS_TILE,
					},
				)
				font_size := u16(max(tile_size * PATTERN_COUNT_FONT_RATIO, MIN_PATTERN_COUNT_FONT_SIZE))
				clay.Text(
					PATTERN_LINE_LABELS[row],
					{
						fontSize = font_size,
						textColor = COLOR_TEXT_PATTERN_COUNT,
					},
				)
				clay.End()
			}
			clay.End()
		} else {
			clay.Begin(
				{
					id = clay.ID_LOCAL("Board"),
					layout = {
						layoutDirection = .TopToBottom,
						sizing = {
							width = clay.SizingFixed(f32(plo.pattern_line_max_size) * tile_size),
							height = clay.SizingGrow(),
						},
					},
				},
			)
			for row in 0 ..< plo.pattern_line_max_size {
				clay.Begin(
					{
						id = clay.ID_LOCAL("Row", u32(row)),
						layout = {
							layoutDirection = .LeftToRight,
							sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
						},
					},
				)
				for col in 0 ..< plo.pattern_line_max_size {
					if col < (plo.pattern_line_max_size - 1) - row {
						// Empty spacer on the left
						clay.Element(
							{
								layout = {
									sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
								},
							},
						)
					} else {
						// Active pattern line slot
						clay.Element(
							{
								id = clay.ID_LOCAL("Col", u32(col)),
								layout = {
									sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
								},
								backgroundColor = COLOR_BG_PATTERN_SLOT,
								cornerRadius = CORNER_RADIUS_TILE,
							},
						)
					}
				}
				clay.End()
			}
			clay.End()
		}

		// Gap between pattern lines and wall
		clay.Element(
			{
				layout = {
					sizing = {
						width = clay.SizingFixed(plo.areas_gap_in_tiles * tile_size),
						height = clay.SizingGrow(),
					},
				},
			},
		)

		// 2. Wall (5x5 grid with cyclic diagonal colors)
		clay.Begin(
			{
				id = clay.ID_LOCAL("Wall"),
				layout = {
					layoutDirection = .TopToBottom,
					sizing = {
						width = clay.SizingFixed(f32(plo.wall_dimension) * tile_size),
						height = clay.SizingGrow(),
					},
				},
			},
		)
		for row in 0 ..< plo.wall_dimension {
			clay.Begin(
				{
					id = clay.ID_LOCAL("Row", u32(row)),
					layout = {
						layoutDirection = .LeftToRight,
						sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					},
				},
			)
			for col in 0 ..< plo.wall_dimension {
				color_idx := (col - row + plo.wall_dimension) % plo.wall_dimension
				clay.Element(
					{
						id = clay.ID_LOCAL("Col", u32(col)),
						layout = {
							sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
						},
						backgroundColor = WALL_COLORS[color_idx],
						cornerRadius = CORNER_RADIUS_TILE,
					},
				)
			}
			clay.End()
		}
		clay.End()
	}
	clay.End()

	// Gap between pattern lines and floor
	clay.Element(
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(plo.areas_gap_in_tiles * tile_size),
				},
			},
		},
	)

	// 3. Floor (7 penalty slots)
	clay.Begin(
		{
			id = clay.ID_LOCAL("Floor"),
			layout = {
				layoutDirection = .LeftToRight,
				sizing = {
					width = clay.SizingFixed(f32(plo.floor_size) * tile_size),
					height = clay.SizingFixed(tile_size),
				},
			},
		},
	)
	for col in 0 ..< plo.floor_size {
		clay.Element(
			{
				id = clay.ID_LOCAL("Col", u32(col)),
				layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()}},
				backgroundColor = COLOR_BG_FLOOR_SLOT,
				cornerRadius = CORNER_RADIUS_TILE,
			},
		)
	}
	clay.End()
}

render_factory_disc :: proc(disc_idx: int, flo: FactoriesLayoutOptions, tile_size: f32) {
	disc_w := f32(flo.tile_x_count) * tile_size
	disc_h := f32(flo.tile_y_count) * tile_size

	clay.Begin(
		{
			id = clay.ID_LOCAL("Factory", u32(disc_idx)),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {
					width = clay.SizingFixed(disc_w),
					height = clay.SizingFixed(disc_h),
				},
			},
			backgroundColor = COLOR_BG_FACTORY_DISC,
			cornerRadius = CORNER_RADIUS_FACTORY,
		},
	)
	defer clay.End()

	for row in 0 ..< flo.tile_y_count {
		clay.Begin(
			{
				id = clay.ID_LOCAL("Row", u32(row)),
				layout = {
					layoutDirection = .LeftToRight,
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				},
			},
		)
		for col in 0 ..< flo.tile_x_count {
			clay.Element(
				{
					id = clay.ID_LOCAL("Col", u32(col)),
					layout = {
						sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					},
					backgroundColor = {
						f32(40 + (disc_idx * 35) % 200),
						f32(60 + (row * 60) % 180),
						f32(80 + (col * 100) % 160),
						255,
					},
					cornerRadius = CORNER_RADIUS_TILE,
				},
			)
		}
		clay.End()
	}
}

render_factories :: proc(is_horizontal: bool, tile_size: f32, flo: FactoriesLayoutOptions) {
	factories_w_units, factories_h_units := get_factories_dimensions(flo)
	total_w := factories_w_units * tile_size
	total_h := factories_h_units * tile_size

	clay.Begin(
		{
			id = clay.ID("CenterPart"),
			layout = {
				layoutDirection = .LeftToRight if is_horizontal else .TopToBottom,
				sizing = {
					width = clay.SizingFixed(total_w) if is_horizontal else clay.SizingGrow(),
					height = clay.SizingGrow() if is_horizontal else clay.SizingFixed(total_h),
				},
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = COLOR_BG_FACTORY_AREA,
		},
	)
	defer clay.End()

	if is_horizontal {
		// Columns of factory discs
		for col in 0 ..< flo.disc_cols {
			clay.Begin(
				{
					id = clay.ID_LOCAL("DiscCol", u32(col)),
					layout = {
						layoutDirection = .TopToBottom,
						sizing = {
							width = clay.SizingFixed(f32(flo.tile_x_count) * tile_size),
							height = clay.SizingFixed(total_h),
						},
						childAlignment = {x = .Center, y = .Center},
					},
				},
			)
			for row in 0 ..< flo.disc_rows {
				disc_idx := col * flo.disc_rows + row
				render_factory_disc(disc_idx, flo, tile_size)
			}
			clay.End()
		}
	} else {
		// Rows of factory discs
		for row in 0 ..< flo.disc_rows {
			clay.Begin(
				{
					id = clay.ID_LOCAL("DiscRow", u32(row)),
					layout = {
						layoutDirection = .LeftToRight,
						sizing = {
							width = clay.SizingFixed(total_w),
							height = clay.SizingFixed(f32(flo.tile_y_count) * tile_size),
						},
						childAlignment = {x = .Center, y = .Center},
					},
				},
			)
			for col in 0 ..< flo.disc_cols {
				disc_idx := row * flo.disc_cols + col
				render_factory_disc(disc_idx, flo, tile_size)
			}
			clay.End()
		}
	}
}

create_layout :: proc(width, height, delta_time: f32, player_count: int) -> clay.ClayArray(clay.RenderCommand) {
	is_horizontal := width >= height
	tile_size := get_tile_max_size(width, height, player_count)
	flo := get_factories_layout_options(width, height, player_count)
	gap_size := AREAS_GAP_IN_TILES * tile_size

	clay.BeginLayout()
	clay.Begin(
		{
			id = clay.ID("MainContainer"),
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .LeftToRight if is_horizontal else .TopToBottom,
			},
			backgroundColor = COLOR_BG_APP,
		},
	)

	if is_horizontal {
		is_minified := is_horizontal_layout_minified(width, height, player_count)
		plo := get_player_board_layout_options(is_minified)

		// Left column: Opponent players (aligned right towards center factories)
		clay.Begin(
			{
				id = clay.ID("LeftPlayersContainer"),
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .TopToBottom,
					childAlignment = {x = .Right, y = .Center},
				},
			},
		)
		if player_count == 2 {
			render_player_board(1, plo, tile_size)
		} else {
			// 3 or 4 players: Player 1 (top) and Player 2 (bottom)
			render_player_board(1, plo, tile_size)
			ui_gap_y(gap_size)
			render_player_board(2, plo, tile_size)
		}
		clay.End()

		ui_gap_x(gap_size)

		// Central factories (2-column layout for 3p/4p, 1-column for 2p)
		render_factories(true, tile_size, flo)

		ui_gap_x(gap_size)

		// Right column: Player 0 and Player 3 (aligned left towards center factories)
		clay.Begin(
			{
				id = clay.ID("RightPlayersContainer"),
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .TopToBottom,
					childAlignment = {x = .Left, y = .Center},
				},
			},
		)
		if player_count == 4 {
			render_player_board(3, plo, tile_size)
			ui_gap_y(gap_size)
			render_player_board(0, plo, tile_size)
		} else {
			render_player_board(0, plo, tile_size)
		}
		clay.End()
	} else {
		plo_reg := get_player_board_layout_options(false)
		plo_min := get_player_board_layout_options(true)

		// Top container: Opponents (aligned bottom towards center factories)
		clay.Begin(
			{
				id = clay.ID("TopPlayersContainer"),
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .LeftToRight,
					childAlignment = {x = .Center, y = .Bottom},
				},
			},
		)
		if player_count == 2 {
			render_player_board(1, plo_reg, tile_size)
		} else {
			// 3 or 4 players: Player 1 (left) and Player 2 (right), minified
			render_player_board(1, plo_min, tile_size)
			ui_gap_x(gap_size)
			render_player_board(2, plo_min, tile_size)
		}
		clay.End()

		ui_gap_y(gap_size)

		// Central factories (2-row layout for 3p/4p, 1-row for 2p)
		render_factories(false, tile_size, flo)

		ui_gap_y(gap_size)

		// Bottom container: Player 0 and Player 3 (aligned top towards center factories)
		clay.Begin(
			{
				id = clay.ID("BottomPlayersContainer"),
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .LeftToRight,
					childAlignment = {x = .Center, y = .Top},
				},
			},
		)
		if player_count == 2 {
			render_player_board(0, plo_reg, tile_size)
		} else if player_count == 3 {
			// 3 players: Player 0 is full layout at bottom
			render_player_board(0, plo_reg, tile_size)
		} else {
			// 4 players: Player 3 (left) and Player 0 (right), minified
			render_player_board(3, plo_min, tile_size)
			ui_gap_x(gap_size)
			render_player_board(0, plo_min, tile_size)
		}
		clay.End()
	}

	clay.End()

	return clay.EndLayout(delta_time)
}
