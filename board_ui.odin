package main

import "clay"

// Keep gaps in floating-point pixels, matching the layout calculations.
ui_gap :: proc(size: f32, direction: clay.LayoutDirection) {
	clay.Element(
		{
			layout = {
				sizing = {
					width = clay.SizingFixed(size) if direction == .LeftToRight else clay.SizingGrow(),
					height = clay.SizingFixed(size) if direction == .TopToBottom else clay.SizingGrow(),
				},
			},
		},
	)
}

render_player_board :: proc(player_idx: u32, board: Player_Board_Mode, tile_size: f32) {
	board_w_units, board_h_units := get_player_board_dimensions(board)
	board_w := board_w_units * tile_size
	board_h := board_h_units * tile_size
	padding := PLAYER_BOARD_PADDING_IN_TILES * tile_size

	// Player identity stays stable when its group or orientation changes.
	clay.Begin(
		{
			id = clay.ID("PlayerBoard", player_idx),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {width = clay.SizingFixed(board_w), height = clay.SizingFixed(board_h)},
				childAlignment = {x = .Center, y = .Center},
			},
			image = {imageData = rawptr(&PLAYER_BOARD_SPRITE)},
		},
	)
	defer clay.End()

	// Fixed-size content preserves floating-point padding on every side.
	clay.Begin(
		{
			id = clay.ID("PlayerBoardContent", player_idx),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {
					width = clay.SizingFixed(board_w - 2 * padding),
					height = clay.SizingFixed(board_h - 2 * padding),
				},
			},
		},
	)
	defer clay.End()

	// Pattern lines and wall share the upper area above the floor.
	{
		clay.Begin(
			{
				id = clay.ID_LOCAL("UpperArea"),
				layout = {
					layoutDirection = .LeftToRight,
					sizing = {
						width = clay.SizingGrow(),
						height = clay.SizingFixed(f32(WALL_DIMENSION) * tile_size),
					},
				},
			},
		)
		defer clay.End()

		render_pattern_lines(board, tile_size)
		ui_gap(AREAS_GAP_IN_TILES * tile_size, .LeftToRight)
		render_wall(tile_size)
	}

	ui_gap(AREAS_GAP_IN_TILES * tile_size, .TopToBottom)

	render_floor(tile_size)
}

render_pattern_lines :: proc(board: Player_Board_Mode, tile_size: f32) {
	column_count := 1 if board == .Compact else WALL_DIMENSION
	clay.Begin(
		{
			id = clay.ID_LOCAL("Board"),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {
					width = clay.SizingFixed(f32(column_count) * tile_size),
					height = clay.SizingGrow(),
				},
			},
		},
	)
	defer clay.End()

	for row in 0 ..< WALL_DIMENSION {
		if board == .Compact {
			render_compact_pattern_line(row, tile_size)
		} else {
			render_regular_pattern_line(row, tile_size)
		}
	}
}

render_compact_pattern_line :: proc(row: int, tile_size: f32) {
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
	defer clay.End()

	font_size := u16(max(tile_size * PATTERN_COUNT_FONT_RATIO, MIN_PATTERN_COUNT_FONT_SIZE))
	clay.Text(
		PATTERN_LINE_LABELS[row],
		{fontSize = font_size, textColor = COLOR_TEXT_PATTERN_COUNT},
	)
}

render_regular_pattern_line :: proc(row: int, tile_size: f32) {
	clay.Begin(
		{
			id = clay.ID_LOCAL("Row", u32(row)),
			layout = {
				layoutDirection = .LeftToRight,
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			},
		},
	)
	defer clay.End()

	first_col := WALL_DIMENSION - 1 - row
	if first_col > 0 {
		ui_gap(f32(first_col) * tile_size, .LeftToRight)
	}
	for col in first_col ..< WALL_DIMENSION {
		render_board_slot(col, COLOR_BG_PATTERN_SLOT)
	}
}

render_board_slot :: proc(col: int, color: clay.Color, sprite: ^UI_Sprite = nil) {
	clay.Element(
		{
			id = clay.ID_LOCAL("Col", u32(col)),
			layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()}},
			backgroundColor = color if sprite == nil else clay.Color{},
			cornerRadius = CORNER_RADIUS_TILE,
			image = {imageData = rawptr(sprite)},
		},
	)
}

render_wall :: proc(tile_size: f32) {
	// Wall rows follow the cyclic diagonal color pattern.
	clay.Begin(
		{
			id = clay.ID_LOCAL("Wall"),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {
					width = clay.SizingFixed(f32(WALL_DIMENSION) * tile_size),
					height = clay.SizingGrow(),
				},
			},
		},
	)
	defer clay.End()

	for row in 0 ..< WALL_DIMENSION {
		clay.Begin(
			{
				id = clay.ID_LOCAL("Row", u32(row)),
				layout = {
					layoutDirection = .LeftToRight,
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				},
			},
		)
		defer clay.End()

		for col in 0 ..< WALL_DIMENSION {
			color_idx := (col - row + WALL_DIMENSION) % WALL_DIMENSION
			render_board_slot(col, WALL_COLORS[color_idx], &TILE_SPRITES[color_idx])
		}
	}
}

render_floor :: proc(tile_size: f32) {
	label_height := FLOOR_LABEL_HEIGHT_IN_TILES * tile_size
	label_gap := FLOOR_LABEL_GAP_IN_TILES * tile_size
	clay.Begin(
		{
			id = clay.ID_LOCAL("Floor"),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {
					width = clay.SizingFixed(f32(FLOOR_SIZE) * tile_size),
					height = clay.SizingFixed(tile_size + label_gap + label_height),
				},
			},
		},
	)
	defer clay.End()

	{
		clay.Begin(
			{
				id = clay.ID_LOCAL("FloorSlots"),
				layout = {
					layoutDirection = .LeftToRight,
					sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(tile_size)},
				},
			},
		)
		defer clay.End()
		for col in 0 ..< FLOOR_SIZE {
			render_board_slot(col, COLOR_BG_FLOOR_SLOT)
		}
	}
	ui_gap(label_gap, .TopToBottom)
	clay.Begin(
		{
			id = clay.ID_LOCAL("FloorPenalties"),
			layout = {
				layoutDirection = .LeftToRight,
				sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(label_height)},
			},
		},
	)
	defer clay.End()
	font_size := u16(max(tile_size * FLOOR_PENALTY_FONT_RATIO, MIN_FLOOR_PENALTY_FONT_SIZE))
	for label, col in FLOOR_PENALTY_LABELS {
		clay.Begin(
			{
				id = clay.ID_LOCAL("Penalty", u32(col)),
				layout = {
					sizing = {width = clay.SizingFixed(tile_size), height = clay.SizingGrow()},
					childAlignment = {x = .Center, y = .Center},
				},
			},
		)
		defer clay.End()
		clay.Text(label, {fontSize = font_size, textColor = COLOR_TEXT_FLOOR_PENALTY})
	}
}

render_factory_disc :: proc(disc_idx: int, factories: Factory_Layout, tile_size: f32) {
	disc_w, disc_h := get_factory_disc_dimensions(factories, tile_size)
	clay.Begin(
		{
			id = clay.ID("Factory", u32(disc_idx)),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {width = clay.SizingFixed(disc_w), height = clay.SizingFixed(disc_h)},
				childAlignment = {x = .Center, y = .Center},
			},
			cornerRadius = CORNER_RADIUS_FACTORY,
			image = {imageData = rawptr(&FACTORY_SPRITE)},
		},
	)
	defer clay.End()

	for row in 0 ..< factories.tile_rows {
		if row > 0 {
			ui_gap(FACTORY_TILE_GAP_IN_TILES * tile_size, .TopToBottom)
		}
		clay.Begin(
			{
				id = clay.ID_LOCAL("Row", u32(row)),
				layout = {
					layoutDirection = .LeftToRight,
					sizing = {
						width = clay.SizingFixed(
							disc_w - 2 * FACTORY_PADDING_IN_TILES * tile_size,
						),
						height = clay.SizingFixed(tile_size),
					},
				},
			},
		)
		defer clay.End()

		for col in 0 ..< factories.tile_cols {
			if col > 0 {
				ui_gap(FACTORY_TILE_GAP_IN_TILES * tile_size, .LeftToRight)
			}
			tile_idx := (disc_idx * factories.tile_rows + row) * factories.tile_cols + col
			color_idx := tile_idx % WALL_DIMENSION
			clay.Element(
				{
					id = clay.ID("FactoryTile", u32(tile_idx)),
					layout = {
						sizing = {
							width = clay.SizingFixed(tile_size),
							height = clay.SizingFixed(tile_size),
						},
					},
					cornerRadius = CORNER_RADIUS_TILE,
					image = {imageData = rawptr(&TILE_SPRITES[color_idx])},
				},
			)
		}
	}
}

render_factories :: proc(is_horizontal: bool, tile_size: f32, factories: Factory_Layout) {
	total_w, total_h := get_factories_dimensions(factories, tile_size)
	outer_direction: clay.LayoutDirection = .LeftToRight if is_horizontal else .TopToBottom
	inner_direction: clay.LayoutDirection = .TopToBottom if is_horizontal else .LeftToRight
	line_count := factories.disc_cols if is_horizontal else factories.disc_rows
	line_length := factories.disc_rows if is_horizontal else factories.disc_cols
	line_id := "DiscCol" if is_horizontal else "DiscRow"
	gap := FACTORY_GAP_IN_TILES * tile_size

	clay.Begin(
		{
			id = clay.ID("CenterPart"),
			layout = {
				layoutDirection = outer_direction,
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

	for line in 0 ..< line_count {
		if line > 0 {
			ui_gap(gap, outer_direction)
		}
		clay.Begin(
			{
				id = clay.ID_LOCAL(line_id, u32(line)),
				layout = {
					layoutDirection = inner_direction,
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					childAlignment = {x = .Center, y = .Center},
				},
			},
		)
		defer clay.End()

		for cell in 0 ..< line_length {
			if cell > 0 {
				ui_gap(gap, inner_direction)
			}
			render_factory_cell(line * line_length + cell, factories, tile_size)
		}
	}
}

// Equal growing cells distribute the discs across the available central area.
render_factory_cell :: proc(disc_idx: int, factories: Factory_Layout, tile_size: f32) {
	clay.Begin(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				childAlignment = {x = .Center, y = .Center},
			},
		},
	)
	defer clay.End()

	render_factory_disc(disc_idx, factories, tile_size)
}

render_player_group :: proc(
	id: string,
	players: []u32,
	board: Player_Board_Mode,
	tile_size: f32,
	direction: clay.LayoutDirection,
	alignment: clay.ChildAlignment,
) {
	clay.Begin(
		{
			id = clay.ID(id),
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = direction,
				childAlignment = alignment,
			},
		},
	)
	defer clay.End()

	for player, i in players {
		if i > 0 {
			ui_gap(AREAS_GAP_IN_TILES * tile_size, direction)
		}
		render_player_board(player, board, tile_size)
	}
}

// The returned commands borrow Clay's arena and must be consumed before the next layout.
create_layout :: proc(layout: Board_Layout, delta_time: f32) -> []clay.RenderCommand {
	is_horizontal := layout.is_horizontal
	tile_size := layout.tile_size
	gap_size := AREAS_GAP_IN_TILES * tile_size
	outer_direction: clay.LayoutDirection = .LeftToRight if is_horizontal else .TopToBottom
	player_direction: clay.LayoutDirection = .TopToBottom if is_horizontal else .LeftToRight

	// Player order is the same in either orientation: [1, 2] / factories / [3, 0].
	opponents := [2]u32{1, 2}
	local_players := [2]u32{3, 0}
	opponent_count := min(layout.player_count - 1, 2)
	local_start := 0 if layout.player_count == MAX_PLAYER_COUNT else 1
	opponent_alignment: clay.ChildAlignment = {
		x = .Center,
		y = .Bottom,
	}
	local_alignment: clay.ChildAlignment = {
		x = .Center,
		y = .Top,
	}
	if is_horizontal {
		opponent_alignment = {
			x = .Right,
			y = .Center,
		}
		local_alignment = {
			x = .Left,
			y = .Center,
		}
	}

	clay.BeginLayout()
	{
		clay.Begin(
			{
				id = clay.ID("MainContainer"),
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = outer_direction,
				},
				image = {imageData = rawptr(&TABLE_SPRITE)},
			},
		)
		defer clay.End()

		render_player_group(
			"LeftPlayersContainer" if is_horizontal else "TopPlayersContainer",
			opponents[:opponent_count],
			layout.opponent_board,
			tile_size,
			player_direction,
			opponent_alignment,
		)
		ui_gap(gap_size, outer_direction)
		render_factories(is_horizontal, tile_size, layout.factories)
		ui_gap(gap_size, outer_direction)
		render_player_group(
			"RightPlayersContainer" if is_horizontal else "BottomPlayersContainer",
			local_players[local_start:],
			layout.local_board,
			tile_size,
			player_direction,
			local_alignment,
		)
	}

	return clay.ToSlice(clay.EndLayout(delta_time))
}
