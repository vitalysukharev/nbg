#+build js

package main

import "base:runtime"
import "clay"

// Eight 32-bit words per glyph, also written by web/app.js.
Web_Glyph :: struct {
	codepoint: rune,
	source:    Sprite_Rect,
	offset:    [2]f32,
	advance:   f32,
}

#assert(size_of(Web_Glyph) == 32)
#assert(offset_of(Web_Glyph, codepoint) == 0)
#assert(offset_of(Web_Glyph, source) == 4)
#assert(offset_of(Web_Glyph, offset) == 20)
#assert(offset_of(Web_Glyph, advance) == 28)

Web_Font :: struct {
	texture:     Web_Texture,
	glyphs:      [128]Web_Glyph,
	glyph_count: int,
	height:      f32,
}

web_load_font :: proc() -> Web_Font {
	font: Web_Font
	font.texture = web_load_texture(4, {512, 1024}, false)
	font.glyph_count = int(read_font(
		&font.glyphs[0],
		i32(len(font.glyphs)),
		&font.height,
	))
	if font.glyph_count <= 0 || font.height <= 0 {
		report_error("The game font could not be loaded.")
	}
	return font
}

web_glyph :: proc(font: ^Web_Font, codepoint: rune) -> Web_Glyph {
	fallback: Web_Glyph
	for glyph in font.glyphs[:font.glyph_count] {
		if glyph.codepoint == codepoint {return glyph}
		if glyph.codepoint == '?' {fallback = glyph}
	}
	return fallback
}

measure_clay_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	user_data: rawptr,
) -> clay.Dimensions {
	context = runtime.default_context()
	renderer := cast(^Renderer)user_data
	font_size := clay_font_size(config.fontSize)
	scale := font_size / renderer.font.height
	width, line_width: f32
	lines, count := 1, 0
	for codepoint in string(text.chars[:text.length]) {
		if codepoint == '\n' {
			width = max(width, line_width)
			line_width, count = 0, 0
			lines += 1
			continue
		}
		if count > 0 {line_width += f32(config.letterSpacing)}
		line_width += web_glyph(&renderer.font, codepoint).advance * scale
		count += 1
	}
	return {max(width, line_width), f32(lines) * font_size}
}

web_text :: proc(renderer: ^Renderer, bb: clay.BoundingBox, text: clay.TextRenderData) {
	font_size := clay_font_size(text.fontSize)
	scale := font_size / renderer.font.height
	x, y := bb.x, bb.y
	for codepoint in string(text.stringContents.chars[:text.stringContents.length]) {
		if codepoint == '\n' {x, y = bb.x, y + font_size; continue}
		glyph := web_glyph(&renderer.font, codepoint)
		if codepoint != ' ' {
			web_quad(renderer, renderer.font.texture, glyph.source,
				{x + glyph.offset.x * scale, y + glyph.offset.y * scale,
				 glyph.source.width * scale, glyph.source.height * scale}, text.textColor)
		}
		x += glyph.advance * scale + f32(text.letterSpacing)
	}
}
