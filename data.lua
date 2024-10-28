require("prototypes.style")


local inputs = {}
for i=1, 100 do
	inputs[#inputs+1] = {
		type  = "custom-input",
		name  = "UB_hotkey_" .. i,
		order = "ZUB_hotkey_" .. string.char(i),
		localised_name = {"useful_book.hotkey", tostring(i)},
		key_sequence = "",
		action = "lua",
	}
end
data:extend(inputs)


local GRAPHICS_PATH = "__useful_book__/graphics/"

data:extend{
	{
		type = "sprite", name = "UB_book",
		filename = GRAPHICS_PATH .. "book.png",
		width = 32, height = 32,
		flags = {"gui-icon"}
	}, {type = "font", name = "default-mono", from = "default-mono", size = 16}
}


local hotkey_name = "UB_get_admin_area_tool"
data:extend({
	{type = "custom-input", name = hotkey_name, key_sequence = "", consuming = "game-only"},
	{
		type = "selection-tool",
		name = "UB_admin_area_selection_tool",
		icon = "__useful_book__/graphics/book.png",
		icon_size = 32,
		flags = {"not-stackable", "only-in-cursor", "spawnable"},
		select = {
		  border_color = {1, 1, 1},
		  mode = {"blueprint"},
		  cursor_box_type = "copy",
		},
		alt_select = {
		  border_color = {0, 1, 0},
		  mode = {"blueprint"},
		  cursor_box_type = "copy",
		},
		hidden = true,
		icon_mipmaps = nil,
		subgroup = "tool",
		stack_size = 1,
		entity_filter_count = nil,
		tile_filter_count = nil,
		selection_color = {255, 145, 0},
		alt_selection_color = {239, 153, 34},
		selection_mode = {"any-entity"},
		alt_selection_mode = {"nothing"},
		selection_cursor_box_type = "entity",
		alt_selection_cursor_box_type = "not-allowed"
	}, {
		type = "shortcut",
		name = "UB_admin_area_tool_shortcut",
		action = "spawn-item",
		item_to_spawn = "UB_admin_area_selection_tool",
		associated_control_input = hotkey_name,
		small_icon = "__useful_book__/graphics/book.png",
		small_icon_size = 32,
		icon = "__useful_book__/graphics/book-24x.png",
		icon_size = 24,
		toggleable = true,
		style = "blue"
	}
})
