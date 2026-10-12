package main

Pointer_Input :: struct {
	position:      [2]f32,
	held, pressed: bool,
}

read_pointer_input :: proc(
	mouse_position: [2]f32,
	mouse_held, mouse_pressed: bool,
	touch_position: [2]f32,
	touch_count, previous_touch_count: i32,
) -> Pointer_Input {
	result := Pointer_Input {
		position = mouse_position,
		held     = mouse_held,
		pressed  = mouse_pressed,
	}
	if touch_count > 0 {
		result.position = touch_position
		result.held = true
		// Raylib exposes active touch points; only new contacts count as presses.
		result.pressed = result.pressed || touch_count > previous_touch_count
	}
	return result
}
