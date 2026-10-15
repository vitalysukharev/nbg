package main

import "clay"
import "core:c"

// Platform entry points own the window, input polling, and drawing boundaries.
App :: struct {
	clay_memory:  []u8,
	player_count: int,
	renderer:     Renderer,
}

app_init :: proc(app: ^App, width, height: f32) {
	renderer_init(&app.renderer)
	app.clay_memory = make([]u8, clay.MinMemorySize())
	arena := clay.CreateArenaWithCapacityAndMemory(
		c.size_t(len(app.clay_memory)),
		raw_data(app.clay_memory),
	)
	clay.Initialize(arena, {width, height}, {handler = clay_error_handler})
	clay.SetMeasureTextFunction(measure_clay_text, &app.renderer)
	app.player_count = MIN_PLAYER_COUNT
}

app_shutdown :: proc(app: ^App) {
	clay.SetCurrentContext(nil)
	delete(app.clay_memory)
	renderer_shutdown(&app.renderer)
	app^ = {}
}

// Commands borrow Clay's arena and must be drawn before the next update.
app_update :: proc(
	app: ^App,
	width, height: f32,
	pointer: Pointer_Input,
	wheel: [2]f32,
	frame_time: f32,
) -> []clay.RenderCommand {
	if pointer.pressed {
		app.player_count =
			app.player_count + 1 if app.player_count < MAX_PLAYER_COUNT else MIN_PLAYER_COUNT
	}
	clay.SetLayoutDimensions({width, height})
	clay.SetPointerState({pointer.position.x, pointer.position.y}, pointer.held)
	clay.UpdateScrollContainers(false, {wheel.x, wheel.y}, frame_time)
	layout := calculate_board_layout(width, height, app.player_count)
	return create_layout(layout, frame_time)
}
