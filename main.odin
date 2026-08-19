package main

import "base:runtime"
import "clay"
import "core:c"
import "core:fmt"
import rl "vendor:raylib"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

FactoriesLayoutOptions :: struct {
	x_count:          int,
	y_count:          int,
	factories_number: int,
}

get_factories_layout_options :: proc(width, height: f32) -> (flo: FactoriesLayoutOptions) {
	flo.factories_number = 6 // TODO: handle 3 and 4 players
	if width >= height {
		flo.x_count = 3
		flo.y_count = 2
	} else {
		flo.x_count = 2
		flo.y_count = 3
	}
	return
}

PlayerBoardLayoutOptions :: struct {
	wall_dimension:        int,
	pattern_line_max_size: int,
	floor_size:            int,
	areas_gap_in_tiles:    f32,
}

get_player_board_layout_options :: proc(width, height: f32) -> (plo: PlayerBoardLayoutOptions) {
	plo.wall_dimension = 5
	plo.floor_size = 7
	plo.pattern_line_max_size = 5 // TODO: minified layout
	plo.areas_gap_in_tiles = 0.5
	return
}

clay_error_handler :: proc "c" (error_data: clay.ErrorData) {
	context = runtime.default_context()
	fmt.eprintfln(
		"Clay error: %s (type: %v)",
		error_data.errorText.chars[:error_data.errorText.length],
		error_data.errorType,
	)
}

clay_color_to_rl_color :: proc(c: clay.Color) -> rl.Color {
	return rl.Color {
		u8(clamp(c[0], 0, 255)),
		u8(clamp(c[1], 0, 255)),
		u8(clamp(c[2], 0, 255)),
		u8(clamp(c[3], 0, 255)),
	}
}

render_clay_commands :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand)) {
	for i in 0 ..< render_commands.length {
		cmd := clay.RenderCommandArray_Get(render_commands, i)
		switch cmd.commandType {
		case .None:
		case .Rectangle:
			rect := cmd.renderData.rectangle
			color := clay_color_to_rl_color(rect.backgroundColor)
			if rect.cornerRadius.topLeft > 0 {
				roundness :=
					(rect.cornerRadius.topLeft * 2.0) /
					min(cmd.boundingBox.width, cmd.boundingBox.height)
				rl.DrawRectangleRounded(
					{
						cmd.boundingBox.x,
						cmd.boundingBox.y,
						cmd.boundingBox.width,
						cmd.boundingBox.height,
					},
					roundness,
					8,
					color,
				)
			} else {
				rl.DrawRectangleRec(
					{
						cmd.boundingBox.x,
						cmd.boundingBox.y,
						cmd.boundingBox.width,
						cmd.boundingBox.height,
					},
					color,
				)
			}
		case .Border:
			border := cmd.renderData.border
			color := clay_color_to_rl_color(border.color)
			bb := cmd.boundingBox
			if border.width.left > 0 {
				rl.DrawRectangleRec({bb.x, bb.y, f32(border.width.left), bb.height}, color)
			}
			if border.width.right > 0 {
				rl.DrawRectangleRec(
					{
						bb.x + bb.width - f32(border.width.right),
						bb.y,
						f32(border.width.right),
						bb.height,
					},
					color,
				)
			}
			if border.width.top > 0 {
				rl.DrawRectangleRec({bb.x, bb.y, bb.width, f32(border.width.top)}, color)
			}
			if border.width.bottom > 0 {
				rl.DrawRectangleRec(
					{
						bb.x,
						bb.y + bb.height - f32(border.width.bottom),
						bb.width,
						f32(border.width.bottom),
					},
					color,
				)
			}
		case .Text:
		case .Image:
		case .ScissorStart:
			rl.BeginScissorMode(
				i32(cmd.boundingBox.x),
				i32(cmd.boundingBox.y),
				i32(cmd.boundingBox.width),
				i32(cmd.boundingBox.height),
			)
		case .ScissorEnd:
			rl.EndScissorMode()
		case .OverlayColorStart, .OverlayColorEnd, .Custom:
		}
	}
}

get_tile_max_size :: proc(width, height: f32) -> f32 {
	flo := get_factories_layout_options(width, height)
	plo := get_player_board_layout_options(width, height)
	if width >= height {
		return min(
			width /
			(2 *
						(f32(plo.pattern_line_max_size + plo.wall_dimension) +
								2 * plo.areas_gap_in_tiles) +
					f32(flo.x_count)),
			height / f32(flo.factories_number * flo.y_count),
		)
	} else {
		return min(
			width / f32(flo.factories_number * flo.x_count),
			height /
			(2 * (f32(plo.wall_dimension) + 2 * plo.areas_gap_in_tiles + 1) + f32(flo.y_count)),
		)
	}
}

@(rodata)
WALL_COLORS := [5]clay.Color {
	{41, 128, 185, 255}, // Blue
	{243, 156, 18, 255}, // Yellow
	{231, 76, 60, 255}, // Red
	{44, 62, 80, 255}, // Black
	{207, 216, 220, 255}, // White / Light Slate
}

render_player_board :: proc(player_idx: u32, plo: PlayerBoardLayoutOptions, tile_size: f32) {
	clay.Begin(
		{
			id = clay.ID_LOCAL("PlayerBoard", player_idx),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {
					width = clay.SizingFixed(
						(f32(plo.pattern_line_max_size + plo.wall_dimension) +
							plo.areas_gap_in_tiles) *
						tile_size,
					),
					height = clay.SizingFixed(
						(f32(plo.wall_dimension) + plo.areas_gap_in_tiles + 1) * tile_size,
					),
				},
			},
			backgroundColor = {48, 42, 60, 255},
		},
	)
	defer clay.End()

	// Upper part: Board (Pattern lines) on left, Wall on right
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
		// 1. Board (Pattern Lines - 5 rows)
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
							backgroundColor = {68, 60, 82, 255},
							cornerRadius = clay.CornerRadiusAll(2),
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

		// 2. Wall (5x5 grid)
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
						cornerRadius = clay.CornerRadiusAll(2),
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
				backgroundColor = {75, 52, 64, 255},
				cornerRadius = clay.CornerRadiusAll(2),
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
			backgroundColor = {30, 136, 229, 255}, // Accent Blue
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
				backgroundColor = {45, 55, 72, 255},
				cornerRadius = clay.CornerRadiusAll(4),
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
						cornerRadius = clay.CornerRadiusAll(2),
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

	clay.BeginLayout()
	clay.Begin(
		{
			id = clay.ID("MainContainer"),
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .LeftToRight if is_horizontal else .TopToBottom,
			},
			backgroundColor = {18, 22, 30, 255},
		},
	)

	if is_horizontal {
		// 1. Left part: Player 1 (aligned right towards center)
		clay.Begin(
			{
				id = clay.ID_LOCAL("Player", u32(1)),
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .LeftToRight,
					childAlignment = {x = .Right, y = .Center},
				},
			},
		)
		render_player_board(1, plo, tile_size)
		clay.End()

		// Gap between Player 1 and factories
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

		// 2. Central part: Factories (vertical)
		render_factories(true, tile_size)

		// Gap between factories and Player 0
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

		// 3. Right part: Player 0 (aligned left towards center)
		clay.Begin(
			{
				id = clay.ID_LOCAL("Player", u32(0)),
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .LeftToRight,
					childAlignment = {x = .Left, y = .Center},
				},
			},
		)
		render_player_board(0, plo, tile_size)
		clay.End()
	} else {
		// 1. Upper part: Player 0 (aligned bottom towards center)
		clay.Begin(
			{
				id = clay.ID_LOCAL("Player", u32(0)),
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .LeftToRight,
					childAlignment = {x = .Center, y = .Bottom},
				},
			},
		)
		render_player_board(0, plo, tile_size)
		clay.End()

		// Gap between Player 0 and factories
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

		// 2. Central part: Factories (horizontal)
		render_factories(false, tile_size)

		// Gap between factories and Player 1
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

		// 3. Lower part: Player 1 (aligned top towards center)
		clay.Begin(
			{
				id = clay.ID_LOCAL("Player", u32(1)),
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					layoutDirection = .LeftToRight,
					childAlignment = {x = .Center, y = .Top},
				},
			},
		)
		render_player_board(1, plo, tile_size)
		clay.End()
	}

	clay.End()

	return clay.EndLayout(rl.GetFrameTime())
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Clay - Blue Rectangle")
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()

	// Initialize Clay
	min_memory_size := clay.MinMemorySize()
	memory := make([]u8, min_memory_size)
	defer delete(memory)

	arena := clay.CreateArenaWithCapacityAndMemory(cast(c.size_t)min_memory_size, raw_data(memory))
	clay.Initialize(
		arena,
		{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
		{handler = clay_error_handler},
	)

	for !rl.WindowShouldClose() {
		// Update Clay dimensions and inputs
		clay.SetLayoutDimensions({f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())})

		mouse_pos := rl.GetMousePosition()
		clay.SetPointerState({mouse_pos.x, mouse_pos.y}, rl.IsMouseButtonDown(.LEFT))

		clay.UpdateScrollContainers(
			false,
			{rl.GetMouseWheelMoveV().x, rl.GetMouseWheelMoveV().y},
			rl.GetFrameTime(),
		)

		render_commands := create_layout(f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		render_clay_commands(&render_commands)
		rl.EndDrawing()
	}
}
