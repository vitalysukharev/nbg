package main

import "base:runtime"
import "clay"
import "core:c"
import "core:fmt"
import rl "vendor:raylib"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

@(rodata)
FACTORY_ELEMENT_LABELS := [?]string {
	"Factory0",
	"Factory1",
	"Factory2",
	"Factory3",
	"Factory4",
	"Factory5",
	"Factory6",
	"Factory7",
	"Factory8",
	"Factory9",
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

tile_max_size :: proc(width, height: f32) -> f32 {
	// hardcoding for 2 players and vertical layout for now
	return min(width / (2 * 2 + 2) / 2, height / 20)
}

create_layout :: proc(width, height: f32) -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()
	clay.Begin(
		{
			id = clay.ID("MainContainer"),
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .TopToBottom,
				//childGap = 8,
				//padding = clay.PaddingAll(8),
			},
			backgroundColor = {18, 22, 30, 255},
		},
	)
	// 1. Upper part (equal growing height)
	clay.Element(
		{
			id = clay.ID("TopPart"),
			layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()}},
			backgroundColor = {41, 98, 255, 255}, // Blue
		},
	)
	// 2. Central part (fixed height)
	tile_size := tile_max_size(width, height)
	clay.Begin(
		{
			id = clay.ID("CenterPart"),
			layout = {
				layoutDirection = .LeftToRight,
				sizing = {
					width  = clay.SizingGrow(),
					height = clay.SizingFixed(3 * tile_size), // Fixed height -> 3x tile height
				},
				childAlignment = {x = .Center, y = .Center},
				//childGap = 12,
				//padding = clay.PaddingAll(4),
			},
			backgroundColor = {30, 136, 229, 255}, // Accent Blue
		},
	)

	for i in 0 ..< 6 {
		clay.Begin(
			{
				id = clay.ID_LOCAL("Factory", u32(i)),
				layout = {
					layoutDirection = .TopToBottom,
					sizing = {width = clay.SizingFixed(2 * tile_size), height = clay.SizingGrow()},
					//childGap = 2,
					//padding = clay.PaddingAll(2),
				},
				backgroundColor = {45, 55, 72, 255},
				cornerRadius = clay.CornerRadiusAll(4),
			},
		)
		defer clay.End()
		for row in 0 ..< 3 {
			clay.Begin(
				{
					id = clay.ID_LOCAL("Row", u32(row)),
					layout = {
						layoutDirection = .LeftToRight,
						sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
						//childGap = 2,
					},
				},
			)
			defer clay.End()
			for col in 0 ..< 2 {
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
		}
	}

	clay.End()

	// 3. Lower part (equal growing height)
	clay.Element(
		{
			id = clay.ID("BottomPart"),
			layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()}},
			backgroundColor = {41, 98, 255, 255}, // Blue
		},
	)

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
