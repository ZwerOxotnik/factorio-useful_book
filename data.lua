require("prototypes.style")
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
