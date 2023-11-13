require("prototypes.style")


local inputs = {}
for i=1, 100 do
	inputs[#inputs+1] = {
		type  = "custom-input",
		name  = "UB_hotkey_" .. i,
		order = "ZUB_hotkey_" .. string.char(i),
		localised_name = {"useful_book.hotkey", i},
		key_sequence = "",
		action = "lua",
	}
end
data:extend(inputs)


local GRAPHICS_PATH = "__useful_book__/graphics/"

data:extend{
	{
		type = "sprite", name = "refresh",
		filename = GRAPHICS_PATH .. "refresh.png",
		width = 32, height = 32,
		flags = {"gui-icon"}
	}, {
		type = "sprite", name = "UB_book",
		filename = GRAPHICS_PATH .. "book.png",
		width = 32, height = 32,
		flags = {"gui-icon"}
	}, {
		type = "sprite", name = "plus_white",
		filename = GRAPHICS_PATH .. "plus_white.png",
		priority = "extra-high-no-scale",
		width = 32, height = 32,
		scale = 0.5,
		flags = {"gui-icon"}
	}, {
		type = "sprite", name = "plus",
		filename = GRAPHICS_PATH .. "plus.png",
		priority = "extra-high-no-scale",
		width = 32, height = 32,
		scale = 0.5,
		flags = {"gui-icon"}
	}, {
		type = "sprite", name = "lua_snippet_tool_icon_white",
		filename = GRAPHICS_PATH .. "run-snippet-tool-white.png",
		priority = "medium",
		width = 64, height = 64,
		mipmap_count = 3,
		flags = {"gui-icon"},
		scale = 0.5
	}, {
		type = "sprite", name = "map_exchange_string_white",
		filename = GRAPHICS_PATH .. "map-exchange-string-white.png",
		priority = "extra-high-no-scale",
		width = 32, height = 32,
		mipmap_count = 3,
		flags = {"gui-icon"},
		scale = 0.5
	}, {type = "font", name = "default-mono", from = "default-mono", size = 16}
}


local hotkey_name = "UB_get_admin_area_tool"
data:extend({
	{type = "custom-input", name = hotkey_name, key_sequence = "", consuming = "game-only"},
	{
		type = "selection-tool",
		name = "UB_admin_area_selection_tool",
		icons = {
			{icon = "__useful_book__/graphics/book.png"}
		},
		icon_size = 32,
		flags = {"hidden", "not-stackable", "only-in-cursor", "spawnable"},
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
		icon = {
			filename = "__useful_book__/graphics/book.png",
			priority = "low",
			size = 32,
			flags = {"gui-icon"}
		},
		toggleable = true,
		style = "blue"
	}
})
