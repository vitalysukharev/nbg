#+build !js

package main

import "clay"
import "core:math"
import "core:testing"

@(test)
sprite_panel_geometry :: proc(t: ^testing.T) {
	// An offset atlas region catches accidental assumptions about source origin.
	sprite := UI_Sprite{source = {13, 27, 192, 128}, border = 8}
	cases := []struct {
		bounds:      clay.BoundingBox,
		corner_size: f32,
	} {
		{{10, 20, 192, 128}, 8},
		{{10, 20, 384, 128}, 8},
		{{10, 20, 192, 256}, 8},
		{{10, 20, 384, 256}, 16},
		{{10, 20, 1, 0.5}, 0.03125},
	}
	for tc in cases {
		slices := get_sprite_panel_slices(&sprite, tc.bounds)
		source_area, destination_area: f32
		for slice, i in slices {
			src, dst := slice.source, slice.destination
			testing.expect(t, src.width > 0 && src.height > 0)
			testing.expect(t, dst.width > 0 && dst.height > 0)
			testing.expect(t, src.x >= sprite.source.x && src.y >= sprite.source.y)
			testing.expect(t, src.x + src.width <= sprite.source.x + sprite.source.width)
			testing.expect(t, src.y + src.height <= sprite.source.y + sprite.source.height)
			testing.expect(t, dst.x >= tc.bounds.x && dst.y >= tc.bounds.y)
			testing.expect(t, dst.x + dst.width <= tc.bounds.x + tc.bounds.width)
			testing.expect(t, dst.y + dst.height <= tc.bounds.y + tc.bounds.height)
			source_area += src.width * src.height
			destination_area += dst.width * dst.height
			// Disjoint slices covering the whole bounds leave no gaps or overlap.
			for other in slices[:i] {
				a := other.destination
				overlap_w := min(dst.x + dst.width, a.x + a.width) - max(dst.x, a.x)
				overlap_h := min(dst.y + dst.height, a.y + a.height) - max(dst.y, a.y)
				testing.expect(t, overlap_w <= 0 || overlap_h <= 0)
			}
		}
		testing.expect(t, source_area == sprite.source.width * sprite.source.height)
		testing.expect(t, math.abs(destination_area - tc.bounds.width * tc.bounds.height) < 0.01)
		for corner in ([]int{0, 2, 6, 8}) {
			dst := slices[corner].destination
			testing.expect(t, math.abs(dst.width - tc.corner_size) < 0.0001)
			testing.expect(t, math.abs(dst.height - tc.corner_size) < 0.0001)
		}
	}
	for bounds in ([]clay.BoundingBox{{0, 0, 0, 10}, {0, 0, 10, 0}, {0, 0, -1, 10}}) {
		testing.expect(t, get_sprite_panel_slices(&sprite, bounds) == ([9]Sprite_Panel_Slice{}))
	}
}
