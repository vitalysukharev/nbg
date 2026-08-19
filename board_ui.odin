package main

import "clay"
import rl "vendor:raylib"

// Reusable spacing element between layout containers
ui_gap :: proc(size: f32, is_horizontal: bool) {
	clay.Element(
		{
			layout = {
				sizing = {
					width = clay.SizingFixed(size) if is_horizontal else clay.SizingGrow(),
					height = clay.SizingGrow() if is_horizontal else clay.SizingFixed(size),
				},
			},
		},
	)
}

// Reusable player container slot with custom alignment
render_player_slot :: proc(
	player_idx: u32,
	alignment: clay.ChildAlignment,
	plo: PlayerBoardLayoutOptions,
	tile_size: f32,
) {
	clay.Begin(
		{
			id = clay.ID_LOCAL("Player", player_idx),
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .LeftToRight,
				childAlignment = alignment,
			},
		},
	)
	render_player_board(player_idx, plo, tile_size)
	clay.End()
}

render_player_board :: proc(player_idx: u32, plo: PlayerBoardLayoutOptions, tile_size: f32) {
	board_w :=
		(f32(plo.pattern_line_max_size + plo.wall_dimension) + plo.areas_gap_in_tiles) * tile_size
	board_h := (f32(plo.wall_dimension) + plo.areas_gap_in_tiles + 1) * tile_size

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
		// 1. Pattern Lines (Triangle 1..5)
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

render_factories :: proc(is_horizontal: bool, tile_size: f32) {
	num_rows := 2 if is_horizontal else 3
	num_cols := 3 if is_horizontal else 2

	clay.Begin(
		{
			id = clay.ID("CenterPart"),
			layout = {
				layoutDirection = .TopToBottom if is_horizontal else .LeftToRight,
				sizing = {
					width = clay.SizingFixed(3 * tile_size) if is_horizontal else clay.SizingGrow(),
					height = clay.SizingGrow() if is_horizontal else clay.SizingFixed(3 * tile_size),
				},
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = COLOR_BG_FACTORY_AREA,
		},
	)
	defer clay.End()

	for i in 0 ..< 6 {
		clay.Begin(
			{
				id = clay.ID_LOCAL("Factory", u32(i)),
				layout = {
					layoutDirection = .TopToBottom,
					sizing = {
						width = clay.SizingGrow() if is_horizontal else clay.SizingFixed(2 * tile_size),
						height = clay.SizingFixed(2 * tile_size) if is_horizontal else clay.SizingGrow(),
					},
				},
				backgroundColor = COLOR_BG_FACTORY_DISC,
				cornerRadius = CORNER_RADIUS_FACTORY,
			},
		)
		for row in 0 ..< num_rows {
			clay.Begin(
				{
					id = clay.ID_LOCAL("Row", u32(row)),
					layout = {
						layoutDirection = .LeftToRight,
						sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					},
				},
			)
			for col in 0 ..< num_cols {
				clay.Element(
					{
						id = clay.ID_LOCAL("Col", u32(col)),
						layout = {
							sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
						},
						backgroundColor = {
							f32(40 + (i * 35) % 200),
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
		clay.End()
	}
}

create_layout :: proc(width, height: f32) -> clay.ClayArray(clay.RenderCommand) {
	is_horizontal := width >= height
	tile_size := get_tile_max_size(width, height)
	plo := get_player_board_layout_options(width, height)
	gap_size := plo.areas_gap_in_tiles * tile_size

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
		// Player 1 (aligned right towards center)
		render_player_slot(1, {x = .Right, y = .Center}, plo, tile_size)
		ui_gap(gap_size, is_horizontal)

		// Central factories (vertical layout)
		render_factories(true, tile_size)
		ui_gap(gap_size, is_horizontal)

		// Player 0 (aligned left towards center)
		render_player_slot(0, {x = .Left, y = .Center}, plo, tile_size)
	} else {
		// Player 0 (aligned bottom towards center)
		render_player_slot(0, {x = .Center, y = .Bottom}, plo, tile_size)
		ui_gap(gap_size, is_horizontal)

		// Central factories (horizontal layout)
		render_factories(false, tile_size)
		ui_gap(gap_size, is_horizontal)

		// Player 1 (aligned top towards center)
		render_player_slot(1, {x = .Center, y = .Top}, plo, tile_size)
	}

	clay.End()

	return clay.EndLayout(rl.GetFrameTime())
}
