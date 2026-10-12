#+build js

package main

import "base:runtime"
import "clay"
import "core:c"
import gl "vendor:wasm/WebGL"

// ABI shared with web/app.js: eight float32 values followed by two int32 flags.
Browser_Input :: struct {
	width, height, pixel_ratio: f32,
	x, y, wheel_x, wheel_y:    f32,
	visible:                  f32,
	held, pressed:            i32,
}

foreign import browser "nbg"

@(default_calling_convention = "contextless")
foreign browser {
	read_input :: proc(input: ^Browser_Input) ---
	upload_image :: proc(texture: gl.Texture, asset: i32) -> bool ---
	read_font :: proc(glyphs: [^]Web_Glyph, capacity: i32, line_height: ^f32) -> i32 ---
	report_error :: proc(message: string) ---
}

Web_App :: struct {
	clay_memory:  []u8,
	renderer:     Renderer,
	player_count: int,
}

web_app: Web_App
web_running: bool

main :: proc() {
	renderer_init(&web_app.renderer)
	web_app.clay_memory = make([]u8, clay.MinMemorySize())
	arena := clay.CreateArenaWithCapacityAndMemory(
		c.size_t(len(web_app.clay_memory)),
		raw_data(web_app.clay_memory),
	)
	clay.Initialize(arena, {800, 600}, {handler = clay_error_handler})
	clay.SetMeasureTextFunction(measure_clay_text, &web_app.renderer)
	web_app.player_count = MIN_PLAYER_COUNT
	web_running = true
}

// odin.js calls this each animation frame with Odin's default context.
@(export)
step :: proc(delta_time: f64) -> bool {
	if !web_running {return false}
	defer free_all(context.temp_allocator)
	input: Browser_Input
	read_input(&input)
	if input.visible == 0 || input.width <= 0 || input.height <= 0 {return true}
	if input.pressed != 0 {
		web_app.player_count = web_app.player_count + 1 if
			web_app.player_count < MAX_PLAYER_COUNT else MIN_PLAYER_COUNT
	}
	clay.SetLayoutDimensions({input.width, input.height})
	clay.SetPointerState({input.x, input.y}, input.held != 0)
	frame_time := f32(clamp(delta_time, 0, 0.1))
	clay.UpdateScrollContainers(false, {input.wheel_x, input.wheel_y}, frame_time)
	layout := calculate_board_layout(input.width, input.height, web_app.player_count)
	commands := create_layout(layout, frame_time)
	renderer_begin(&web_app.renderer, input.width, input.height, input.pixel_ratio)
	render_clay_commands(&web_app.renderer, commands)
	return true
}

@(export)
get_player_count :: proc "c" () -> i32 {
	return i32(web_app.player_count)
}

@(export)
shutdown :: proc "c" () {
	context = runtime.default_context()
	if !web_running {return}
	web_running = false
	clay.SetCurrentContext(nil)
	delete(web_app.clay_memory)
	renderer_shutdown(&web_app.renderer)
	web_app = {}
}

clay_error_handler :: proc "c" (error: clay.ErrorData) {
	report_error(string(error.errorText.chars[:error.errorText.length]))
}
