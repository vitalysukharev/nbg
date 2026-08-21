package main

import "base:runtime"
import "clay"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

measure_clay_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	userData: rawptr,
) -> clay.Dimensions {
	context = runtime.default_context()
	text_str := string(text.chars[:text.length])
	c_str := strings.clone_to_cstring(text_str, context.temp_allocator)
	font := rl.GetFontDefault()
	font_size := f32(config.fontSize) if config != nil && config.fontSize > 0 else DEFAULT_FONT_SIZE
	spacing := f32(config.letterSpacing) if config != nil else 0.0
	size := rl.MeasureTextEx(font, c_str, font_size, spacing)
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

clay_color_to_rl_color :: #force_inline proc(c: clay.Color) -> rl.Color {
	return rl.Color {
		u8(clamp(c[0], 0, 255)),
		u8(clamp(c[1], 0, 255)),
		u8(clamp(c[2], 0, 255)),
		u8(clamp(c[3], 0, 255)),
	}
}

bb_to_rl_rec :: #force_inline proc(bb: clay.BoundingBox) -> rl.Rectangle {
	return rl.Rectangle{bb.x, bb.y, bb.width, bb.height}
}

draw_clay_border :: proc(bb: clay.BoundingBox, border: clay.BorderRenderData) {
	color := clay_color_to_rl_color(border.color)
	if border.width.left > 0 {
		rl.DrawRectangleRec({bb.x, bb.y, f32(border.width.left), bb.height}, color)
	}
	if border.width.right > 0 {
		rl.DrawRectangleRec(
			{bb.x + bb.width - f32(border.width.right), bb.y, f32(border.width.right), bb.height},
			color,
		)
	}
	if border.width.top > 0 {
		rl.DrawRectangleRec({bb.x, bb.y, bb.width, f32(border.width.top)}, color)
	}
	if border.width.bottom > 0 {
		rl.DrawRectangleRec(
			{
				bb.x,
				bb.y + bb.height - f32(border.width.bottom),
				bb.width,
				f32(border.width.bottom),
			},
			color,
		)
	}
}

render_clay_commands :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand)) {
	for i in 0 ..< render_commands.length {
		cmd := clay.RenderCommandArray_Get(render_commands, i)
		switch cmd.commandType {
		case .None:
		case .Rectangle:
			rect := cmd.renderData.rectangle
			color := clay_color_to_rl_color(rect.backgroundColor)
			rec := bb_to_rl_rec(cmd.boundingBox)
			min_dim := min(cmd.boundingBox.width, cmd.boundingBox.height)
			if rect.cornerRadius.topLeft > 0 && min_dim > 0 {
				roundness := (rect.cornerRadius.topLeft * 2.0) / min_dim
				rl.DrawRectangleRounded(rec, roundness, CORNER_ROUND_SEGMENTS, color)
			} else {
				rl.DrawRectangleRec(rec, color)
			}
		case .Border:
			draw_clay_border(cmd.boundingBox, cmd.renderData.border)
		case .ScissorStart:
			rl.BeginScissorMode(
				i32(cmd.boundingBox.x),
				i32(cmd.boundingBox.y),
				i32(cmd.boundingBox.width),
				i32(cmd.boundingBox.height),
			)
		case .ScissorEnd:
			rl.EndScissorMode()
		case .Text:
			text_data := cmd.renderData.text
			text_str := string(text_data.stringContents.chars[:text_data.stringContents.length])
			c_str := strings.clone_to_cstring(text_str, context.temp_allocator)
			font := rl.GetFontDefault()
			font_size := f32(text_data.fontSize) if text_data.fontSize > 0 else DEFAULT_FONT_SIZE
			spacing := f32(text_data.letterSpacing)
			color := clay_color_to_rl_color(text_data.textColor)
			rl.DrawTextEx(
				font,
				c_str,
				{cmd.boundingBox.x, cmd.boundingBox.y},
				font_size,
				spacing,
				color,
			)
		case .Image, .OverlayColorStart, .OverlayColorEnd, .Custom:
		// Unused render commands
		}
	}
}
