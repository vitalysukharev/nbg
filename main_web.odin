#+build js

package main

import "base:runtime"
import "clay"
import gl "vendor:wasm/WebGL"

// ABI shared with web/app.js: eight float32 values followed by two int32 flags.
Browser_Input :: struct {
	width, height, pixel_ratio: f32,
	x, y, wheel_x, wheel_y:    f32,
	visible:                  f32,
	held, pressed:            i32,
}

// Keep these offsets compatible with the typed-array writes in web/app.js.
#assert(size_of(Browser_Input) == 40)
#assert(offset_of(Browser_Input, width) == 0)
#assert(offset_of(Browser_Input, height) == 4)
#assert(offset_of(Browser_Input, pixel_ratio) == 8)
#assert(offset_of(Browser_Input, x) == 12)
#assert(offset_of(Browser_Input, y) == 16)
#assert(offset_of(Browser_Input, wheel_x) == 20)
#assert(offset_of(Browser_Input, wheel_y) == 24)
#assert(offset_of(Browser_Input, visible) == 28)
#assert(offset_of(Browser_Input, held) == 32)
#assert(offset_of(Browser_Input, pressed) == 36)

foreign import browser "nbg"

@(default_calling_convention = "contextless")
foreign browser {
	read_input :: proc(input: ^Browser_Input) ---
	upload_image :: proc(texture: gl.Texture, asset: i32) -> bool ---
	read_font :: proc(glyphs: [^]Web_Glyph, capacity: i32, line_height: ^f32) -> i32 ---
	report_error :: proc(message: string) ---
}

web_app: App
web_running: bool

main :: proc() {
	app_init(&web_app, DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT)
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
	frame_time := f32(clamp(delta_time, 0, 0.1))
	commands := app_update(
		&web_app,
		input.width,
		input.height,
		{position = {input.x, input.y}, held = input.held != 0, pressed = input.pressed != 0},
		{input.wheel_x, input.wheel_y},
		frame_time,
	)
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
	app_shutdown(&web_app)
}

clay_error_handler :: proc "c" (error: clay.ErrorData) {
	report_error(string(error.errorText.chars[:error.errorText.length]))
}
