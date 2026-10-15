#+build !js

package main

import rl "vendor:raylib"

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .MSAA_4X_HINT})
	rl.InitWindow(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT, WINDOW_TITLE)
	defer rl.CloseWindow()
	rl.SetTargetFPS(TARGET_FPS)

	app: App
	app_init(&app, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
	defer app_shutdown(&app)
	previous_touch_count: i32
	for !rl.WindowShouldClose() {
		app_step(&app, &previous_touch_count)
	}
}

app_step :: proc(app: ^App, previous_touch_count: ^i32) {
	defer free_all(context.temp_allocator)

	pointer, touch_count := poll_pointer_input(previous_touch_count^)
	previous_touch_count^ = touch_count
	render_commands := app_update(
		app,
		f32(rl.GetScreenWidth()),
		f32(rl.GetScreenHeight()),
		pointer,
		rl.GetMouseWheelMoveV(),
		rl.GetFrameTime(),
	)

	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(rl.BLACK)
	render_clay_commands(&app.renderer, render_commands)
}
