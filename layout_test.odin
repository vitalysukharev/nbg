#+build !js

package main

import "base:runtime"
import "clay"
import "core:c"
import "core:math"
import "core:testing"

Layout_Test_Element_Kind :: enum {
	Player_Board,
	Factory_Disc,
	Factory_Tile,
}

Layout_Test_Element :: struct {
	kind: Layout_Test_Element_Kind,
	seen: bool,
}

@(rodata)
LAYOUT_TEST_VIEWPORTS := [?][2]f32 {
	{800, 600},
	{600, 800},
	{480, 480},
	{480, 481},
	{481, 480},
	{1920, 1080},
	{480, 1600},
	{1600, 480},
}

@(test)
factory_spacing :: proc(t: ^testing.T) {
	// A two-column, four-row grid of 3x2 tiles, including every padding and gap.
	factories := get_factory_layout(is_horizontal = true, player_count = 3)
	disc_w, disc_h := get_factory_disc_dimensions(factories, 20)
	width, height := get_factories_dimensions(factories, 20)
	testing.expect(t, disc_w == 68 && disc_h == 46)
	testing.expect(t, width == 140 && height == 196)
	for tile in ([]f32{0, 1.25, 10, 40, 100}) {
		w, h := get_factories_dimensions(factories, tile)
		testing.expect(t, math.abs(w - width * tile / 20) < 0.001)
		testing.expect(t, math.abs(h - height * tile / 20) < 0.001)
	}
}

@(test)
layout_fits_viewport :: proc(t: ^testing.T) {
	for size in LAYOUT_TEST_VIEWPORTS {
		for players in MIN_PLAYER_COUNT ..= MAX_PLAYER_COUNT {
			layout := calculate_board_layout(size[0], size[1], players)
			tile := layout.tile_size
			testing.expect(t, tile >= 16)
			ow, oh := get_player_board_dimensions(layout.opponent_board)
			lw, lh := get_player_board_dimensions(layout.local_board)
			fw, fh := get_factories_dimensions(layout.factories, tile)
			gap := f32(AREAS_GAP_IN_TILES)
			width, height: f32
			if layout.is_horizontal {
				width = (ow + lw + 2 * gap) * tile + fw
				board_height := (2 * oh + gap) * tile if players >= 3 else oh * tile
				height = max(board_height, fh)
			} else {
				top_width := (2 * ow + gap) * tile if players >= 3 else ow * tile
				bottom_width := (2 * lw + gap) * tile if players == 4 else lw * tile
				width = max(top_width, bottom_width, fw)
				height = (oh + lh + 2 * gap) * tile + fh
			}
			testing.expect(t, width <= size[0] + 0.01 && height <= size[1] + 0.01)
			// The largest fitting tile size must touch at least one viewport edge.
			testing.expect(
				t,
				math.abs(width - size[0]) < 0.01 || math.abs(height - size[1]) < 0.01,
			)
		}
	}
	for players in MIN_PLAYER_COUNT ..= MAX_PLAYER_COUNT {
		testing.expect(t, calculate_board_layout(0, 0, players).tile_size == 0)
		testing.expect(t, calculate_board_layout(-1, 10, players).tile_size == 0)
	}
}

test_measure_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	data: rawptr,
) -> clay.Dimensions {
	return {f32(text.length) * f32(config.fontSize) * 0.5, f32(config.fontSize)}
}

test_clay_error :: proc "c" (error: clay.ErrorData) {
	context = runtime.default_context()
	testing.expect(
		cast(^testing.T)error.userData,
		false,
		string(error.errorText.chars[:error.errorText.length]),
	)
}

@(test)
rendered_board_layout :: proc(t: ^testing.T) {
	memory := make([]u8, clay.MinMemorySize())
	defer delete(memory)
	defer clay.SetCurrentContext(nil)
	arena := clay.CreateArenaWithCapacityAndMemory(c.size_t(len(memory)), raw_data(memory))
	clay.Initialize(arena, {800, 600}, {handler = test_clay_error, userData = t})
	clay.SetMeasureTextFunction(test_measure_text, nil)
	for size in LAYOUT_TEST_VIEWPORTS {
		for players in MIN_PLAYER_COUNT ..= MAX_PLAYER_COUNT {
			clay.SetLayoutDimensions({size[0], size[1]})
			layout := calculate_board_layout(size[0], size[1], players)
			commands := create_layout(layout, 1.0 / 60.0)
			expect_rendered_layout(t, layout, commands, size)
		}
	}
}

expect_rendered_layout :: proc(
	t: ^testing.T,
	layout: Board_Layout,
	commands: []clay.RenderCommand,
	viewport: [2]f32,
) {
	// Identify layout elements without depending on the current theme palette.
	elements := make(map[u32]Layout_Test_Element)
	defer delete(elements)
	for player in 0 ..< layout.player_count {
		elements[clay.ID("PlayerBoard", u32(player)).id] = {kind = .Player_Board}
	}
	factory_count := 2 * layout.player_count + 2
	tiles_per_disc := layout.factories.tile_x_count * layout.factories.tile_y_count
	for disc in 0 ..< factory_count {
		elements[clay.ID("Factory", u32(disc)).id] = {kind = .Factory_Disc}
		for tile in 0 ..< tiles_per_disc {
			tile_idx := disc * tiles_per_disc + tile
			elements[clay.ID("FactoryTile", u32(tile_idx)).id] = {kind = .Factory_Tile}
		}
	}

	boards: [MAX_PLAYER_COUNT]clay.BoundingBox
	discs: [2 * MAX_PLAYER_COUNT + 2]clay.BoundingBox
	board_count, disc_count, label_count, tile_count := 0, 0, 0, 0
	for command in commands {
		bb := command.boundingBox
		testing.expectf(
			t,
			bb.x >= -0.01 &&
			bb.y >= -0.01 &&
			bb.x + bb.width <= viewport[0] + 0.01 &&
			bb.y + bb.height <= viewport[1] + 0.01,
			"%v players in %v: command %v extends outside the viewport: %v",
			layout.player_count, viewport, command.id, bb,
		)
		if command.commandType == .Text {
			label := command.renderData.text.stringContents
			testing.expect(
				t,
				string(label.chars[:label.length]) == PATTERN_LINE_LABELS[label_count % WALL_DIMENSION],
			)
			label_count += 1
		}
		if command.commandType != .Rectangle {continue}
		element, known := elements[command.id]
		if !known {continue}
		if !testing.expectf(
			t,
			!element.seen,
			"%v players in %v: duplicate %v rectangle with ID %v",
			layout.player_count, viewport, element.kind, command.id,
		) {continue}
		element.seen = true
		elements[command.id] = element
		switch element.kind {
		case .Player_Board:
			if !testing.expect(t, board_count < len(boards)) {return}
			boards[board_count] = bb
			board_count += 1
		case .Factory_Disc:
			if !testing.expect(t, disc_count < len(discs)) {return}
			discs[disc_count] = bb
			disc_count += 1
		case .Factory_Tile:
			tile_count += 1
			testing.expect(
				t,
				math.abs(bb.width - layout.tile_size) < 0.01 &&
				math.abs(bb.height - layout.tile_size) < 0.01,
			)
		}
	}

	for id, element in elements {
		testing.expectf(
			t,
			element.seen,
			"%v players in %v: missing %v rectangle with ID %v",
			layout.player_count, viewport, element.kind, id,
		)
	}
	expect_player_board_layout(t, layout, boards[:board_count], label_count)
	expect_factory_disc_spacing(t, layout, discs[:disc_count])
	testing.expect(
		t,
		tile_count == factory_count * tiles_per_disc,
	)
}

expect_player_board_layout :: proc(
	t: ^testing.T,
	layout: Board_Layout,
	boards: []clay.BoundingBox,
	label_count: int,
) {
	if !testing.expect_value(t, len(boards), layout.player_count) {return}
	// Opponents precede the local group; compact boards retain all five row labels.
	opponent_count := min(layout.player_count - 1, 2)
	compact_count := 0
	for board, i in boards {
		mode := layout.opponent_board if i < opponent_count else layout.local_board
		width, height := get_player_board_dimensions(mode)
		testing.expect(t, math.abs(board.width - width * layout.tile_size) < 0.01)
		testing.expect(t, math.abs(board.height - height * layout.tile_size) < 0.01)
		if mode == .Compact {
			compact_count += 1
		}
		if i == 0 || i == opponent_count {continue}
		previous := boards[i - 1]
		gap := AREAS_GAP_IN_TILES * layout.tile_size
		if layout.is_horizontal {
			testing.expect(t, math.abs(board.y - previous.y - previous.height - gap) < 0.01)
		} else {
			testing.expect(t, math.abs(board.x - previous.x - previous.width - gap) < 0.01)
		}
	}
	testing.expect_value(t, label_count, compact_count * WALL_DIMENSION)
}

expect_factory_disc_spacing :: proc(t: ^testing.T, layout: Board_Layout, discs: []clay.BoundingBox) {
	if !testing.expect_value(t, len(discs), 2 * layout.player_count + 2) {return}
	// Disc centers form equally spaced rows and columns across the central area.
	line_length := layout.factories.disc_rows if layout.is_horizontal else layout.factories.disc_cols
	for i in 2 ..< len(discs) {
		if i % line_length < 2 {continue}
		a, b, c := discs[i - 2], discs[i - 1], discs[i]
		step_difference :=
			(c.y - b.y) - (b.y - a.y) if layout.is_horizontal else (c.x - b.x) - (b.x - a.x)
		testing.expect(t, math.abs(step_difference) < 0.01)
	}
}
