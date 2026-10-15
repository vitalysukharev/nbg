#+build js

package main

import "clay"
import "core:math"
import gl "vendor:wasm/WebGL"

Web_Texture :: struct {
	handle:        gl.Texture,
	width, height: f32,
}

Web_Vertex :: struct {
	position, uv: [2]f32,
	color:        [4]f32,
}

Renderer :: struct {
	program:          gl.Program,
	buffer:           gl.Buffer,
	viewport_uniform: i32,
	textures:         [Sprite_Kind]Web_Texture,
	font:             Web_Font,
	white:            Web_Texture,
	vertices:         [dynamic]Web_Vertex,
	batch_texture:    gl.Texture,
	height:           f32,
	pixel_ratio:      f32,
	clips:            [32]clay.BoundingBox,
	clip_count:       int,
}

WEB_VERTEX_SHADER :: `
attribute vec2 a_position;
attribute vec2 a_uv;
attribute vec4 a_color;
uniform vec2 u_viewport;
varying vec2 v_uv;
varying vec4 v_color;
void main() {
    vec2 clip = a_position / u_viewport * 2.0 - 1.0;
    gl_Position = vec4(clip.x, -clip.y, 0.0, 1.0);
    v_uv = a_uv;
    v_color = a_color;
}
`

WEB_FRAGMENT_SHADER :: `
precision mediump float;
uniform sampler2D u_texture;
varying vec2 v_uv;
varying vec4 v_color;
void main() {
    gl_FragColor = texture2D(u_texture, v_uv) * v_color;
}
`

web_compile_shader :: proc(kind: gl.Enum, source: string) -> gl.Shader {
	shader := gl.CreateShader(kind)
	gl.ShaderSource(shader, []string{source})
	gl.CompileShader(shader)
	if gl.GetShaderiv(shader, gl.COMPILE_STATUS) == 0 {
		log: [1024]u8
		report_error(gl.GetShaderInfoLog(shader, log[:]))
	}
	return shader
}

renderer_init :: proc(renderer: ^Renderer) {
	if !gl.CreateCurrentContextById("game", {.disableAlpha, .disableDepth}) {
		report_error("This browser could not create a WebGL context.")
	}
	vertex := web_compile_shader(gl.VERTEX_SHADER, WEB_VERTEX_SHADER)
	fragment := web_compile_shader(gl.FRAGMENT_SHADER, WEB_FRAGMENT_SHADER)
	defer gl.DeleteShader(vertex)
	defer gl.DeleteShader(fragment)
	renderer.program = gl.CreateProgram()
	gl.AttachShader(renderer.program, vertex)
	gl.AttachShader(renderer.program, fragment)
	gl.BindAttribLocation(renderer.program, 0, "a_position")
	gl.BindAttribLocation(renderer.program, 1, "a_uv")
	gl.BindAttribLocation(renderer.program, 2, "a_color")
	gl.LinkProgram(renderer.program)
	if gl.GetProgramParameter(renderer.program, gl.LINK_STATUS) == 0 {
		log: [1024]u8
		report_error(gl.GetProgramInfoLog(renderer.program, log[:]))
	}
	gl.UseProgram(renderer.program)
	renderer.viewport_uniform = gl.GetUniformLocation(renderer.program, "u_viewport")
	gl.Uniform1i(gl.GetUniformLocation(renderer.program, "u_texture"), 0)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	renderer.buffer = gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, renderer.buffer)
	for attribute in 0 ..< 3 {
		gl.EnableVertexAttribArray(i32(attribute))
	}
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(Web_Vertex), 0)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Web_Vertex), offset_of(Web_Vertex, uv))
	gl.VertexAttribPointer(2, 4, gl.FLOAT, false, size_of(Web_Vertex), offset_of(Web_Vertex, color))
	renderer.vertices = make([dynamic]Web_Vertex, 0, 8192)
	dimensions := [Sprite_Kind][2]f32 {
		.Tile = {640, 128},
		.Factory = {FACTORY_SPRITE.source.width, FACTORY_SPRITE.source.height},
		.Player_Board = {PLAYER_BOARD_SPRITE.source.width, PLAYER_BOARD_SPRITE.source.height},
		.Table = {TABLE_SPRITE.source.width, TABLE_SPRITE.source.height},
	}
	for size, kind in dimensions {
		renderer.textures[kind] = web_load_texture(i32(kind), size, kind == .Table)
	}
	renderer.font = web_load_font()
	renderer.white = {handle = gl.CreateTexture(), width = 1, height = 1}
	gl.BindTexture(gl.TEXTURE_2D, renderer.white.handle)
	pixel := [4]u8{255, 255, 255, 255}
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, 4, &pixel)
	web_texture_parameters(false)
}

web_load_texture :: proc(asset: i32, size: [2]f32, repeat: bool) -> Web_Texture {
	texture := Web_Texture{gl.CreateTexture(), size.x, size.y}
	gl.BindTexture(gl.TEXTURE_2D, texture.handle)
	if !upload_image(texture.handle, asset) {
		report_error("A game texture could not be uploaded.")
	}
	web_texture_parameters(repeat)
	return texture
}

web_texture_parameters :: proc(repeat: bool) {
	wrap := gl.REPEAT if repeat else gl.CLAMP_TO_EDGE
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(wrap))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(wrap))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(gl.LINEAR))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, i32(gl.LINEAR))
}

renderer_shutdown :: proc(renderer: ^Renderer) {
	for texture in renderer.textures {gl.DeleteTexture(texture.handle)}
	gl.DeleteTexture(renderer.font.texture.handle)
	gl.DeleteTexture(renderer.white.handle)
	gl.DeleteBuffer(renderer.buffer)
	gl.DeleteProgram(renderer.program)
	delete(renderer.vertices)
	renderer^ = {}
}

renderer_begin :: proc(renderer: ^Renderer, width, height, pixel_ratio: f32) {
	renderer.height = height
	renderer.pixel_ratio = pixel_ratio
	gl.Viewport(0, 0, gl.DrawingBufferWidth(), gl.DrawingBufferHeight())
	gl.Disable(gl.SCISSOR_TEST)
	gl.ClearColor(0, 0, 0, 1)
	gl.Clear(u32(gl.COLOR_BUFFER_BIT))
	gl.UseProgram(renderer.program)
	gl.Uniform2f(renderer.viewport_uniform, width, height)
	renderer.clip_count = 0
}

web_flush :: proc(renderer: ^Renderer) {
	if len(renderer.vertices) == 0 {return}
	gl.BindTexture(gl.TEXTURE_2D, renderer.batch_texture)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(renderer.vertices) * size_of(Web_Vertex),
		raw_data(renderer.vertices),
		gl.STREAM_DRAW,
	)
	gl.DrawArrays(gl.TRIANGLES, 0, len(renderer.vertices))
	clear(&renderer.vertices)
}

web_use_texture :: proc(renderer: ^Renderer, texture: gl.Texture) {
	if texture != renderer.batch_texture {
		web_flush(renderer)
		renderer.batch_texture = texture
	}
}

web_quad :: proc(
	renderer: ^Renderer,
	texture: Web_Texture,
	source: Sprite_Rect,
	bb: clay.BoundingBox,
	color: clay.Color = {255, 255, 255, 255},
) {
	if bb.width <= 0 || bb.height <= 0 {return}
	web_use_texture(renderer, texture.handle)
	u0, v0 := source.x / texture.width, source.y / texture.height
	u1 := (source.x + source.width) / texture.width
	v1 := (source.y + source.height) / texture.height
	tint := color / 255.0
	a := Web_Vertex{{bb.x, bb.y}, {u0, v0}, tint}
	b := Web_Vertex{{bb.x + bb.width, bb.y}, {u1, v0}, tint}
	c := Web_Vertex{{bb.x + bb.width, bb.y + bb.height}, {u1, v1}, tint}
	d := Web_Vertex{{bb.x, bb.y + bb.height}, {u0, v1}, tint}
	append(&renderer.vertices, a, b, c, a, c, d)
}

web_rectangle :: proc(
	renderer: ^Renderer,
	bb: clay.BoundingBox,
	color: clay.Color,
	radii: clay.CornerRadius = {},
) {
	if bb.width <= 0 || bb.height <= 0 || color.a == 0 {return}
	if radii == (clay.CornerRadius{}) {
		web_quad(renderer, renderer.white, {0, 0, 1, 1}, bb, color)
		return
	}
	web_use_texture(renderer, renderer.white.handle)
	tint := color / 255.0
	center := Web_Vertex{{bb.x + bb.width / 2, bb.y + bb.height / 2}, {}, tint}
	limit := min(bb.width, bb.height) / 2
	r := [4]f32 {
		min(radii.topRight, limit),
		min(radii.bottomRight, limit),
		min(radii.bottomLeft, limit),
		min(radii.topLeft, limit),
	}
	centers := [4][2]f32 {
		{bb.x + bb.width - r[0], bb.y + r[0]},
		{bb.x + bb.width - r[1], bb.y + bb.height - r[1]},
		{bb.x + r[2], bb.y + bb.height - r[2]},
		{bb.x + r[3], bb.y + r[3]},
	}
	points: [4 * (CORNER_ROUND_SEGMENTS + 1)][2]f32
	for corner in 0 ..< 4 {
		for segment in 0 ..= CORNER_ROUND_SEGMENTS {
			angle := (f32(corner - 1) + f32(segment) / CORNER_ROUND_SEGMENTS) * (math.PI / 2)
			points[corner * (CORNER_ROUND_SEGMENTS + 1) + segment] =
				centers[corner] + [2]f32{math.cos(angle), math.sin(angle)} * r[corner]
		}
	}
	for point, i in points {
		next := points[(i + 1) % len(points)]
		append(&renderer.vertices, center, Web_Vertex{point, {}, tint}, Web_Vertex{next, {}, tint})
	}
}

web_image :: proc(renderer: ^Renderer, bb: clay.BoundingBox, data: clay.ImageRenderData) {
	sprite := cast(^UI_Sprite)data.imageData
	if sprite == nil {web_rectangle(renderer, bb, data.backgroundColor); return}
	texture := renderer.textures[sprite.kind]
	source := sprite.source
	if sprite.border > 0 {
		for slice in get_sprite_panel_slices(sprite, bb) {
			web_quad(renderer, texture, slice.source, slice.destination)
		}
	} else {
		if sprite.kind == .Table {source = {0, 0, bb.width, bb.height}}
		web_quad(renderer, texture, source, bb)
	}
}

web_border :: proc(renderer: ^Renderer, bb: clay.BoundingBox, data: clay.BorderRenderData) {
	for side in get_border_sides(bb, data.width) {
		web_rectangle(renderer, side, data.color)
	}
}

web_apply_clip :: proc(renderer: ^Renderer) {
	if renderer.clip_count == 0 {gl.Disable(gl.SCISSOR_TEST); return}
	gl.Enable(gl.SCISSOR_TEST)
	bb := renderer.clips[renderer.clip_count - 1]
	p := renderer.pixel_ratio
	x0 := i32(math.floor(bb.x * p))
	y0 := i32(math.floor((renderer.height - bb.y - bb.height) * p))
	x1 := i32(math.ceil((bb.x + bb.width) * p))
	y1 := i32(math.ceil((renderer.height - bb.y) * p))
	gl.Scissor(x0, y0, max(0, x1 - x0), max(0, y1 - y0))
}

render_clay_commands :: proc(renderer: ^Renderer, commands: []clay.RenderCommand) {
	for command in commands {
		bb := command.boundingBox
		switch command.commandType {
		case .None:
		case .Rectangle:
			data := command.renderData.rectangle
			web_rectangle(renderer, bb, data.backgroundColor, data.cornerRadius)
		case .Border:
			web_border(renderer, bb, command.renderData.border)
		case .Text:
			web_text(renderer, bb, command.renderData.text)
		case .Image:
			web_image(renderer, bb, command.renderData.image)
		case .ScissorStart:
			web_flush(renderer)
			if renderer.clip_count == len(renderer.clips) {report_error("Too many nested clips.")}
			if renderer.clip_count > 0 {
				parent := renderer.clips[renderer.clip_count - 1]
				x, y := max(bb.x, parent.x), max(bb.y, parent.y)
				bb = {x, y, max(0, min(bb.x + bb.width, parent.x + parent.width) - x),
					max(0, min(bb.y + bb.height, parent.y + parent.height) - y)}
			}
			renderer.clips[renderer.clip_count] = bb
			renderer.clip_count += 1
			web_apply_clip(renderer)
		case .ScissorEnd:
			web_flush(renderer)
			renderer.clip_count = max(0, renderer.clip_count - 1)
			web_apply_clip(renderer)
		case .OverlayColorStart, .OverlayColorEnd, .Custom:
			report_error("This Clay command is not supported by the web renderer.")
		}
	}
	web_flush(renderer)
}
