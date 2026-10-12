#+build !js

package main

import rl "vendor:raylib"

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
