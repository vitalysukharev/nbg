package main

import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(800, 600, "Hello, World!")
	rl.SetTargetFPS(60)
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.DrawText("Hello, World, again!", 10, 10, 20, rl.BLACK)
	}
	rl.CloseWindow()
}
