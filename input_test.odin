#+build !js

package main

import "core:testing"

@(test)
pointer_mouse_and_touch :: proc(t: ^testing.T) {
	cases := []struct {
		name:             string,
		actual, expected: Pointer_Input,
	} {
		{
			"mouse press",
			read_pointer_input({10, 20}, true, true, {}, 0, 0),
			{position = {10, 20}, held = true, pressed = true},
		},
		{
			"held mouse",
			read_pointer_input({15, 25}, true, false, {}, 0, 0),
			{position = {15, 25}, held = true},
		},
		{
			"new touch",
			read_pointer_input({}, false, false, {30, 40}, 1, 0),
			{position = {30, 40}, held = true, pressed = true},
		},
		{
			"held touch",
			read_pointer_input({}, false, false, {35, 45}, 1, 1),
			{position = {35, 45}, held = true},
		},
		{
			"press without a remaining contact",
			read_pointer_input({30, 40}, false, true, {}, 0, 0),
			{position = {30, 40}, pressed = true},
		},
		{
			"released touch",
			read_pointer_input({10, 20}, false, false, {}, 0, 1),
			{position = {10, 20}},
		},
		{
			"touch overrides emulated mouse",
			read_pointer_input({10, 20}, true, true, {30, 40}, 1, 0),
			{position = {30, 40}, held = true, pressed = true},
		},
		{
			"second finger",
			read_pointer_input({}, false, false, {30, 40}, 2, 1),
			{position = {30, 40}, held = true, pressed = true},
		},
		{
			"one finger lifted",
			read_pointer_input({}, false, false, {35, 45}, 1, 2),
			{position = {35, 45}, held = true},
		},
	}
	for tc in cases {
		testing.expectf(
			t,
			tc.actual == tc.expected,
			"%s: expected %v, got %v",
			tc.name,
			tc.expected,
			tc.actual,
		)
	}
}
