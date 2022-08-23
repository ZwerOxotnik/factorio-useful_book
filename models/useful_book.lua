---@class UB : module
local M = {}


fun = require("lualib/fun")


is_server = false -- this is for rcon


--#region Global data
local mod_data
---@type table<integer, table>
local public_script_data
---@type table<integer, table>
local admin_script_data
---@type table<string, table>
local admin_area_script_data
---@type table<string, table>
local rcon_script_data
---@type table<string, table>
local custom_commands_data
---@type table<integer, string>
local players_admin_area_script
--#endregion

---@type table<integer, function>
local compiled_public_code = {}
---@type table<integer, function>
local compiled_admin_code = {}
---@type table<string, function>
local compiled_admin_area_code = {}
---@type table<string, function>
local compiled_rcon_code = {}
---@type table<string, function>
local compiled_commands_code = {}


--#region Constants
local print_to_rcon = rcon.print
local DEFAULT_TEXT = "local player = ...\nplayer.print(player.name)"
local DEFAULT_RCON_TEXT = "local data = ...\ngame.print(data)\nglobal.my_data = global.my_data or {data}\nif not is_server then return end -- be careful with it, it's different value for clients\nrcon.print(game.table_to_json(global.my_data))"
local DEFAULT_ADMIN_AREA_TEXT = "local area, player, entities = ...\n"
local DEFAULT_COMMAND_TEXT = [[
if event.player_index == 0 then -- stop this command if we got it via server console/rcon 
	print({"prohibited-server-command"})
	return
end
if player == nil then return end
if not player.admin then
	player.print({'command-output.parameters-require-admin'})
	return
end
player.print(player.name)
]]
local COLON = {"colon"}
local FLOW = {type = "flow"}
local LABEL = {type = "label"}
local EMPTY_WIDGET = {type = "empty-widget"}
local RED_COLOR = {1, 0, 0}
local CLOSE_BUTTON = {
	type = "sprite-button",
	name = "UB_close",
	style = "frame_action_button",
	sprite = "utility/close_white",
	hovered_sprite = "utility/close_black",
	clicked_sprite = "utility/close_black"
}
local BOOK_TYPES = {
	admin = 1,
	public = 2,
	rcon = 3,
	admin_area = 4,
	command = 5
}
local BOOK_TITLES = {
	[BOOK_TYPES.admin] = {"useful_book.admin_scripts"},
	[BOOK_TYPES.public] = {"useful_book.public_scripts"},
	[BOOK_TYPES.rcon] = {"useful_book.rcon_scripts"},
	[BOOK_TYPES.admin_area] = {"useful_book.admin_area_scripts"},
	[BOOK_TYPES.command] = {"useful_book.custom_commands"}
}
--#endregion


if script.mod_name ~= "useful_book" then
	remote.remove_interface("disable-useful_book")
	remote.add_interface("disable-useful_book", {})
end


--#region Function for RCON

-- /sc __useful_book__ getRconData("name")
---@param name string
function getRconData(name)
	print_to_rcon(game.table_to_json(mod_data[name]))
end

-- /sc __useful_book__ RunRCONScript("script name", ...)
---@param name string
---@param ... any #any data
function RunRCONScript(name, ...)
	local f = compiled_rcon_code[name]
	if f == nil then return end
	local is_ok, error = pcall(f, ...)
	if not is_ok then
		game.print(error, RED_COLOR)
	end
end

--#endregion


--#region utils


---@param json string
---@param player? table #LuaPlayer
---@return boolean
function import_scripts(json, player)
	local target = player or game

	local raw_data = game.json_to_table(json)
	if raw_data == nil then
		-- TODO: add localization
		target.print("It's not json data")
		return false
	end

	for _, data in pairs(raw_data.public or {}) do
		add_public_script(data.title, data.descripton, data.code, nil, data.version)
	end
	for _, data in pairs(raw_data.admin or {}) do
		add_admin_script(data.title, data.descripton, data.code, nil, data.version)
	end
	for name, data in pairs(raw_data.admin_area or {}) do
		add_admin_area_script(name, data.descripton, data.code, data.version)
	end
	for name, data in pairs(raw_data.rcon or {}) do
		add_rcon_script(name, data.descripton, data.code, data.version)
	end
	for name, data in pairs(raw_data.commands or {}) do
		add_new_command(name, data.descripton, data.code, data.version)
	end

	-- TODO: add localization
	target.print("Scripts has been imported for \"useful book\"")
	return true
end


---@param _ nil
---@param player table #LuaPlayer
function open_import_frame(_, player)
	local screen = player.gui.screen
	if screen.UB_import_frame then
		return
	end

	local main_frame = screen.add{
		type = "frame",
		name = "UB_import_frame",
		direction = "vertical"
	}
	main_frame.auto_center = true

	local footer = main_frame.add(FLOW)
	footer.add{
		type = "label",
		style = "frame_title",
		caption = {"gui-blueprint-library.import-string"},
		ignored_by_interaction = true
	}
	local drag_handler = footer.add{type = "empty-widget", style = "draggable_space"}
	drag_handler.drag_target = main_frame
	drag_handler.style.right_margin = 0
	drag_handler.style.horizontally_stretchable = true
	drag_handler.style.height = 32
	footer.add(CLOSE_BUTTON)

	local textfield = main_frame.add{
		type = "text-box",
		name = "UB_text_for_import",
		style = "UB_program_input"
	}
	textfield.word_wrap = true
	textfield.style.height = player.display_resolution.height * 0.6 / player.display_scale
	textfield.style.width = player.display_resolution.width * 0.6 / player.display_scale
	local flow = main_frame.add{type = "flow", direction = "horizontal", style = "dialog_buttons_horizontal_flow"}
	local pusher = flow.add{type = "empty-widget", style = "draggable_space"}
	pusher.style.horizontally_stretchable = true
	pusher.style.vertically_stretchable = true
	pusher.drag_target = main_frame
	local confirm_button = flow.add{
		type = "button",
		name = "UB_import",
		caption = {"gui-blueprint-library.import"},
		style = "confirm_button"
	}
	confirm_button.style.minimal_width = 250
end

function reset_scripts()
	mod_data.admin_script_data = {}
	admin_script_data = mod_data.admin_script_data
	mod_data.public_script_data = {}
	public_script_data = mod_data.public_script_data
	mod_data.admin_area_script_data = {}
	admin_area_script_data = mod_data.admin_area_script_data
	mod_data.rcon_script_data = {}
	rcon_script_data = mod_data.rcon_script_data
	mod_data.custom_commands_data = {}
	custom_commands_data = mod_data.custom_commands_data
	ompiled_admin_code = {}
	compiled_public_code = {}
	compiled_admin_area_code = {}
	compiled_rcon_code = {}
	compiled_commands_code = {}
	add_admin_script(
		{"scripts-titles.reveal-gen-map"},
		{"scripts-description.reveal-gen-map"},
		"local player = ...\nplayer.force.chart_all()"
	)
	add_admin_script(
		{"scripts-titles.kill-all-enemies"},
		{"scripts-description.kill-all-enemies"},
		'local player = ...\
		local raise_destroy = {raise_destroy=true}\
		local entities = player.surface.find_entities_filtered({force="enemy"})\
		for i=1, #entities do\
			entities[i].destroy(raise_destroy)\
		end'
	)
	add_admin_script(
		{"scripts-titles.kill-half-enemies"},
		{"scripts-description.kill-half-enemies"},
		'local player = ...\
		local raise_destroy = {raise_destroy=true}\
		local entities = player.surface.find_entities_filtered({force="enemy"})\
		for i=1, #entities, 2 do\
			entities[i].destroy(raise_destroy)\
		end'
	)
	add_admin_script(
		{"scripts-titles.reg-resources"},
		{"scripts-description.reg-resources"},
		'local player = ...\n\
		local surface = player.surface\
		local raise_destroy = {raise_destroy=true}\
		local entities = surface.find_entities_filtered{type="resource"}\
		for i=1, #entities do\
			local e = entities[i]\
			if e.prototype.infinite_resource then\
				e.amount = e.initial_amount\
			else\
				e.destroy(raise_destroy)\
			end\
		end\
		local non_infinites = {}\
		for resource, prototype in pairs(game.get_filtered_entity_prototypes{{filter="type", type="resource"}}) do\
			if not prototype.infinite_resource then\
				non_infinites[#non_infinites+1] = resource\
			end\
		end\
		surface.regenerate_entity(non_infinites)\
		entities = surface.find_entities_filtered{type="mining-drill"}\
		for i=1, #entities do\
			entities[i].update_connections()\
		end'
	)
	add_rcon_script(
		"Print Twitch message", "",
		'local username, message = ...\
		game.print({"", "[color=purple][Twitch][/color] ", username, {"colon"}, " ", message})'
	)
	add_admin_area_script(
		"Indestructible",
		'Makes selected entities indestructible',
		'local _, _, entities = ...\
		for i=1, #entities do\
			local entity = entities[i]\
			if entity.valid then\
				entity.destructible = false\
			end\
		end'
	)
	add_admin_area_script(
		"Destroy",
		'Destroys selected entities safely',
		'local _, _, entities = ...\
		local raise_destroy = {raise_destroy=true}\
		for i=1, #entities do\
			local entity = entities[i]\
			if entity.valid and not entity.is_player() then\
				entity.destroy(raise_destroy)\
			end\
		end'
	)
	for _, player in pairs(game.players) do
		if player.valid and player.admin then
			-- TODO: add localization
			player.print("Scripts has been reset for \"useful book\"")
		end
	end
end

---@param player table #LuaPlayer
function close_admin_area_scripts_frame(player)
	local frame = player.gui.screen.UB_admin_area_scripts_frame
	if frame then
		frame.destroy()
		players_admin_area_script[player.index] = nil
	end
end

---@param player table #LuaPlayer
function open_admin_area_scripts_frame(player)
	local screen = player.gui.screen
	if screen.UB_admin_area_scripts_frame then
		return
	end

	local main_frame = screen.add{
		type = "frame",
		name = "UB_admin_area_scripts_frame",
		caption = {"useful_book.admin_area_scripts"},
		direction = "vertical"
	}
	main_frame.auto_center = true

	local footer = main_frame.add(FLOW)
	local drag_handler = footer.add{type = "empty-widget", style = "draggable_space"}
	drag_handler.drag_target = main_frame
	drag_handler.style.right_margin = 0
	drag_handler.style.horizontally_stretchable = true
	drag_handler.style.height = 32

	local items = {}
	for name in pairs(admin_area_script_data) do
		items[#items+1] = name
	end

	main_frame.add{
		type = "drop-down", name = "UB_admin_area_scripts_drop_down",
		items = items
	}
end


-- Replaces tabulation with 2 spaces and removes unnecessary spaces
---@param code string
---@return string #code
function format_code(code)
	---@diagnostic disable-next-line: redundant-return-value
	return code:gsub("[ ]+\n", "\n"):gsub("\t", "  ")
end
DEFAULT_COMMAND_TEXT = format_code(DEFAULT_COMMAND_TEXT)


---@param code string
---@return function
function format_command_code(code)
	local new_code = "local function custom_command(event, player) " .. code .. "\nend\n"
	-- TODO: improve the error message!
	-- Should I prohibit access to some global variables
	-- and make them a bit different for the command?
	local new_code2 = [[return function(event)
		game.print(serpent.block(event))
		local player = game.get_player(event.player_index)
		if not (player and player.valid) then
			player = nil
		end
		local is_ok, error = pcall(custom_command, event, player)
		if not is_ok then
			player.print(error, {1, 0, 0})
		end
	end
	]]

	---@diagnostic disable-next-line: return-type-mismatch
	return load(new_code .. new_code2)()
end


---@param title string|LocalisedString
---@param description? string|LocalisedString
---@param code string
---@param id number?
---@param version string?
---@return integer? #id
function add_admin_script(title, description, code, id, version)
	code = format_code(code)
	local f = load(code)
	if type(f) ~= "function" then return end

	if id == nil then
		id = mod_data.last_admin_id + 1
		mod_data.last_admin_id = id
	end
	compiled_admin_code[id] = f
	admin_script_data[id] = {
		description = description,
		title = title,
		code = code,
		version = version or script.active_mods.useful_book
	}
	return id
end


---@param title string|LocalisedString
---@param description? string|LocalisedString
---@param code string
---@param id number?
---@param version string?
---@return integer? #id
function add_public_script(title, description, code, id, version)
	code = format_code(code)
	local f = load(code)
	if type(f) ~= "function" then return end

	if id == nil then
		id = mod_data.last_public_id + 1
		mod_data.last_public_id = id
	end
	compiled_public_code[id] = f
	public_script_data[id] = {
		description = description,
		title = title,
		code = code,
		version = version or script.active_mods.useful_book
	}
	return id
end


---@param name string
---@param description? string
---@param code string
---@param version string?
function add_admin_area_script(name, description, code, version)
	code = format_code(code)
	local f = load(code)
	if type(f) ~= "function" then return end

	compiled_admin_area_code[name] = f
	admin_area_script_data[name] = {
		description = description,
		code = code,
		version = version or script.active_mods.useful_book
	}
end


---@param name string
---@param description? string
---@param code string
---@param version string?
function add_rcon_script(name, description, code, version)
	code = format_code(code)
	local f = load(code)
	if type(f) ~= "function" then return end

	compiled_rcon_code[name] = f
	rcon_script_data[name] = {
		description = description,
		code = code,
		version = version or script.active_mods.useful_book
	}
end


---@param name string
---@param description? string
---@param code string
---@param version string?
function add_new_command(name, description, code, version)
	code = format_code(code)
	if type(load(code)) ~= "function" then return end

	custom_commands_data[name] = {
		description = description,
		code = code,
		version = version or script.active_mods.useful_book
	}
	if not commands.commands[name] and not commands.game_commands[name] then
		custom_commands_data[name].is_added = true
		local f = format_command_code(code)
		compiled_commands_code[name] = f
		commands.add_command(name, description or '', f)
	else
		custom_commands_data[name].is_added = false
	end
end

local function destroy_GUI_event(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	close_admin_area_scripts_frame(player)
	local screen = player.gui.screen
	if screen.UB_book_frame then
		screen.UB_book_frame.destroy()
	end
	if screen.UB_code_editor then
		screen.UB_code_editor.destroy()
	end
	if screen.UB_import_frame then
		screen.UB_import_frame.destroy()
	end
end


---@param player table #LuaPlayer
---@param book_type integer
---@param id? integer|string
function switch_code_editor(player, book_type, id)
	local screen = player.gui.screen
	if screen.UB_code_editor then
		screen.UB_code_editor.destroy()
		return
	end

	local data
	if id then
		if book_type == BOOK_TYPES.public then
			data = public_script_data[id]
		elseif book_type == BOOK_TYPES.admin then
			data = admin_script_data[id]
		elseif book_type == BOOK_TYPES.admin_area then
			data = admin_area_script_data[id]
		elseif book_type == BOOK_TYPES.command then
			data = custom_commands_data[id]
		else -- rcon
			data = rcon_script_data[id]
		end
	end

	local main_frame = screen.add{type = "frame", name = "UB_code_editor", direction = "vertical"}
	local footer = main_frame.add(FLOW)
	footer.add{
		type = "label",
		style = "frame_title",
		caption = {"useful_book.code_editor"},
		ignored_by_interaction = true
	}
	local drag_handler = footer.add{type = "empty-widget", style = "draggable_space"}
	drag_handler.drag_target = main_frame
	drag_handler.style.right_margin = 0
	drag_handler.style.horizontally_stretchable = true
	drag_handler.style.height = 32
	footer.add(CLOSE_BUTTON)

	local flow = main_frame.add(FLOW)
	flow.name = "buttons_row"
	local content = {type = "sprite-button"}
	content.name = "UB_check_code"
	content.sprite = "refresh"
	flow.add(content)
	content.name = "UB_add_code"
	content.sprite = "plus_white"
	flow.add(content).visible = false
	if book_type ~= BOOK_TYPES.rcon and book_type ~= BOOK_TYPES.admin_area and book_type ~= BOOK_TYPES.command then
		flow.add{type = "label", caption = {'', {"useful_book.is_public_script"}, COLON}}
	end
	local UB_is_public_script = flow.add{type = "checkbox", name = "UB_is_public_script", state = (book_type == BOOK_TYPES.public), enabled = id and false}
	if book_type == BOOK_TYPES.rcon or book_type == BOOK_TYPES.admin_area or book_type == BOOK_TYPES.command then
		UB_is_public_script.visible = false
	end
	flow.add{type = "checkbox", name = "UB_is_rcon_script", state = (book_type == BOOK_TYPES.rcon), visible = false}
	flow.add{type = "checkbox", name = "UB_is_admin_area_script", state = (book_type == BOOK_TYPES.admin_area), visible = false}
	flow.add{type = "checkbox", name = "UB_is_command", state = (book_type == BOOK_TYPES.command), visible = false}
	if id then
		local label = flow.add{type = "label", name = "id", visible = false}
		if book_type == BOOK_TYPES.rcon or book_type == BOOK_TYPES.admin_area or book_type == BOOK_TYPES.command then
			label.caption = id
		else
			label.caption = tonumber(id)
		end
	end

	main_frame.add({type = "label", name = "error_message", style = "bold_red_label", visible = false})

	local scroll_pane = main_frame.add{type = "scroll-pane", name = "scroll_pane"}
	flow = scroll_pane.add(FLOW)
	flow.name = "UB_title"
	local title_label = flow.add(LABEL)
	-- TODO: add localization!
	if book_type == BOOK_TYPES.command then
		title_label.caption = {'', "Command name", COLON}
	else
		title_label.caption = {'', "Title", COLON}
	end

	local is_text = (data == nil) or (data.title == nil or type(data.title) == "string")
	if is_text then
		local textfield = flow.add{type = "textfield", name = "textfield"}
		if book_type == BOOK_TYPES.rcon or book_type == BOOK_TYPES.admin_area or book_type == BOOK_TYPES.command then
			textfield.text = id or ''
		else
			textfield.text = data and data.title or ''
		end
		textfield.style.horizontally_stretchable = true
		textfield.style.maximal_width = 0
	else
		flow.add{type = "label", name = "textfield", caption = data.title}
	end

	is_text = (data == nil) or (type(data.title) == "string")
	if is_text then
		scroll_pane.add(LABEL).caption = {'', "Description", COLON}
		local text_box = scroll_pane.add{type = "text-box", name = "UB_description"}
		text_box.text = data and data.description or ''
		text_box.style.horizontally_stretchable = true
		text_box.style.maximal_width = 0
		text_box.style.height = 90
	else
		scroll_pane.add{type = "label", name = "UB_description", caption = data.title, visible = false}
	end

	local input = scroll_pane.add{type = "text-box", name = "UB_program_input", style = "UB_program_input"}
	if book_type == BOOK_TYPES.rcon then
		input.text = data and data.code or DEFAULT_RCON_TEXT
	elseif book_type == BOOK_TYPES.admin_area then
		input.text = data and data.code or DEFAULT_ADMIN_AREA_TEXT
	elseif book_type == BOOK_TYPES.command then
		input.text = data and data.code or DEFAULT_COMMAND_TEXT
	else
		input.text = data and data.code or DEFAULT_TEXT
	end
	main_frame.force_auto_center()
end

local function fill_with_public_data(table_element, player)
	local RUN_BUTTON = {
		type = "sprite-button",
		name = "UB_run_public_script",
		style = "frame_action_button",
		sprite = "lua_snippet_tool_icon_white",
		hovered_sprite = "utility/lua_snippet_tool_icon",
		clicked_sprite = "utility/lua_snippet_tool_icon"
	}
	local CHANGE_BUTTON = {
		type = "sprite-button",
		name = "UB_change_public_script",
		style = "frame_action_button",
		sprite = "map_exchange_string_white",
		hovered_sprite = "utility/map_exchange_string",
		clicked_sprite = "utility/map_exchange_string"
	}
	local DELETE_BUTTON = {
		type = "sprite-button",
		name = "UB_delete_public_code",
		style = "frame_action_button",
		sprite = "utility/trash_white",
		hovered_sprite = "utility/trash",
		clicked_sprite = "utility/trash"
	}
	local label, flow
	for id, data in pairs(public_script_data) do
		label = table_element.add(LABEL)
		label.tooltip = data.description or ''
		label.caption = data.title
		flow = table_element.add(FLOW)
		flow.name = tostring(id)
		flow.add(RUN_BUTTON)
		if player.admin then
			flow.add(CHANGE_BUTTON)
			flow.add(DELETE_BUTTON)
		end
	end
end

local function fill_with_admin_data(table_element)
	local RUN_BUTTON = {
		type = "sprite-button",
		name = "UB_run_admin_code",
		style = "frame_action_button",
		sprite = "lua_snippet_tool_icon_white",
		hovered_sprite = "utility/lua_snippet_tool_icon",
		clicked_sprite = "utility/lua_snippet_tool_icon"
	}
	local DELETE_BUTTON = {
		type = "sprite-button",
		name = "UB_delete_admin_code",
		style = "frame_action_button",
		sprite = "utility/trash_white",
		hovered_sprite = "utility/trash",
		clicked_sprite = "utility/trash"
	}
	local CHANGE_BUTTON = {
		type = "sprite-button",
		name = "UB_change_admin_code",
		style = "frame_action_button",
		sprite = "map_exchange_string_white",
		hovered_sprite = "utility/map_exchange_string",
		clicked_sprite = "utility/map_exchange_string"
	}
	local label, flow
	for id, data in pairs(admin_script_data) do
		label = table_element.add(LABEL)
		label.tooltip = data.description or ''
		label.caption = data.title
		flow = table_element.add(FLOW)
		flow.name = tostring(id)
		flow.add(RUN_BUTTON)
		flow.add(CHANGE_BUTTON)
		flow.add(DELETE_BUTTON)
	end
end

local function fill_with_admin_area_data(table_element)
	local DELETE_BUTTON = {
		type = "sprite-button",
		name = "UB_delete_admin_area_code",
		style = "frame_action_button",
		sprite = "utility/trash_white",
		hovered_sprite = "utility/trash",
		clicked_sprite = "utility/trash"
	}
	local CHANGE_BUTTON = {
		type = "sprite-button",
		name = "UB_change_admin_area_code",
		style = "frame_action_button",
		sprite = "map_exchange_string_white",
		hovered_sprite = "utility/map_exchange_string",
		clicked_sprite = "utility/map_exchange_string"
	}
	local label, flow
	for name, data in pairs(admin_area_script_data) do
		label = table_element.add(LABEL)
		label.tooltip = data.description or ''
		label.caption = name
		flow = table_element.add(FLOW)
		flow.name = name
		flow.add(CHANGE_BUTTON)
		flow.add(DELETE_BUTTON)
	end
end

local function fill_with_rcon_data(table_element)
	local DELETE_BUTTON = {
		type = "sprite-button",
		name = "UB_delete_rcon_code",
		style = "frame_action_button",
		sprite = "utility/trash_white",
		hovered_sprite = "utility/trash",
		clicked_sprite = "utility/trash"
	}
	local CHANGE_BUTTON = {
		type = "sprite-button",
		name = "UB_change_rcon_code",
		style = "frame_action_button",
		sprite = "map_exchange_string_white",
		hovered_sprite = "utility/map_exchange_string",
		clicked_sprite = "utility/map_exchange_string"
	}
	local label, flow
	for name, data in pairs(rcon_script_data) do
		label = table_element.add(LABEL)
		label.tooltip = data.description or ''
		label.caption = name
		flow = table_element.add(FLOW)
		flow.name = name
		flow.add(CHANGE_BUTTON)
		flow.add(DELETE_BUTTON)
	end
end

local function fill_with_custom_commands_data(table_element)
	local DELETE_BUTTON = {
		type = "sprite-button",
		name = "UB_delete_custom_command",
		style = "frame_action_button",
		sprite = "utility/trash_white",
		hovered_sprite = "utility/trash",
		clicked_sprite = "utility/trash"
	}
	local CHANGE_BUTTON = {
		type = "sprite-button",
		name = "UB_change_command_code",
		style = "frame_action_button",
		sprite = "map_exchange_string_white",
		hovered_sprite = "utility/map_exchange_string",
		clicked_sprite = "utility/map_exchange_string"
	}
	local label, flow
	for name, data in pairs(custom_commands_data) do
		label = table_element.add(LABEL)
		label.tooltip = data.description or ''
		label.caption = name
		flow = table_element.add(FLOW)
		flow.name = name
		flow.add(CHANGE_BUTTON)
		flow.add(DELETE_BUTTON)
	end
end


---@param player table #LuaPlayer
---@param book_type integer
function switch_book(player, book_type)
	local screen = player.gui.screen
	if screen.UB_book_frame then
		screen.UB_book_frame.destroy()
	end

	local main_frame = screen.add{type = "frame", name = "UB_book_frame", direction = "vertical"}
	main_frame.style.minimal_width = 260
	local footer = main_frame.add(FLOW)
	footer.add{
		type = "label",
		style = "frame_title",
		caption = {"mod-name.useful_book"},
		ignored_by_interaction = true
	}
	local drag_handler = footer.add{type = "empty-widget", style = "draggable_space"}
	drag_handler.drag_target = main_frame
	drag_handler.style.right_margin = 0
	drag_handler.style.horizontally_stretchable = true
	drag_handler.style.height = 32
	if player.admin then
		footer.add{
			type = "sprite-button",
			name = "UB_open_import",
			sprite = "utility/import", -- TODO: add white button
			tooltip = {"gui-blueprint-library.import-string"},
			style = "frame_action_button"
		}
		footer.add{
			type = "sprite-button",
			name = "UB_open_code_editor",
			style = "frame_action_button",
			sprite = "plus_white",
			hovered_sprite = "plus",
			clicked_sprite = "plus"
		}
	end
	footer.add(CLOSE_BUTTON)

	local content_table = main_frame.add{type = "table", name = "content_table", column_count = 3}
	content_table.add(EMPTY_WIDGET).style.horizontally_stretchable = true

	content_table.add(LABEL).caption = BOOK_TITLES[book_type]
	if player.admin then
		local sub_flow = content_table.add(FLOW)
		sub_flow.name = "nav_flow"
		sub_flow.style.horizontally_stretchable = true
		sub_flow.add{
			type = "drop-down", name = "UB_book_type",
			items = BOOK_TITLES,
			selected_index = book_type or 1
		}
		sub_flow.add{
			type = "sprite-button",
			name = "UB_update_book",
			style = "frame_action_button",
			sprite = "utility/reset_white",
			hovered_sprite = "utility/reset",
			clicked_sprite = "utility/reset"
		}
	else
		content_table.add(EMPTY_WIDGET).style.horizontally_stretchable = true
	end

	local scroll_pane = main_frame.add{type = "scroll-pane", name = "scroll_pane"}
	local scripts_table = scroll_pane.add{type = "table", column_count = 2}
	if book_type == BOOK_TYPES.public then
		fill_with_public_data(scripts_table, player)
	elseif book_type == BOOK_TYPES.admin then
		fill_with_admin_data(scripts_table)
	elseif book_type == BOOK_TYPES.admin_area then
		fill_with_admin_area_data(scripts_table)
	elseif book_type == BOOK_TYPES.command then
		fill_with_custom_commands_data(scripts_table)
	else -- rcon
		fill_with_rcon_data(scripts_table)
	end

	main_frame.force_auto_center()
end

local left_anchor = {gui = defines.relative_gui_type.controller_gui, position = defines.relative_gui_position.left}
local function create_left_relative_gui(player)
	local relative = player.gui.relative
	if relative.UB_book then
		return
	end

	relative.add{
		type = "sprite-button",
		name = "UB_book",
		style = "UB_book_button", -- see prototypes/style.lua
		anchor = left_anchor
	}
end

--#endregion


--#region Events

local function on_player_created(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end
	create_left_relative_gui(player)
end

local function on_gui_text_changed(event)
	local element = event.element
	if not (element and element.valid) then return end
	if element.name ~= "UB_program_input" then return end

	local button = element.parent.parent.buttons_row.UB_run_code
	if button then
		button.name = "UB_check_code"
		button.sprite = "refresh"
		button.hovered_sprite = ''
		button.clicked_sprite = ''
		button = element.parent.parent.buttons_row.UB_add_code
		button.visible = false
	end
end

local GUIS = {
	UB_close = function(element)
		element.parent.parent.destroy()
	end,
	UB_book = function(element, player, event)
		if player.admin then
			if event.control then
				switch_code_editor(player, (event.shift and BOOK_TYPES.admin) or BOOK_TYPES.public)
			else
				switch_book(player, (event.shift and BOOK_TYPES.admin) or BOOK_TYPES.public)
			end
		else
			local UB_book_frame = player.gui.screen.UB_book_frame
			if UB_book_frame then
				UB_book_frame.destroy()
			else
				if next(public_script_data) == nil then
					player.print({"useful_book.no-public-scripts"})
				else
					switch_book(player, BOOK_TYPES.public)
				end
			end
		end
	end,
	UB_run_public_script = function(element, player)
		local id = tonumber(element.parent.name)
		local f = compiled_public_code[id]
		if f then
			local is_ok, error = pcall(f, player)
			if not is_ok then
				player.print(error, RED_COLOR)
			end
		else
			local flow = element.parent
			flow.parent.children[flow.get_index_in_parent() - 1].destroy()
			flow.destroy()
			player.print({"useful_book.script-had-been-deleted"})
		end
	end,
	UB_run_admin_code = function(element, player)
		local id = tonumber(element.parent.name)
		local f = compiled_admin_code[id]
		if f then
			local is_ok, error = pcall(f, player)
			if not is_ok then
				player.print(error, RED_COLOR)
			end
		else
			local flow = element.parent
			flow.parent.children[flow.get_index_in_parent() - 1].destroy()
			flow.destroy()
			player.print({"useful_book.script-had-been-deleted"})
		end
	end,
	UB_delete_public_code = function(element, player)
		local id = tonumber(element.parent.name)
		---@cast id number
		public_script_data[id] = nil
		compiled_public_code[id] = nil
		local flow = element.parent
		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()
	end,
	UB_delete_admin_code = function(element, player)
		local id = tonumber(element.parent.name)
		---@cast id number
		admin_script_data[id] = nil
		compiled_admin_code[id] = nil
		local flow = element.parent
		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()
	end,
	UB_delete_admin_area_code = function(element, player)
		local name = element.parent.name
		admin_area_script_data[name] = nil
		compiled_admin_area_code[name] = nil
		local flow = element.parent
		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()
	end,
	UB_delete_rcon_code = function(element, player)
		local name = element.parent.name
		rcon_script_data[name] = nil
		compiled_rcon_code[name] = nil
		local flow = element.parent
		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()
	end,
	UB_delete_custom_command = function(element, player)
		local name = element.parent.name
		commands.remove_command(name)
		custom_commands_data[name] = nil
		if compiled_commands_code[name] then -- there's something weird about Factorio lua, so I shouldn't nil twice
			compiled_commands_code[name] = nil
		end
		local flow = element.parent
		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()
	end,
	UB_change_public_script = function(element, player)
		switch_code_editor(player, BOOK_TYPES.public, tonumber(element.parent.name))
	end,
	UB_change_admin_code = function(element, player)
		switch_code_editor(player, BOOK_TYPES.admin, tonumber(element.parent.name))
	end,
	UB_change_admin_area_code = function(element, player)
		switch_code_editor(player, BOOK_TYPES.admin_area, element.parent.name)
	end,
	UB_change_rcon_code = function(element, player)
		switch_code_editor(player, BOOK_TYPES.rcon, element.parent.name)
	end,
	UB_change_command_code = function(element, player)
		switch_code_editor(player, BOOK_TYPES.command, element.parent.name)
	end,
	UB_open_code_editor = function(element, player)
		local UB_book_frame = element.parent.parent
		local book_type = UB_book_frame.content_table.nav_flow.UB_book_type.selected_index
		UB_book_frame.destroy()
		switch_code_editor(player, book_type)
	end,
	UB_add_code = function(element, player)
		local title, description, code
		local flow = element.parent
		local main_frame = flow.parent
		local UB_description = main_frame.scroll_pane.UB_description
		local is_description_visible = UB_description.visible
		if is_description_visible then
			title = main_frame.scroll_pane.UB_title.textfield.text
			if title == '' then
				player.print({"useful_book.no-title"})
				return
			end
		else
			title = main_frame.scroll_pane.UB_title.textfield.caption
		end
		code = main_frame.scroll_pane.UB_program_input.text
		if code == '' then
			player.print({"useful_book.no-code"})
			return
		end

		if is_description_visible then
			description = UB_description.text
			if description == '' then
				description = nil
			end
		else
			if type(UB_description.caption) ~= "string" then
				description = UB_description.caption
			else
				description = UB_description.caption
				if description == '' then
					description = nil
				end
			end
		end
		local UB_is_public_script = flow.UB_is_public_script
		local UB_is_rcon_script = flow.UB_is_rcon_script
		local UB_is_admin_area_script = flow.UB_is_admin_area_script
		local UB_is_command = flow.UB_is_command
		local book_type
		if UB_is_public_script.state then
			book_type = BOOK_TYPES.public
		elseif UB_is_admin_area_script.state then
			book_type = BOOK_TYPES.admin_area
		elseif UB_is_rcon_script.state then
			book_type = BOOK_TYPES.rcon
		elseif UB_is_command.state then
			book_type = BOOK_TYPES.command
		else
			book_type = BOOK_TYPES.admin
		end
		local is_enabled = UB_is_public_script.enabled
		if not is_enabled then
			-- TODO: RECHECK
			if book_type == BOOK_TYPES.admin then
				local id = tonumber(flow.id.caption)
				---@cast id number
				add_admin_script(title, description, code, id)
			elseif book_type == BOOK_TYPES.public then
				local id = tonumber(flow.id.caption)
				---@cast id number
				add_public_script(title, description, code, id)
			elseif book_type == BOOK_TYPES.admin_area then
				local name = flow.id.caption
				add_admin_area_script(name, description, code)
			elseif book_type == BOOK_TYPES.command then
				local name = flow.id.caption
				add_new_command(name, description, code)
			else -- rcon
				local name = flow.id.caption
				add_rcon_script(name, description, code)
			end
		else
			if book_type == BOOK_TYPES.admin then
				add_admin_script(title, description, code)
			elseif book_type == BOOK_TYPES.public then
				add_public_script(title, description, code)
			elseif book_type == BOOK_TYPES.admin_area then
				add_admin_area_script(title, description, code)
			elseif book_type == BOOK_TYPES.command then
				add_new_command(title, description, code)
			else -- rcon
				add_rcon_script(title, description, code)
			end
		end
		element.parent.parent.destroy()
		switch_book(player, book_type)
	end,
	UB_run_code = function(element, player)
		local parent = element.parent
		local is_command = parent.UB_is_command.state
		local scroll_pane = parent.parent.scroll_pane
		local code = scroll_pane.UB_program_input.text
		local is_ok, error
		-- TODO: change for rcon!
		if is_command then
			local fake_event_data = {
				player_index = player.index,
				tick = game.tick,
				name = scroll_pane.UB_title.textfield.text
			}
			is_ok, error = pcall(
				load("local event = " .. serpent.line(fake_event_data) .. "local player = game.get_player(event.player_index) " .. code),
					fake_event_data, player
				)
		else
			is_ok, error = pcall(load(code), player)
		end
		if is_ok then return end

		local flow = element.parent
		local main_frame = flow.parent
		local error_message = main_frame.error_message
		error_message.caption = error
		error_message.visible = true
		flow.UB_add_code.visible = false
		element.name = "UB_check_code"
		element.sprite = "refresh"
		element.hovered_sprite = ''
		element.clicked_sprite = ''
	end,
	UB_check_code = function(element, player)
		local flow = element.parent
		local main_frame = flow.parent
		local f = load(main_frame.scroll_pane.UB_program_input.text)
		if type(f) == "function" then
			if flow.UB_is_rcon_script.state == false then
				element.name = "UB_run_code"
				element.sprite = "lua_snippet_tool_icon_white"
				element.hovered_sprite = "utility/lua_snippet_tool_icon"
				element.clicked_sprite = "utility/lua_snippet_tool_icon"
			end
			element.parent.UB_add_code.visible = true
			local error_message = main_frame.error_message
			error_message.caption = nil
			error_message.visible = false
		else
			local error_message = main_frame.error_message
			error_message.caption = {"useful_book.cant-compile"}
			error_message.visible = true
		end
	end,
	UB_import = function(element, player)
		local UB_import_frame = element.parent.parent
		if not player.admin then
			-- TODO: add message
			UB_import_frame.destroy()
			return
		end

		if import_scripts(UB_import_frame.UB_text_for_import.text, player) then
			UB_import_frame.destroy()
		end
	end,
	UB_update_book = function(element, player)
		local parent = element.parent
		local book_type = parent.UB_book_type.selected_index
		parent.parent.parent.destroy()
		switch_book(player, book_type)
	end,
	UB_open_import = open_import_frame
}
local function on_gui_click(event)
	local element = event.element
	if not (element and element.valid) then return end

	local f = GUIS[element.name]
	if f then
		f(element, game.get_player(event.player_index), event)
	end
end

local function on_player_selected_area(event)
	local entities = event.entities
	if #entities == 0 then return end
	if event.item ~= "UB_admin_area_selection_tool" then return end
	local player_index = event.player_index
	local script_name = players_admin_area_script[player_index]
	if script_name == nil then return end
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end
	if not player.admin then
		player.print({"command-output.parameters-require-admin"})
		return
	end

	local f = compiled_admin_area_code[script_name]
	if f == nil then
		player.print("Such script doesn't exist anymore") -- TODO: add localization
		return
	end
	local is_ok, error = pcall(f, event.area, player, entities)
	if not is_ok then
		player.print(error, RED_COLOR)
	end
end

local function on_player_cursor_stack_changed(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end
	local cursor_stack = player.cursor_stack
	if cursor_stack.valid_for_read
		and player.admin
		and cursor_stack.name == "UB_admin_area_selection_tool"
	then
		open_admin_area_scripts_frame(player)
		return
	end
	close_admin_area_scripts_frame(player)
end

--#endregion


--#region Pre-game stage

local function compile_all_text()
	for id, data in pairs(admin_script_data or {}) do
		compiled_admin_code[id] = load(data.code)
	end
	for id, data in pairs(public_script_data or {}) do
		compiled_public_code[id] = load(data.code)
	end
	for name, data in pairs(admin_area_script_data or {}) do
		compiled_admin_area_code[name] = load(data.code)
	end
	for name, data in pairs(rcon_script_data or {}) do
		compiled_rcon_code[name] = load(data.code)
	end
	for name, data in pairs(custom_commands_data or {}) do
		if data.is_added then
			custom_commands_data[name].is_added = true
			local f = format_command_code(data.code)
			compiled_commands_code[name] = f
			commands.add_command(data.name, data.description or '', f) -- Perhaps, I should do something about other cases
		end
	end
end

local function link_data()
	mod_data = global.useful_book
	public_script_data = mod_data.public_script_data
	admin_script_data = mod_data.admin_script_data
	admin_area_script_data = mod_data.admin_area_script_data
	rcon_script_data = mod_data.rcon_script_data
	custom_commands_data = mod_data.custom_commands_data
	players_admin_area_script = mod_data.players_admin_area_script
end

local function update_global_data()
	global.useful_book = global.useful_book or {}
	mod_data = global.useful_book
	mod_data.public_script_data = mod_data.public_script_data or {}
	mod_data.admin_script_data = mod_data.admin_script_data or {}
	mod_data.admin_area_script_data = mod_data.admin_area_script_data or {}
	mod_data.rcon_script_data = mod_data.rcon_script_data or {}
	mod_data.custom_commands_data = mod_data.custom_commands_data or {}
	mod_data.players_admin_area_script = {}
	mod_data.last_public_id = mod_data.last_public_id or 0
	mod_data.last_admin_id = mod_data.last_admin_id or 0

	link_data()

	for _, player in pairs(game.players) do
		if player.valid then
			if player.gui.relative.UB_book == nil then
				create_left_relative_gui(player)
			end
		end
	end

	compile_all_text()
end

M.on_init = function()
	update_global_data()
	local UB_json_data = settings.global.UB_json_data.value
	if UB_json_data == '' then
		reset_scripts()
	else
		import_scripts(UB_json_data)
	end
end

M.on_configuration_changed = function(event)
	update_global_data()

	local mod_changes = event.mod_changes["useful_book"]
	if not (mod_changes and mod_changes.old_version) then return end

	local version = tonumber(string.gmatch(mod_changes.old_version, "%d+.%d+")())

	if version < 0.17 then
		for _, data in pairs(public_script_data) do
			data.version = data.version or "0.16.2"
		end
		for _, data in pairs(admin_script_data) do
			data.version = data.version or "0.16.2"
		end
		for _, data in pairs(admin_area_script_data) do
			data.version = data.version or "0.16.2"
		end
		for _, data in pairs(rcon_script_data) do
			data.version = data.version or "0.16.2"
		end
	end

	if version < 0.16 then
		add_admin_area_script(
			"Indestructible",
			'Makes selected entities indestructible',
			'local _, _, entities = ...\
			for i=1, #entities do\
				local entity = entities[i]\
				if entity.valid then\
					entity.destructible = false\
				end\
			end',
			"0.15"
		)
		add_admin_area_script(
			"Destroy",
			'Destroys selected entities safely',
			'local _, _, entities = ...\
			local raise_destroy = {raise_destroy=true}\
			for i=1, #entities do\
				local entity = entities[i]\
				if entity.valid and not entity.is_player() then\
					entity.destroy(raise_destroy)\
				end\
			end',
			"0.15"
		)
	end

	if version < 0.15 then
		add_rcon_script(
			"Print Twitch message", "",
			'local username, message = ...\
			game.print({"", "[color=purple][Twitch][/color] ", username, {"colon"}, " ", message})',
			"0.14"
		)
	end

	if version < 0.11 then
		add_admin_script(
			{"scripts-titles.kill-half-enemies"},
			{"scripts-description.kill-half-enemies"},
			'local player = ...\
			local raise_destroy = {raise_destroy=true}\
			local entities = player.surface.find_entities_filtered({force="enemy"})\
			for i=1, #entities, 2 do\
				entities[i].destroy(raise_destroy)\
			end',
			nil,
			"0.10"
		)
	end

	if version < 0.10 then
		for _, player in pairs(game.players) do
			local UB_book = player.gui.relative.UB_book
			if UB_book then
				UB_book.destroy()
			end
			create_left_relative_gui(player)
		end
	end
end

M.on_load = function()
	link_data()
	compile_all_text()
end
M.add_remote_interface = function()
	-- https://lua-api.factorio.com/latest/LuaRemote.html
	remote.remove_interface("useful_book") -- For safety
	remote.add_interface("useful_book", {
		get_source = function()
			local mod_name = script.mod_name
			print_to_rcon(mod_name) -- Returns "level" if it's a scenario, otherwise "useful_book" as a mod.
			return mod_name
		end,
		activate_rcon = function()
			is_server = true
		end,
		deactivate_rcon = function()
			is_server = false
		end,
		get_mod_data = function()
			return mod_data
		end,
		reset_scripts = reset_scripts,
		delete_admin_script = function(id)
			admin_script_data[id] = nil
			compiled_admin_code[id] = nil
		end,
		delete_public_script = function(id)
			public_script_data[id] = nil
			compiled_public_code[id] = nil
		end,
		delete_admin_area_script = function(name)
			admin_area_script_data[name] = nil
			compiled_admin_area_code[name] = nil
		end,
		delete_rcon_script = function(name)
			rcon_script_data[name] = nil
			compiled_rcon_code[name] = nil
		end,
		delete_command = function(name)
			if custom_commands_data[name] == nil then return end
			if compiled_commands_code[name] then
				compiled_commands_code[name] = nil
			end
			custom_commands_data[name] = nil
		end,
		add_admin_script = add_admin_script,
		add_public_script = add_public_script,
		add_admin_area_script = add_admin_area_script,
		add_rcon_script = add_rcon_script,
		add_new_command = add_new_command,
		run_admin_script = function(id, player)
			local f = compiled_public_code[id]
			if f == nil then return end
			local is_ok, error = pcall(f, player)
			if not is_ok then
				player.print(error, RED_COLOR)
			end
		end,
		run_public_script = function(id, player)
			local f = compiled_public_code[id]
			if f == nil then return end
			local is_ok, error = pcall(f, player)
			if not is_ok then
				player.print(error, RED_COLOR)
			end
		end
	})
end

--#endregion


local DROP_DOWN_GUIS_FUNCS = {
	UB_book_type = function(element, player)
		local book_type = element.selected_index
		element.parent.parent.parent.destroy()
		switch_book(player, book_type)
	end,
	UB_admin_area_scripts_drop_down = function(element, player)
		local selected_index = element.selected_index
		players_admin_area_script[player.index] = element.items[selected_index]
	end
}
M.events = {
	[defines.events.on_gui_click] = on_gui_click,
	[defines.events.on_gui_text_changed] = on_gui_text_changed,
	[defines.events.on_player_created] = on_player_created,
	[defines.events.on_player_joined_game] = destroy_GUI_event,
	[defines.events.on_player_left_game] = destroy_GUI_event,
	[defines.events.on_player_demoted] = destroy_GUI_event,
	[defines.events.on_player_selected_area] = on_player_selected_area,
	[defines.events.on_player_cursor_stack_changed] = on_player_cursor_stack_changed,
	[defines.events.on_gui_selection_state_changed] = function(event)
		local element = event.element
		if not (element and element.valid) then return end
		local f = DROP_DOWN_GUIS_FUNCS[element.name]
		if f then
			f(element, game.get_player(event.player_index))
		end
	end
}

M.commands = {
	["Ubook-export"] = function(cmd)
		local raw_data = {
			public = {},
			admin = {},
			admin_area = admin_area_script_data,
			rcon = rcon_script_data,
			commands = custom_commands_data
		}

		local public_data = raw_data.public
		local admin_data = raw_data.admin
		for _, data in pairs(public_script_data) do
			public_data[#public_data+1] = data
		end
		for _, data in pairs(admin_script_data) do
			admin_data[#admin_data+1] = data
		end

		local filename = "useful_book_scripts.json"
		local json = game.table_to_json(raw_data)
		game.write_file(filename, json, false, cmd.player_index)
		local target = game.get_player(cmd.player_index) or game
		-- TODO: add localization
		target.print("All scripts has been exported in ...script-output/" .. filename)
	end,
	["Ubook-import"] = function(cmd)
		import_scripts(cmd.parameter, game.get_player(cmd.player_index))
	end,
	["Ubook-reset"] = reset_scripts,
}

return M
