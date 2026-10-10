package main

import rl "vendor:raylib"

Pointer_Input :: struct {
	position:      rl.Vector2,
	held, pressed: bool,
}

poll_pointer_input :: proc(
	previous_touch_count: i32,
) -> (
	pointer: Pointer_Input,
	touch_count: i32,
) {
	touch_count = rl.GetTouchPointCount()
	touch_position := rl.GetTouchPosition(0) if touch_count > 0 else rl.Vector2{}
	pointer = read_pointer_input(
		rl.GetMousePosition(),
		rl.IsMouseButtonDown(.LEFT),
		rl.IsMouseButtonPressed(.LEFT),
		touch_position,
		touch_count,
		previous_touch_count,
	)
	return
}

read_pointer_input :: proc(
	mouse_position: rl.Vector2,
	mouse_held, mouse_pressed: bool,
	touch_position: rl.Vector2,
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
