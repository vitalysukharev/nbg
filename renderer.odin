#+build !js

package main

import "base:runtime"
import "clay"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

Renderer_Limitation :: enum {
	Unequal_Corners,
	Rounded_Borders,
	Overlay,
	Custom,
	Font,
}

Renderer :: struct {
	warned:   bit_set[Renderer_Limitation],
	textures: [Sprite_Kind]rl.Texture2D,
	font:     rl.Font,
}

renderer_init :: proc(renderer: ^Renderer) {
	font := rl.LoadFont(UI_FONT_PATH)
	if rl.IsFontValid(font) && font.texture.id != 0 &&
	   font.texture.id != rl.GetFontDefault().texture.id {
		rl.SetTextureFilter(font.texture, .BILINEAR)
		renderer.font = font
	} else {
		fmt.eprintfln("Could not load %s; using the default font.", UI_FONT_PATH)
	}

	for path, kind in SPRITE_TEXTURE_PATHS {
		texture := rl.LoadTexture(path)
		if !rl.IsTextureValid(texture) {
			fmt.eprintfln("Could not load %s; using flat colors for %v.", path, kind)
			continue
		}
		rl.SetTextureFilter(texture, .BILINEAR)
		if kind == .Table {
			rl.SetTextureWrap(texture, .REPEAT)
		}
		renderer.textures[kind] = texture
	}
}

renderer_shutdown :: proc(renderer: ^Renderer) {
	if renderer.font.texture.id != 0 {
		rl.UnloadFont(renderer.font)
	}
	for texture in renderer.textures {
		if texture.id != 0 {
			rl.UnloadTexture(texture)
		}
	}
	renderer^ = {}
}

renderer_font :: proc(renderer: ^Renderer) -> rl.Font {
	if renderer != nil && renderer.font.texture.id != 0 {
		return renderer.font
	}
	return rl.GetFontDefault()
}

clay_text_to_cstring :: proc(text: clay.StringSlice) -> cstring {
	return strings.clone_to_cstring(string(text.chars[:text.length]), context.temp_allocator)
}

measure_clay_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	user_data: rawptr,
) -> clay.Dimensions {
	context = runtime.default_context()
	font_size := clay_font_size(config.fontSize if config != nil else 0)
	spacing := f32(config.letterSpacing) if config != nil else 0.0
	size := rl.MeasureTextEx(
		renderer_font(cast(^Renderer)user_data),
		clay_text_to_cstring(text),
		font_size,
		spacing,
	)
	return {width = size.x, height = size.y}
}

clay_error_handler :: proc "c" (error_data: clay.ErrorData) {
	context = runtime.default_context()
	fmt.eprintfln(
		"Clay error: %s (type: %v)",
		string(error_data.errorText.chars[:error_data.errorText.length]),
		error_data.errorType,
	)
}

clay_color_to_rl_color :: proc(color: clay.Color) -> rl.Color {
	return rl.Color {
		u8(clamp(color[0], 0, 255)),
		u8(clamp(color[1], 0, 255)),
		u8(clamp(color[2], 0, 255)),
		u8(clamp(color[3], 0, 255)),
	}
}

clay_box_to_rl_rectangle :: proc(bb: clay.BoundingBox) -> rl.Rectangle {
	return rl.Rectangle{bb.x, bb.y, bb.width, bb.height}
}

draw_clay_rectangle :: proc(
	renderer: ^Renderer,
	bb: clay.BoundingBox,
	rect: clay.RectangleRenderData,
) {
	radii := rect.cornerRadius
	if radii.topLeft != radii.topRight ||
	   radii.topLeft != radii.bottomLeft ||
	   radii.topLeft != radii.bottomRight {
		warn_renderer_limitation(renderer, .Unequal_Corners)
	}
	color := clay_color_to_rl_color(rect.backgroundColor)
	bounds := clay_box_to_rl_rectangle(bb)
	min_dim := min(bb.width, bb.height)
	if radii.topLeft > 0 && min_dim > 0 {
		roundness := clamp((radii.topLeft * 2.0) / min_dim, 0, 1)
		rl.DrawRectangleRounded(bounds, roundness, CORNER_ROUND_SEGMENTS, color)
	} else {
		rl.DrawRectangleRec(bounds, color)
	}
}

draw_clay_border :: proc(
	renderer: ^Renderer,
	bb: clay.BoundingBox,
	border: clay.BorderRenderData,
) {
	radii := border.cornerRadius
	if radii.topLeft > 0 || radii.topRight > 0 || radii.bottomLeft > 0 || radii.bottomRight > 0 {
		warn_renderer_limitation(renderer, .Rounded_Borders)
	}
	color := clay_color_to_rl_color(border.color)
	for side in get_border_sides(bb, border.width) {
		if side.width <= 0 || side.height <= 0 {continue}
		rl.DrawRectangleRec(clay_box_to_rl_rectangle(side), color)
	}
}

draw_clay_text :: proc(renderer: ^Renderer, bb: clay.BoundingBox, text: clay.TextRenderData) {
	if text.fontId != 0 {
		warn_renderer_limitation(renderer, .Font)
	}
	rl.DrawTextEx(
		renderer_font(renderer),
		clay_text_to_cstring(text.stringContents),
		{bb.x, bb.y},
		clay_font_size(text.fontSize),
		f32(text.letterSpacing),
		clay_color_to_rl_color(text.textColor),
	)
}

draw_clay_image :: proc(renderer: ^Renderer, bb: clay.BoundingBox, data: clay.ImageRenderData) {
	sprite := cast(^UI_Sprite)data.imageData
	texture: rl.Texture2D
	color := data.backgroundColor
	if sprite != nil {
		texture = renderer.textures[sprite.kind]
		switch sprite.kind {
		case .Tile:
			color = WALL_COLORS[sprite.color_index]
		case .Factory:
			color = COLOR_BG_FACTORY_DISC
		case .Player_Board:
			color = COLOR_BG_PLAYER_BOARD
		case .Table:
			color = COLOR_BG_APP
		}
	}
	if sprite == nil || texture.id == 0 {
		draw_clay_rectangle(
			renderer,
			bb,
			{backgroundColor = color, cornerRadius = data.cornerRadius},
		)
		return
	}
	if sprite.border > 0 {
		draw_sprite_panel(texture, sprite, bb)
		return
	}
	source := sprite.source
	if sprite.kind == .Table {
		// Repeat at a fixed pixel scale so resizing never stretches the wood grain.
		source = {0, 0, bb.width, bb.height}
	}
	rl.DrawTexturePro(
		texture,
		{source.x, source.y, source.width, source.height},
		clay_box_to_rl_rectangle(bb),
		{0, 0},
		0,
		rl.WHITE,
	)
}

draw_sprite_panel :: proc(texture: rl.Texture2D, sprite: ^UI_Sprite, bb: clay.BoundingBox) {
	if bb.width <= 0 || bb.height <= 0 {return}
	for slice in get_sprite_panel_slices(sprite, bb) {
		source := slice.source
		rl.DrawTexturePro(
			texture,
			{source.x, source.y, source.width, source.height},
			clay_box_to_rl_rectangle(slice.destination),
			{0, 0},
			0,
			rl.WHITE,
		)
	}
}

// Report each unsupported feature once in debug builds, without flooding each frame.
warn_renderer_limitation :: proc(renderer: ^Renderer, feature: Renderer_Limitation) {
	when ODIN_DEBUG {
		if feature not_in renderer.warned {
			fmt.eprintfln("Renderer does not support: %v", feature)
			renderer.warned += {feature}
		}
	}
}

render_clay_commands :: proc(renderer: ^Renderer, commands: []clay.RenderCommand) {
	for cmd in commands {
		switch cmd.commandType {
		case .None:
		case .Rectangle:
			draw_clay_rectangle(renderer, cmd.boundingBox, cmd.renderData.rectangle)
		case .Border:
			draw_clay_border(renderer, cmd.boundingBox, cmd.renderData.border)
		case .Text:
			draw_clay_text(renderer, cmd.boundingBox, cmd.renderData.text)
		case .ScissorStart:
			rl.BeginScissorMode(
				i32(cmd.boundingBox.x),
				i32(cmd.boundingBox.y),
				i32(cmd.boundingBox.width),
				i32(cmd.boundingBox.height),
			)
		case .ScissorEnd:
			rl.EndScissorMode()
		case .Image:
			draw_clay_image(renderer, cmd.boundingBox, cmd.renderData.image)
		case .OverlayColorStart, .OverlayColorEnd:
			warn_renderer_limitation(renderer, .Overlay)
		case .Custom:
			warn_renderer_limitation(renderer, .Custom)
		}
	}
}
