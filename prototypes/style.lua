local styles = data.raw["gui-style"].default
local deepcopy = util.table.deepcopy

styles.UB_program_input = {
		type = "textbox_style",
		-- parent = "textbox",
		font = "default-mono",
		font_color = {r=0, g=0.9, b=0},
		disabled_font_color = {r=0, g=1, b=0},
		selection_background_color = {r=0.32, g=0.32, b=0.32},
		rich_text_setting = "disabled",
		minimal_height = 400,
		maximal_height = 0, -- not limited
		minimal_width = 590,
		natural_height = 0,
		natural_width = 0,
		maximal_width = 0,
		word_wrap = false,
		padding = 0,
		horizontally_stretchable = "on",
		vertically_stretchable = "on",
		active_background = {
			filename = "__useful_book__/graphics/black.png",
			width = 1, height = 1
		},
		default_background = {
			filename = "__useful_book__/graphics/input.png",
			width = 1, height = 1
		}
}


local slot_button = styles.slot_button
styles.UB_book_button = {
  type = "button_style",
	parent = "slot_button",
	tooltip = "mod-name.useful_book",
	default_graphical_set = deepcopy(slot_button.default_graphical_set),
	hovered_graphical_set = deepcopy(slot_button.hovered_graphical_set),
	clicked_graphical_set = deepcopy(slot_button.clicked_graphical_set)
}
local UB_book_button = styles.UB_book_button
UB_book_button.default_graphical_set.glow = {
	top_outer_border_shift = 4,
	bottom_outer_border_shift = -4,
	left_outer_border_shift = 4,
	right_outer_border_shift = -4,
	draw_type = "outer",
	filename = "__useful_book__/graphics/book.png",
	flags = {"gui-icon"},
	size = 32
}
UB_book_button.hovered_graphical_set.glow.center = {
	filename = "__useful_book__/graphics/book.png",
	flags = {"gui-icon"},
	size = 32
}
UB_book_button.clicked_graphical_set.glow = {
	top_outer_border_shift = 2,
	bottom_outer_border_shift = -2,
	left_outer_border_shift = 2,
	right_outer_border_shift = -2,
	draw_type = "outer",
	filename = "__useful_book__/graphics/book.png",
	flags = {"gui-icon"},
	size = 32
}
