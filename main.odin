package main

import rl "vendor:raylib"

DEFAULT_WIDTH :: 800
DEFAULT_HEIGHT :: 600
WINDOW_TITLE :: "Hello, World!"

players := 2
areas := 0

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(DEFAULT_WIDTH, DEFAULT_HEIGHT, WINDOW_TITLE)
	rl.SetWindowState({.WINDOW_ALWAYS_RUN})
	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.RAYWHITE)

		if rl.IsKeyPressed(.SPACE) {
			players = (players + 1)
			if players > 4 {
				players = players - 3
			}
		}

		rl.DrawText(rl.TextFormat("%d", players), 10, 10, 30, rl.BLACK)

		width, height := rl.GetScreenWidth(), rl.GetScreenHeight()
		if width >= height {
			if players == 2 {
				rl.DrawLine(width / 2, 0, width / 2, height, rl.BLACK)
			} else if players == 3 {
				rl.DrawLine(width / 2, 0, width / 2, height, rl.BLACK)
				rl.DrawLine(width / 2, height / 2, 0, height / 2, rl.BLACK)
			} else {
				rl.DrawLine(width / 2, 0, width / 2, height, rl.BLACK)
				rl.DrawLine(0, height / 2, width, height / 2, rl.BLACK)
			}
		} else {
			if players == 2 {
				rl.DrawLine(0, height / 2, width, height / 2, rl.BLACK)
			} else if players == 3 {
				rl.DrawLine(0, height / 2, width, height / 2, rl.BLACK)
				rl.DrawLine(width / 2, height / 2, width / 2, 0, rl.BLACK)
			} else {
				rl.DrawLine(0, height / 2, width, height / 2, rl.BLACK)
				rl.DrawLine(width / 2, 0, width / 2, height, rl.BLACK)
			}
		}
	}

	rl.CloseWindow()
}
