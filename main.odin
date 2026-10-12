#+build !js

package main

import "clay"
import "core:c"
import rl "vendor:raylib"

App :: struct {
	clay_memory:          []u8,
	player_count:         int,
	previous_touch_count: i32,
	renderer:             Renderer,
}

main :: proc() {
	app: App
	app_init(&app)
	defer app_shutdown(&app)
	for !rl.WindowShouldClose() {
		app_step(&app)
	}
}

app_init :: proc(app: ^App) {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .MSAA_4X_HINT})
	rl.InitWindow(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT, WINDOW_TITLE)
	rl.SetTargetFPS(TARGET_FPS)
	renderer_init(&app.renderer)

	// Initialize Clay layout engine arena
	min_memory_size := clay.MinMemorySize()
	app.clay_memory = make([]u8, min_memory_size)

	arena := clay.CreateArenaWithCapacityAndMemory(
		c.size_t(min_memory_size),
		raw_data(app.clay_memory),
	)
	clay.Initialize(
		arena,
		{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
		{handler = clay_error_handler},
	)
	clay.SetMeasureTextFunction(measure_clay_text, &app.renderer)

	app.player_count = MIN_PLAYER_COUNT
}

app_shutdown :: proc(app: ^App) {
	clay.SetCurrentContext(nil)
	delete(app.clay_memory)
	renderer_shutdown(&app.renderer)
	app^ = {}
	rl.CloseWindow()
}

app_step :: proc(app: ^App) {
	defer free_all(context.temp_allocator)

	pointer, touch_count := poll_pointer_input(app.previous_touch_count)
	app.previous_touch_count = touch_count
	if pointer.pressed {
		app.player_count =
			app.player_count + 1 if app.player_count < MAX_PLAYER_COUNT else MIN_PLAYER_COUNT
	}

	screen_w := f32(rl.GetScreenWidth())
	screen_h := f32(rl.GetScreenHeight())
	frame_time := rl.GetFrameTime()

	// Update Clay dimensions and inputs
	clay.SetLayoutDimensions({screen_w, screen_h})

	clay.SetPointerState({pointer.position.x, pointer.position.y}, pointer.held)

	wheel := rl.GetMouseWheelMoveV()
	clay.UpdateScrollContainers(false, {wheel.x, wheel.y}, frame_time)

	layout := calculate_board_layout(screen_w, screen_h, app.player_count)
	render_commands := create_layout(layout, frame_time)

	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(rl.BLACK)
	render_clay_commands(&app.renderer, render_commands)
}
