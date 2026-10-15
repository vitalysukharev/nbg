package main

import "clay"

render_factory_disc :: proc(disc_idx: int, factories: Factory_Layout, tile_size: f32) {
	disc_w, disc_h := get_factory_disc_dimensions(factories, tile_size)
	clay.Begin(
		{
			id = clay.ID("Factory", u32(disc_idx)),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {width = clay.SizingFixed(disc_w), height = clay.SizingFixed(disc_h)},
				childAlignment = {x = .Center, y = .Center},
			},
			cornerRadius = CORNER_RADIUS_FACTORY,
			image = {imageData = rawptr(&FACTORY_SPRITE)},
		},
	)
	defer clay.End()

	for row in 0 ..< factories.tile_rows {
		if row > 0 {
			ui_gap(FACTORY_TILE_GAP_IN_TILES * tile_size, .TopToBottom)
		}
		clay.Begin(
			{
				id = clay.ID_LOCAL("Row", u32(row)),
				layout = {
					layoutDirection = .LeftToRight,
					sizing = {
						width = clay.SizingFixed(
							disc_w - 2 * FACTORY_PADDING_IN_TILES * tile_size,
						),
						height = clay.SizingFixed(tile_size),
					},
				},
			},
		)
		defer clay.End()

		for col in 0 ..< factories.tile_cols {
			if col > 0 {
				ui_gap(FACTORY_TILE_GAP_IN_TILES * tile_size, .LeftToRight)
			}
			tile_idx := (disc_idx * factories.tile_rows + row) * factories.tile_cols + col
			color_idx := tile_idx % WALL_DIMENSION
			clay.Element(
				{
					id = clay.ID("FactoryTile", u32(tile_idx)),
					layout = {
						sizing = {
							width = clay.SizingFixed(tile_size),
							height = clay.SizingFixed(tile_size),
						},
					},
					cornerRadius = CORNER_RADIUS_TILE,
					image = {imageData = rawptr(&TILE_SPRITES[color_idx])},
				},
			)
		}
	}
}

render_factories :: proc(is_horizontal: bool, tile_size: f32, factories: Factory_Layout) {
	total_w, total_h := get_factories_dimensions(factories, tile_size)
	outer_direction: clay.LayoutDirection = .LeftToRight if is_horizontal else .TopToBottom
	inner_direction: clay.LayoutDirection = .TopToBottom if is_horizontal else .LeftToRight
	line_count := factories.disc_cols if is_horizontal else factories.disc_rows
	line_length := factories.disc_rows if is_horizontal else factories.disc_cols
	line_id := "DiscCol" if is_horizontal else "DiscRow"
	gap := FACTORY_GAP_IN_TILES * tile_size

	clay.Begin(
		{
			id = clay.ID("CenterPart"),
			layout = {
				layoutDirection = outer_direction,
				sizing = {
					width = clay.SizingFixed(total_w) if is_horizontal else clay.SizingGrow(),
					height = clay.SizingGrow() if is_horizontal else clay.SizingFixed(total_h),
				},
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = COLOR_BG_FACTORY_AREA,
		},
	)
	defer clay.End()

	for line in 0 ..< line_count {
		if line > 0 {
			ui_gap(gap, outer_direction)
		}
		clay.Begin(
			{
				id = clay.ID_LOCAL(line_id, u32(line)),
				layout = {
					layoutDirection = inner_direction,
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					childAlignment = {x = .Center, y = .Center},
				},
			},
		)
		defer clay.End()

		for cell in 0 ..< line_length {
			if cell > 0 {
				ui_gap(gap, inner_direction)
			}
			render_factory_cell(line * line_length + cell, factories, tile_size)
		}
	}
}

// Equal growing cells distribute the discs across the available central area.
render_factory_cell :: proc(disc_idx: int, factories: Factory_Layout, tile_size: f32) {
	clay.Begin(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				childAlignment = {x = .Center, y = .Center},
			},
		},
	)
	defer clay.End()

	render_factory_disc(disc_idx, factories, tile_size)
}
