package main

import "base:runtime"
import "clay"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

Renderer_Limitation :: enum {
	Unequal_Corners,
	Rounded_Borders,
	Image,
	Overlay,
	Custom,
	Font,
}

Renderer :: struct {
	warned: bit_set[Renderer_Limitation],
}

clay_text_to_cstring :: proc(text: clay.StringSlice) -> cstring {
	return strings.clone_to_cstring(string(text.chars[:text.length]), context.temp_allocator)
}

clay_font_size :: proc(size: u16) -> f32 {
	return f32(size) if size > 0 else DEFAULT_FONT_SIZE
}

measure_clay_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	user_data: rawptr,
) -> clay.Dimensions {
	context = runtime.default_context()
	font_size := clay_font_size(config.fontSize if config != nil else 0)
	spacing := f32(config.letterSpacing) if config != nil else 0.0
	size := rl.MeasureTextEx(rl.GetFontDefault(), clay_text_to_cstring(text), font_size, spacing)
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
	widths := border.width
	sides := [4]struct {
		thickness: u16,
		bounds:    rl.Rectangle,
	} {
		{widths.left, {bb.x, bb.y, f32(widths.left), bb.height}},
		{widths.right, {bb.x + bb.width - f32(widths.right), bb.y, f32(widths.right), bb.height}},
		{widths.top, {bb.x, bb.y, bb.width, f32(widths.top)}},
		{
			widths.bottom,
			{bb.x, bb.y + bb.height - f32(widths.bottom), bb.width, f32(widths.bottom)},
		},
	}
	for side in sides {
		if side.thickness == 0 {continue}
		rl.DrawRectangleRec(side.bounds, color)
	}
}

draw_clay_text :: proc(renderer: ^Renderer, bb: clay.BoundingBox, text: clay.TextRenderData) {
	if text.fontId != 0 {
		warn_renderer_limitation(renderer, .Font)
	}
	rl.DrawTextEx(
		rl.GetFontDefault(),
		clay_text_to_cstring(text.stringContents),
		{bb.x, bb.y},
		clay_font_size(text.fontSize),
		f32(text.letterSpacing),
		clay_color_to_rl_color(text.textColor),
	)
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
			warn_renderer_limitation(renderer, .Image)
		case .OverlayColorStart, .OverlayColorEnd:
			warn_renderer_limitation(renderer, .Overlay)
		case .Custom:
			warn_renderer_limitation(renderer, .Custom)
		}
	}
}
