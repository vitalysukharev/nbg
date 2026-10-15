package main

import "clay"

clay_font_size :: proc(size: u16) -> f32 {
	return f32(size) if size > 0 else DEFAULT_FONT_SIZE
}

Sprite_Panel_Slice :: struct {
	source:      Sprite_Rect,
	destination: clay.BoundingBox,
}

// Both renderers use the same nine-slice geometry. Corners scale uniformly;
// only the edges and center stretch to fit the destination.
get_sprite_panel_slices :: proc(sprite: ^UI_Sprite, bb: clay.BoundingBox) -> [9]Sprite_Panel_Slice {
	slices: [9]Sprite_Panel_Slice
	if bb.width <= 0 || bb.height <= 0 {return slices}
	source := sprite.source
	border := f32(sprite.border)
	scale := min(bb.width / source.width, bb.height / source.height)
	margin := min(border * scale, min(bb.width, bb.height) / 2)
	sx := [4]f32{0, border, source.width - border, source.width}
	sy := [4]f32{0, border, source.height - border, source.height}
	dx := [4]f32{0, margin, bb.width - margin, bb.width}
	dy := [4]f32{0, margin, bb.height - margin, bb.height}
	for row in 0 ..< 3 {
		for col in 0 ..< 3 {
			slices[row * 3 + col] = {
				source = {
					source.x + sx[col], source.y + sy[row],
					sx[col + 1] - sx[col], sy[row + 1] - sy[row],
				},
				destination = {
					bb.x + dx[col], bb.y + dy[row],
					dx[col + 1] - dx[col], dy[row + 1] - dy[row],
				},
			}
		}
	}
	return slices
}

// Border sides use the same bounds on both platforms.
get_border_sides :: proc(bb: clay.BoundingBox, widths: clay.BorderWidth) -> [4]clay.BoundingBox {
	return {
		{bb.x, bb.y, f32(widths.left), bb.height},
		{bb.x + bb.width - f32(widths.right), bb.y, f32(widths.right), bb.height},
		{bb.x, bb.y, bb.width, f32(widths.top)},
		{bb.x, bb.y + bb.height - f32(widths.bottom), bb.width, f32(widths.bottom)},
	}
}
