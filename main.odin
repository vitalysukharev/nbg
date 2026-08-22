package main

import "clay"
import "core:c"
import rl "vendor:raylib"

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT, WINDOW_TITLE)
	rl.SetTargetFPS(TARGET_FPS)
	defer rl.CloseWindow()

	// Initialize Clay layout engine arena
	min_memory_size := clay.MinMemorySize()
	memory := make([]u8, min_memory_size)
	defer delete(memory)

	arena := clay.CreateArenaWithCapacityAndMemory(c.size_t(min_memory_size), raw_data(memory))
	clay.Initialize(
		arena,
		{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
		{handler = clay_error_handler},
	)
	clay.SetMeasureTextFunction(measure_clay_text, nil)

	player_count := MIN_PLAYER_COUNT

	for !rl.WindowShouldClose() {
		free_all(context.temp_allocator)

		if rl.IsKeyPressed(.SPACE) {
			player_count = player_count + 1 if player_count < MAX_PLAYER_COUNT else MIN_PLAYER_COUNT
		}

		screen_w := f32(rl.GetScreenWidth())
		screen_h := f32(rl.GetScreenHeight())

		// Update Clay dimensions and inputs
		clay.SetLayoutDimensions({screen_w, screen_h})

		mouse_pos := rl.GetMousePosition()
		clay.SetPointerState({mouse_pos.x, mouse_pos.y}, rl.IsMouseButtonDown(.LEFT))

		clay.UpdateScrollContainers(
			false,
			{rl.GetMouseWheelMoveV().x, rl.GetMouseWheelMoveV().y},
			rl.GetFrameTime(),
		)

		render_commands := create_layout(screen_w, screen_h, rl.GetFrameTime(), player_count)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		render_clay_commands(&render_commands)
		rl.EndDrawing()
	}
}
