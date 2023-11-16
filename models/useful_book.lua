require("util")

---@class UB : module
local M = {}

local zk_modules = require("__zk-lib__/defines").modules

local luacheck = require(zk_modules.luacheck)
--#region Compilers
local moonscript = require(zk_modules.moonscript)
local candran    = require(zk_modules.candran)
local tl         = require(zk_modules.tl)
local lal        = require(zk_modules.lal)
--#endregion

bitwise    = require(zk_modules.bitwise)
luxtre     = require(zk_modules.luxtre)
basexx     = require(zk_modules.basexx)
-- allen      = require(zk_modules.allen) -- WARNING: messes around with moonscript etc.
vivid      = require(zk_modules.vivid)
guard      = require(zk_modules.guard)
lpeg       = require(zk_modules.lpeg)
LCS        = require(zk_modules.LCS)
fun        = require(zk_modules.fun)
all_control_utils = require(zk_modules.static_libs.all_control_utils)
Locale  = require(zk_modules.static_libs.locale)
Version = require(zk_modules.static_libs.version)
time_util   = require(zk_modules.static_libs.time_util)
number_util = require(zk_modules.static_libs.number_util)
coordinates_util = require(zk_modules.static_libs.coordinates_util)
GuiTemplater = require(zk_modules.static_libs.control_stage.GuiTemplater)
GuiTemplater.buttons.refresh.style = nil
GuiTemplater.buttons.small_plus = table.deepcopy(GuiTemplater.buttons.plus)
GuiTemplater.buttons.plus.style = nil

is_server = false -- this is for rcon


--#region Global data
local __mod_data
---@type table<integer, table>
local __public_script_data
---@type table<integer, table>
local __admin_script_data
---@type table<string, table>
local __admin_area_script_data
---@type table<string, table>
local __rcon_script_data
---@type table<string, table>
local __custom_commands_data
---@type table<integer, table<string, table>>
local __custom_events_data
---@type table<integer, string>
local __players_admin_area_script
---@type table<string, table>
local __public_hotkey_script_data
---@type table<string, table>
local __admin_hotkey_script_data
--#endregion

---@type table<integer, function>
local __compiled_public_code = {}
---@type table<integer, function>
local __compiled_admin_code = {}
---@type table<string, function>
local __compiled_admin_area_code = {}
---@type table<string, function>
local __compiled_rcon_code = {}
---@type table<string, function>
local __compiled_public_hotkey_code = {}
---@type table<string, function>
local __compiled_admin_hotkey_code  = {}
---@type table<string, function>
local __compiled_commands_code = {}
---@type table<integer, table<string, function>>
local __compiled_custom_events_data = {}


--#region Constants
print_to_rcon = rcon.print
DEFAULT_CODE = "local player = ...\nplayer.print(player.name)"
DEFAULT_RCON_CODE = "local data = ...\ngame.print(data)\nglobal.my_data = global.my_data or {data}\nif not is_server then return end -- be careful with it, it's different value for clients\nrcon.print(game.table_to_json(global.my_data))"
DEFAULT_ADMIN_AREA_CODE = "local area, player, entities = ...\n"
DEFAULT_CUSTOM_EVENT_CODE = "local event, player = ...\n"
DEFAULT_COMMAND_CODE = [[
if event.player_index == 0 then -- stop this command if we got it via server console/rcon
	player.print({"prohibited-server-command"})
	return
end
if player == nil then return end
if not player.admin then
	player.print({'command-output.parameters-require-admin'})
	return
end
player.print(player.name)
]]
DEFAULT_HOTKEY_CODE = "local player, event = ...\n"
COLON = {"colon"}
FLOW = {type = "flow"}
LABEL = {type = "label"}
EMPTY_WIDGET = {type = "empty-widget"}
RED_COLOR = {1, 0, 0}
YELLOW_COLOR = {1, 1, 0}
GREEN_COLOR = {0, 1, 0}
CLOSE_BUTTON = {
	type = "sprite-button",
	name = "UB_close",
	style = "frame_action_button",
	sprite = "utility/close_white",
	hovered_sprite = "utility/close_black",
	clicked_sprite = "utility/close_black"
}
LUACHECK_OPTIONS = {
	ignore  = {"612", "613", "614", "621"},
	globals = {
		"game",
		"script",
		"remote",
		"commands",
		"settings",
		"rcon",
		"rendering",
		"global",
		"log",
		"defines",
		"data",
		"mods",
		"serpent",
		"table_size",
		"bit32",
		"util",
		"localised_print",
		"circuit_connector_definitions",
		"universal_connector_template",
		"__DebugAdapter",
		"__Profiler",
		"bitwise",
		"luxtre",
		"vivid",
		"guard",
		"lpeg",
		"LCS",
		"fun",
		"all_control_utils",
		"Locale",
		"Version",
		"time_util",
		"number_util",
		"coordinates_util",
		"GuiTemplater",
		"is_server",
		"print_to_rcon",
		"COLON",
		"FLOW",
		"LABEL",
		"EMPTY_WIDGET",
		"RED_COLOR",
		"YELLOW_COLOR",
		"GREEN_COLOR"
	},
}
local BOOK_TYPES  = {
	admin         = 1,
	public        = 2,
	rcon          = 3,
	admin_area    = 4,
	command       = 5,
	custom_event  = 6,
	admin_hotkey  = 7,
	public_hotkey = 8
}
local BOOK_TITLES = {
	[BOOK_TYPES.admin]         = {"useful_book.admin_scripts"},
	[BOOK_TYPES.public]        = {"useful_book.public_scripts"},
	[BOOK_TYPES.rcon]          = {"useful_book.rcon_scripts"},
	[BOOK_TYPES.admin_area]    = {"useful_book.admin_area_scripts"},
	[BOOK_TYPES.command]       = {"useful_book.custom_commands"},
	[BOOK_TYPES.custom_event]  = {"useful_book.custom_events"},
	[BOOK_TYPES.admin_hotkey]  = {"useful_book.admin_script_hotkeys_title"},
	[BOOK_TYPES.public_hotkey] = {"useful_book.public_script_hotkeys_title"}
}
local SCRIPTS_BY_ID = { -- scripts which identified by id
	[BOOK_TYPES.admin] = true,
	[BOOK_TYPES.public] = true
}
local COMPILER_IDS = {
	lua        = 1,
	candran    = 2,
	teal       = 3,
	moonscript = 4,
}
local COMPILER_NAMES = {
	[COMPILER_IDS.lua] = "lua",
	[COMPILER_IDS.candran] = "candran v" .. candran.VERSION,
	[COMPILER_IDS.teal] = "teal v" .. tl.VERSION,
	[COMPILER_IDS.moonscript] = "moonscript v" .. moonscript.VERSION
}
local EVENTS_NAMES = {}
for name in pairs(defines.events) do
	EVENTS_NAMES[#EVENTS_NAMES+1] = name
end


local __delete_admin_hotkey_template = GuiTemplater.create{
	element = {
		type = "sprite-button",
		name = "UB_delete_admin_hotkey_code",
		style = "frame_action_button",
		sprite = "utility/trash_white",
		hovered_sprite = "utility/trash",
		clicked_sprite = "utility/trash"
	},
	on_gui_click = function(element, player, event)
		local flow = element.parent
		local script_name = flow.name

		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()

		__admin_hotkey_script_data[script_name] = nil
		__compiled_admin_hotkey_code[script_name] = nil

		local bindings = __mod_data.admin_script_bindings[player.index]
		if bindings then
			for hotkey, script_names in pairs(bindings) do
				for i=#script_names, 1, -1 do
					if script_name == script_names[i] then
						table.remove(script_names, i)
						if #script_names == 0 then
							bindings[hotkey] = nil
						end
						break
					end
				end
			end
			if table_size(bindings) == 0 then
				__mod_data.admin_script_bindings[player.index] = nil
			end
		end
	end
}
local __change_admin_hotkey_code_element = GuiTemplater.create{
	element = {
		type = "sprite-button",
		name = "UB_change_admin_hotkey_code",
		style = "frame_action_button",
		sprite = "map_exchange_string_white",
		hovered_sprite = "utility/map_exchange_string",
		clicked_sprite = "utility/map_exchange_string"
	},
	on_gui_click = function(element, player, event)
		switch_code_editor(player, BOOK_TYPES.admin_hotkey, element.parent.name)
	end
}
local __delete_public_hotkey_template = GuiTemplater.create{
	element = {
		type = "sprite-button",
		name = "UB_delete_public_hotkey_code",
		style = "frame_action_button",
		sprite = "utility/trash_white",
		hovered_sprite = "utility/trash",
		clicked_sprite = "utility/trash"
	},
	on_gui_click = function(element, player, event)
		local flow = element.parent
		local script_name = flow.name

		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()

		__public_hotkey_script_data[script_name] = nil
		__compiled_public_hotkey_code[script_name] = nil
		__mod_data.public_hotkey_scripts_ticks[script_name] = nil

		local bindings = __mod_data.public_script_bindings[player.index]
		if bindings then
			for hotkey, script_names in pairs(bindings) do
				for i=#script_names, 1, -1 do
					if script_name == script_names[i] then
						table.remove(script_names, i)
						if #script_names == 0 then
							bindings[hotkey] = nil
						end
						break
					end
				end
			end
			if table_size(bindings) == 0 then
				__mod_data.public_script_bindings[player.index] = nil
			end
		end
	end
}
local __change_public_hotkey_code_element = GuiTemplater.create{
	element = {
		type = "sprite-button",
		name = "UB_change_public_hotkey_code",
		style = "frame_action_button",
		sprite = "map_exchange_string_white",
		hovered_sprite = "utility/map_exchange_string",
		clicked_sprite = "utility/map_exchange_string"
	},
	on_gui_click = function(element, player, event)
		switch_code_editor(player, BOOK_TYPES.public_hotkey, element.parent.name)
	end
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
	print_to_rcon(game.table_to_json(__mod_data[name]))
end

-- /sc __useful_book__ RunRCONScript("script name", ...)
---@param name string
---@param ... any #any data
function RunRCONScript(name, ...)
	local f = __compiled_rcon_code[name]
	if f == nil then return end
	local is_ok, error = pcall(f, ...)
	if not is_ok then
		game.print(error, RED_COLOR)
	end
end

--#endregion


--#region utils


---@param data table
local function fix_old_data(data)
	if data.compiler_id then return end
	if data.use_candran then
		data.compiler_id = COMPILER_IDS.candran
		data.use_candran = nil
	elseif data.use_candran ~= nil then
		data.compiler_id = COMPILER_IDS.lua
		data.use_candran = nil
	else
		data.compiler_id = COMPILER_IDS.lua
	end
end


---@param json string
---@param player? LuaPlayer
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
		fix_old_data(data)
		add_public_script(data.title, data.descripton, data.code, data.compiler_id, nil, data.version or "0.16.2")
	end
	for _, data in pairs(raw_data.admin or {}) do
		fix_old_data(data)
		add_admin_script(data.title, data.descripton, data.code, data.compiler_id, nil, data.version or "0.16.2")
	end
	for name, data in pairs(raw_data.admin_area or {}) do
		fix_old_data(data)
		add_admin_area_script(name, data.descripton, data.code, data.compiler_id, data.version or "0.16.2")
	end
	for name, data in pairs(raw_data.rcon or {}) do
		fix_old_data(data)
		add_rcon_script(name, data.descripton, data.code, data.compiler_id, data.version or "0.16.2")
	end
	for event_name, _custom_events_data in pairs(raw_data.custom_events or {}) do
		for name, data in pairs(_custom_events_data) do
			add_custom_event_script(event_name, name, data.descripton, data.code, data.compiler_id, data.version)
		end
	end
	for name, data in pairs(raw_data.commands or {}) do
		fix_old_data(data)
		add_new_command(name, data.descripton, data.code, data.compiler_id, data.version or "0.16.2")
	end
	for name, data in pairs(raw_data.public_hotkey_scripts or {}) do
		add_public_hotkey_script(name, data.descripton, data.code, data.compiler_id, data.version or "0.21.0")
	end
	for name, data in pairs(raw_data.admin_hotkey_scripts or {}) do
		add_admin_hotkey_script(name, data.descripton, data.code, data.compiler_id, data.version or "0.21.0")
	end

	-- TODO: add localization
	target.print("Scripts has been imported for \"useful book\"")
	return true
end


---@param event_id integer
local function add_custom_event(event_id)
	__compiled_custom_events_data[event_id] = __compiled_custom_events_data[event_id] or {}
	local compiled_N_custom_events = __compiled_custom_events_data[event_id]

	local is_default_event = (M.events[event_id] ~= nil)
	if is_default_event == true then return end
	local is_handled = (script.get_event_handler(event_id) ~= nil)
	if is_handled then return end

	script.on_event(event_id, function(event)
		local player
		if event.player_index and event.player_index > 0 then
			player = game.get_player(event.player_index)
		end
		for _, _f in pairs(compiled_N_custom_events) do
			local is_ok, error = pcall(_f, event, player)
			if not is_ok then
				game.print(error, RED_COLOR)
			end
		end
	end)
	log("Added new event, id = " .. tostring(event_id))
end


---Use it on predefined events
local function execute_custom_event(event, player)
	local compiled_N_custom_events = __compiled_custom_events_data[event.name]
	if compiled_N_custom_events == nil then return end
	for _, _f in pairs(compiled_N_custom_events) do
		local is_ok, error = pcall(_f, event, player)
		if not is_ok then
			game.print(error, RED_COLOR)
		end
	end
end


---@param event_id integer
---@param name string
local function delete_custom_event(event_id, name)
	local is_default_event = (M.events[event_id] ~= nil)
	local compiled_N_custom_events = __compiled_custom_events_data[event_id]
	if compiled_N_custom_events == nil then return end
	if compiled_N_custom_events[name] then -- Perhaps, it's excessive, but it's better to be safe
		compiled_N_custom_events[name] = nil
	end
	if next(compiled_N_custom_events) == nil then
		__compiled_custom_events_data[event_id] = nil
	end
	if is_default_event == false then
		script.on_event(event_id, nil)
		log("Removed an event, id = " .. tostring(event_id))
	end
end


---@param _ nil
---@param player LuaPlayer
function open_import_frame(_, player)
	local screen = player.gui.screen
	if screen.UB_import_frame then
		return
	end

	local content_frame, main_frame, top_flow = GuiTemplater.create_screen_window(player, "UB_import_frame", {"gui-blueprint-library.import-string"})
	content_frame.style.padding = 0
	main_frame.force_auto_center()

	local textfield = content_frame.add{
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
	pusher.style.vertically_stretchable   = true
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
	__mod_data.public_hotkey_scripts_ticks = {}

	__mod_data.admin_script_data = {}
	__admin_script_data = __mod_data.admin_script_data
	__mod_data.public_script_data = {}
	__public_script_data = __mod_data.public_script_data
	__mod_data.admin_hotkey_script_data = {}
	__admin_hotkey_script_data = __mod_data.admin_hotkey_script_data
	__mod_data.public_hotkey_script_data = {}
	__public_hotkey_script_data = __mod_data.public_hotkey_script_data
	__mod_data.admin_area_script_data = {}
	__admin_area_script_data = __mod_data.admin_area_script_data
	__mod_data.rcon_script_data = {}
	__rcon_script_data = __mod_data.rcon_script_data
	__mod_data.custom_commands_data = {}
	__custom_commands_data = __mod_data.custom_commands_data
	__mod_data.custom_events_data = {}
	__custom_events_data = __mod_data.custom_events_data
	__compiled_admin_code  = {}
	__compiled_public_code = {}
	__compiled_admin_area_code = {}
	__compiled_rcon_code = {}
	__compiled_commands_code = {}
	__compiled_custom_events_data = {}
	__compiled_public_hotkey_code = {}
	__compiled_admin_hotkey_code  = {}

	add_admin_hotkey_script(
		"unstuck", "Unstucks your character",
		"local player, event = ...\n" ..
		"local character = player.character\n" ..
		"if not (character and character.valid) then return end\n" ..
		"local new_position = character.surface.find_non_colliding_position(character.name, character.position, 20, 1)\n" ..
		"if not new_position then return end\n" ..
		"player.teleport(new_position, character.surface)",
		COMPILER_IDS.lua
	)
	add_admin_script(
		{"scripts-titles.reveal-gen-map"},
		{"scripts-description.reveal-gen-map"},
		"local player = ...\nplayer.force.chart_all()",
		COMPILER_IDS.lua
	)
	add_admin_script(
		{"scripts-titles.kill-all-enemies"},
		{"scripts-description.kill-all-enemies"},
		'local player = ...\
		local raise_destroy = {raise_destroy=true}\
		local entities = player.surface.find_entities_filtered({force="enemy"})\
		for i=1, #entities do\
			entities[i].destroy(raise_destroy)\
		end',
		COMPILER_IDS.lua
	)
	add_admin_script(
		{"scripts-titles.kill-half-enemies"},
		{"scripts-description.kill-half-enemies"},
		'local player = ...\
		local raise_destroy = {raise_destroy=true}\
		local entities = player.surface.find_entities_filtered({force="enemy"})\
		for i=1, #entities, 2 do\
			entities[i].destroy(raise_destroy)\
		end',
		COMPILER_IDS.lua
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
		end',
		COMPILER_IDS.lua
	)
	add_rcon_script(
		"Print Twitch message", "",
		'local username, message = ...\
		game.print({"", "[color=purple][Twitch][/color] ", username, {"colon"}, " ", message})',
		COMPILER_IDS.lua
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
		end',
		COMPILER_IDS.lua
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
		COMPILER_IDS.lua
	)
	add_new_command(
		"tl", "executes teal code",
		"if event.parameter == nil then return end\n" ..
		"if event.player_index == 0 then\n" ..
		"	tl.load(event.parameter)()\n" ..
		"	return\n" ..
		"end\n" ..
		"if not player then return end\n" ..
		"if not player.admin then\n" ..
		"	player.print({'prohibited-server-command'})\n" ..
		"	return\n" ..
		"end\n" ..
		"tl.load(event.parameter)()",
		COMPILER_IDS.lua
	)
	add_new_command(
		"candran", "executes candran code",
		"if event.parameter == nil then return end\n" ..
		"if event.player_index == 0 then\n" ..
		"	load(candran.make(event.parameter))()\n" ..
		"	return\n" ..
		"end\n" ..
		"if not player then return end\n" ..
		"if not player.admin then\n" ..
		"	player.print({'prohibited-server-command'})\n" ..
		"	return\n" ..
		"end\n" ..
		"load(candran.make(event.parameter))()",
		COMPILER_IDS.lua
	)
	for _, player in pairs(game.players) do
		if player.valid and player.admin then
			-- TODO: add localization
			player.print("Scripts has been reset for \"useful book\"")
		end
	end
end

---@param player LuaPlayer
function close_admin_area_scripts_frame(player)
	local frame = player.gui.screen.UB_admin_area_scripts_frame
	if frame then
		frame.destroy()
		__players_admin_area_script[player.index] = nil
	end
end

---@param player LuaPlayer
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
	for name in pairs(__admin_area_script_data) do
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
DEFAULT_COMMAND_CODE = format_code(DEFAULT_COMMAND_CODE)


---@param code string
---@param compiler_id integer
---@return function
function format_command_code(code, compiler_id)
	local is_ok
	if compiler_id == COMPILER_IDS.candran then
		is_ok, code = pcall(candran.make, code) -- TODO: perhaps, xpcall
		if not is_ok then
			log(code)
			code = ""
		end
	elseif compiler_id == COMPILER_IDS.teal then
		is_ok, code = pcall(tl.gen, code) -- TODO: perhaps, xpcall
		if not is_ok then
			log(code)
			code = ""
		end
	elseif compiler_id == COMPILER_IDS.moonscript then
		is_ok, code = pcall(moonscript.to_lua, code) -- TODO: perhaps, xpcall
		if not is_ok then
			log(code)
			code = ""
		end
	end
	local new_code = "local function custom_command(event, player) " .. code .. "\nend\n"
	-- TODO: improve the error message!
	-- Should I prohibit access to some global variables
	-- and make them a bit different for the command?
	local new_code2 = [[return function(event)
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
---@param compiler_id integer
---@param id number?
---@param version string?
---@return integer? #id
function add_admin_script(title, description, code, compiler_id, id, version)
	code = format_code(code)
	local f
	if compiler_id == COMPILER_IDS.lua then
		f = load(code)
	elseif compiler_id == COMPILER_IDS.candran then
		f = load(candran.make(code))
	elseif compiler_id == COMPILER_IDS.teal then
		f = tl.load(code)
	elseif compiler_id == COMPILER_IDS.moonscript then
		f = moonscript.loadstring(code)
	end
	if type(f) ~= "function" then return end

	if id == nil then
		id = __mod_data.last_admin_id + 1
		__mod_data.last_admin_id = id
	end
	__compiled_admin_code[id] = f
	__admin_script_data[id] = {
		description = description,
		title = title,
		code = code,
		compiler_id = compiler_id or COMPILER_IDS.lua,
		version = version or script.active_mods.useful_book
	}
	return id
end


---@param title string|LocalisedString
---@param description? string|LocalisedString
---@param code string
---@param compiler_id integer
---@param id number?
---@param version string?
---@return integer? #id
function add_public_script(title, description, code, compiler_id, id, version)
	code = format_code(code)
	local f
	if compiler_id == COMPILER_IDS.lua then
		f = load(code)
	elseif compiler_id == COMPILER_IDS.candran then
		f = load(candran.make(code))
	elseif compiler_id == COMPILER_IDS.teal then
		f = tl.load(code)
	elseif compiler_id == COMPILER_IDS.moonscript then
		f = moonscript.loadstring(code)
	end

	if type(f) ~= "function" then return end

	if id == nil then
		id = __mod_data.last_public_id + 1
		__mod_data.last_public_id = id
	end
	__compiled_public_code[id] = f
	__public_script_data[id] = {
		description = description,
		title = title,
		code = code,
		compiler_id = compiler_id or COMPILER_IDS.lua,
		version = version or script.active_mods.useful_book
	}
	return id
end


---@param name string|LocalisedString
---@param description? string|LocalisedString
---@param code string
---@param compiler_id integer
---@param id number?
---@param version string?
---@return integer? #id
function add_public_hotkey_script(name, description, code, compiler_id, id, version)
	code = format_code(code)
	local f
	if compiler_id == COMPILER_IDS.lua then
		f = load(code)
	elseif compiler_id == COMPILER_IDS.candran then
		f = load(candran.make(code))
	elseif compiler_id == COMPILER_IDS.teal then
		f = tl.load(code)
	elseif compiler_id == COMPILER_IDS.moonscript then
		f = moonscript.loadstring(code)
	end

	if type(f) ~= "function" then return end

	__compiled_public_hotkey_code[name] = f
	__public_hotkey_script_data[name] = {
		description = description,
		code = code,
		compiler_id = compiler_id or COMPILER_IDS.lua,
		version = version or script.active_mods.useful_book
	}
	return id
end


---@param name string|LocalisedString
---@param description? string|LocalisedString
---@param code string
---@param compiler_id integer
---@param id number?
---@param version string?
---@return integer? #id
function add_admin_hotkey_script(name, description, code, compiler_id, id, version)
	code = format_code(code)
	local f
	if compiler_id == COMPILER_IDS.lua then
		f = load(code)
	elseif compiler_id == COMPILER_IDS.candran then
		f = load(candran.make(code))
	elseif compiler_id == COMPILER_IDS.teal then
		f = tl.load(code)
	elseif compiler_id == COMPILER_IDS.moonscript then
		f = moonscript.loadstring(code)
	end

	if type(f) ~= "function" then return end

	__compiled_admin_hotkey_code[name] = f
	__admin_hotkey_script_data[name] = {
		description = description,
		code = code,
		compiler_id = compiler_id or COMPILER_IDS.lua,
		version = version or script.active_mods.useful_book
	}
	return id
end


---@param name string
---@param description? string
---@param code string
---@param compiler_id integer
---@param version string?
---@return boolean is_valid
function add_admin_area_script(name, description, code, compiler_id, version)
	code = format_code(code)
	local f
	if compiler_id == COMPILER_IDS.lua then
		f = load(code)
	elseif compiler_id == COMPILER_IDS.candran then
		f = load(candran.make(code))
	elseif compiler_id == COMPILER_IDS.teal then
		f = tl.load(code)
	elseif compiler_id == COMPILER_IDS.moonscript then
		f = moonscript.loadstring(code)
	end
	if type(f) ~= "function" then return false end

	__compiled_admin_area_code[name] = f
	__admin_area_script_data[name] = {
		description = description,
		code = code,
		compiler_id = compiler_id or COMPILER_IDS.lua,
		version = version or script.active_mods.useful_book
	}
	return true
end


---@param name string
---@param description? string
---@param code string
---@param compiler_id integer
---@param version string?
---@return boolean is_valid
function add_rcon_script(name, description, code, compiler_id, version)
	code = format_code(code)
	local f
	if compiler_id == COMPILER_IDS.lua then
		f = load(code)
	elseif compiler_id == COMPILER_IDS.candran then
		f = load(candran.make(code))
	elseif compiler_id == COMPILER_IDS.teal then
		f = tl.load(code)
	elseif compiler_id == COMPILER_IDS.moonscript then
		f = moonscript.loadstring(code)
	end
	if type(f) ~= "function" then return false end

	__compiled_rcon_code[name] = f
	__rcon_script_data[name] = {
		description = description,
		code = code,
		compiler_id = compiler_id or COMPILER_IDS.lua,
		version = version or script.active_mods.useful_book
	}
	return true
end


---@param event_name string
---@param name string
---@param description? string
---@param code string
---@param compiler_id integer
---@param version string?
---@return boolean is_valid
function add_custom_event_script(event_name, name, description, code, compiler_id, version)
	local event_id = defines.events[event_name]
	if event_id == nil then
		return false
	end

	code = format_code(code)
	local f
	if compiler_id == COMPILER_IDS.lua then
		f = load(code)
	elseif compiler_id == COMPILER_IDS.candran then
		f = load(candran.make(code))
	elseif compiler_id == COMPILER_IDS.teal then
		f = tl.load(code)
	elseif compiler_id == COMPILER_IDS.moonscript then
		f = moonscript.loadstring(code)
	end

	if type(f) ~= "function" then return false end

	__compiled_custom_events_data[event_id] = __compiled_custom_events_data[event_id] or {}
	__compiled_custom_events_data[event_id][name] = f
	__custom_events_data[event_name] = __custom_events_data[event_name] or {}
	__custom_events_data[event_name][name] = {
		description = description,
		code = code,
		compiler_id = compiler_id or COMPILER_IDS.lua,
		version = version or script.active_mods.useful_book
	}
	add_custom_event(event_id)
	return true
end

---@param name string
---@param description? string
---@param code string
---@param compiler_id integer
---@param version string?
---@return boolean is_valid, boolean is_command_added
function add_new_command(name, description, code, compiler_id, version)
	code = format_code(code)
	if compiler_id == COMPILER_IDS.lua then
		if type(load(code)) ~= "function" then return false, false end
	elseif compiler_id == COMPILER_IDS.moonscript then
		if type(moonscript.loadstring(code)) ~= "function" then return false, false end
	elseif compiler_id == COMPILER_IDS.teal then
		if type(tl.load(code)) ~= "function" then return false, false end
	elseif compiler_id == COMPILER_IDS.candran then
		if type(load(candran.make(code))) ~= "function" then return false, false end
	end

	__custom_commands_data[name] = {
		description = description,
		code = code,
		compiler_id = compiler_id or COMPILER_IDS.lua,
		version = version or script.active_mods.useful_book
	}
	if not commands.commands[name] and not commands.game_commands[name] then
		__custom_commands_data[name].is_added = true
		local f = format_command_code(code, compiler_id)
		__compiled_commands_code[name] = f
		commands.add_command(name, description or '', f)
		log("Added new command : " .. name)
		return true, true
	else
		__custom_commands_data[name].is_added = false
		return true, false
	end
end

local function destroy_GUI(player)
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


---@param player LuaPlayer
---@param book_type integer
---@param id? integer|string
---@param event_name? string
function switch_code_editor(player, book_type, id, event_name)
	local screen = player.gui.screen
	-- if screen.UB_code_editor then
	-- 	screen.UB_code_editor.destroy()
	-- 	return
	-- end

	local data
	if id then
		if book_type == BOOK_TYPES.public then
			data = __public_script_data[id]
		elseif book_type == BOOK_TYPES.admin then
			data = __admin_script_data[id]
		elseif book_type == BOOK_TYPES.admin_area then
			data = __admin_area_script_data[id]
		elseif book_type == BOOK_TYPES.admin_hotkey then
			data = __admin_hotkey_script_data[id]
		elseif book_type == BOOK_TYPES.public_hotkey then
			data = __public_hotkey_script_data[id]
		elseif book_type == BOOK_TYPES.custom_event then
			-- Perhaps, I should change it
			if __custom_events_data[event_name] == nil then
				return
			end
			data = __custom_events_data[event_name][id]
		elseif book_type == BOOK_TYPES.command then
			data = __custom_commands_data[id]
			if data.is_added then
				commands.remove_command(id)
				log("Remove a command with name: " .. id)
				data.is_added = false
			end
		elseif book_type == BOOK_TYPES.rcon then
			data = __rcon_script_data[id]
		else
			log("error")
		end
	end

	local caption
	if event_name then
		caption = {'', {"useful_book.code_editor"}, ' (', BOOK_TITLES[book_type], ', ', event_name,')'}
	else
		caption = {'', {"useful_book.code_editor"}, ' (', BOOK_TITLES[book_type], ')'}
	end
	local content_frame, main_frame, top_flow = GuiTemplater.create_screen_window(player, "UB_code_editor", caption)

	local flow = content_frame.add(FLOW)
	flow.name = "buttons_row"
	local UB_check_code = flow.add(GuiTemplater.buttons.refresh)
	UB_check_code.name = "UB_check_code"
	local UB_add_code = flow.add(GuiTemplater.buttons.plus)
	UB_add_code.name = "UB_add_code"
	UB_add_code.visible = false

	if book_type == BOOK_TYPES.admin or book_type == BOOK_TYPES.public
	   or book_type == BOOK_TYPES.public_hotkey or book_type == BOOK_TYPES.admin_hotkey
	then
		flow.add(LABEL).caption = {'', {"useful_book.is_public_script"}, COLON}
	end
	local UB_is_public_script = flow.add{
		type = "checkbox", name = "UB_is_public_script",
		state = (book_type == BOOK_TYPES.public),
		enabled = id and false
	}

	-- TODO: add localization
	local label = flow.add(LABEL)
	label.caption = {'', 'Compiler', COLON}
	flow.add{
		type = "drop-down",
		name = "UB_compiler_id",
		items = COMPILER_NAMES,
		selected_index = data and data.compiler_id or COMPILER_IDS.lua
	}

	if book_type ~= BOOK_TYPES.admin and book_type ~= BOOK_TYPES.public
	   and book_type ~= BOOK_TYPES.public_hotkey and book_type ~= BOOK_TYPES.admin_hotkey
	then
		UB_is_public_script.visible = false
	end
	flow.add{type = "slider", name = "UB_book_type", value = book_type, visible = false}
	if book_type == BOOK_TYPES.custom_event then
		flow.add{type = "textfield", name = "UB_event_name", text = event_name, visible = false}
	end
	if id then
		local label_id = flow.add{type = "label", name = "id", visible = false}
		if SCRIPTS_BY_ID[book_type] then
			label_id.caption = tonumber(id)
		else
			label_id.caption = id
		end
	end

	content_frame.add({type = "label", name = "error_message", style = "bold_red_label", visible = false})

	local scroll_pane = content_frame.add{type = "scroll-pane", name = "scroll_pane"}

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
		if not SCRIPTS_BY_ID[book_type] then
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
		input.text = data and data.code or DEFAULT_RCON_CODE
	elseif book_type == BOOK_TYPES.admin_area then
		input.text = data and data.code or DEFAULT_ADMIN_AREA_CODE
	elseif book_type == BOOK_TYPES.custom_event then
		input.text = data and data.code or DEFAULT_CUSTOM_EVENT_CODE
	elseif book_type == BOOK_TYPES.command then
		input.text = data and data.code or DEFAULT_COMMAND_CODE
	elseif book_type == BOOK_TYPES.public_hotkey or book_type == BOOK_TYPES.admin_hotkey then
		input.text = data and data.code or DEFAULT_HOTKEY_CODE
	else
		input.text = data and data.code or DEFAULT_CODE
	end

	local UB_linter = scroll_pane.add{type = "text-box", name = "UB_linter"}
	UB_linter.style.horizontally_stretchable = true
	UB_linter.style.vertically_stretchable   = true
	UB_linter.style.minimal_height = 120
	UB_linter.style.maximal_width  = 0
	UB_linter.read_only = true
	UB_linter.visible = false

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
	for id, data in pairs(__public_script_data) do
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
	for id, data in pairs(__admin_script_data) do
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

local function fill_with_custom_event_data(table_element, event_name)
	if __custom_events_data[event_name] == nil then return end
	local DELETE_BUTTON = {
		type = "sprite-button",
		name = "UB_delete_custom_event_code",
		style = "frame_action_button",
		sprite = "utility/trash_white",
		hovered_sprite = "utility/trash",
		clicked_sprite = "utility/trash"
	}
	local CHANGE_BUTTON = {
		type = "sprite-button",
		name = "UB_change_custom_event_code",
		style = "frame_action_button",
		sprite = "map_exchange_string_white",
		hovered_sprite = "utility/map_exchange_string",
		clicked_sprite = "utility/map_exchange_string"
	}
	local label, flow
	for name, data in pairs(__custom_events_data[event_name]) do
		label = table_element.add(LABEL)
		label.tooltip = data.description or ''
		label.caption = name
		flow = table_element.add(FLOW)
		flow.name = name
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
	for name, data in pairs(__admin_area_script_data) do
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
	for name, data in pairs(__rcon_script_data) do
		label = table_element.add(LABEL)
		label.tooltip = data.description or ''
		label.caption = name
		flow = table_element.add(FLOW)
		flow.name = name
		flow.add(CHANGE_BUTTON)
		flow.add(DELETE_BUTTON)
	end
end

local function fill_with_admin_hotkey_script_data(table_element)
	local DELETE_BUTTON = __delete_admin_hotkey_template.element
	local CHANGE_BUTTON = __change_admin_hotkey_code_element.element
	local label, flow
	for name, data in pairs(__admin_hotkey_script_data) do
		label = table_element.add(LABEL)
		label.tooltip = data.description or ''
		label.caption = name
		flow = table_element.add(FLOW)
		flow.name = name
		flow.add(CHANGE_BUTTON)
		flow.add(DELETE_BUTTON)
	end
end

local function fill_with_public_hotkey_script_data(table_element)
	local DELETE_BUTTON = __delete_public_hotkey_template.element
	local CHANGE_BUTTON = __change_public_hotkey_code_element.element
	local label, flow
	for name, data in pairs(__public_hotkey_script_data) do
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
	for name, data in pairs(__custom_commands_data) do
		label = table_element.add(LABEL)
		label.tooltip = data.description or ''
		label.caption = name
		flow = table_element.add(FLOW)
		flow.name = name
		flow.add(CHANGE_BUTTON)
		flow.add(DELETE_BUTTON)
	end
end


---@param player LuaPlayer
---@param book_type integer
function switch_book(player, book_type, selected_index)
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
		local import = footer.add(GuiTemplater.buttons.import)
		import.name = "UB_open_import"
		local plus = footer.add(GuiTemplater.buttons.small_plus)
		plus.name = "UB_open_code_editor"
	end
	footer.add(CLOSE_BUTTON)

	local content_table = main_frame.add{type = "table", name = "content_table", column_count = 1}
	content_table.add(EMPTY_WIDGET).style.horizontally_stretchable = true

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
		if book_type == BOOK_TYPES.custom_event then
			local sub_flow2 = content_table.add(FLOW)
			sub_flow2.name = "event_names_flow"
			sub_flow2.style.horizontally_stretchable = true
			sub_flow2.add{
				type = "drop-down", name = "UB_event_names",
				items = EVENTS_NAMES,
				selected_index = selected_index or 1
			}
		end
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
	elseif book_type == BOOK_TYPES.custom_event then
		local event_name = EVENTS_NAMES[selected_index or 1]
		fill_with_custom_event_data(scripts_table, event_name)
	elseif book_type == BOOK_TYPES.command then
		fill_with_custom_commands_data(scripts_table)
	elseif book_type == BOOK_TYPES.admin_hotkey then
		fill_with_admin_hotkey_script_data(scripts_table)
	elseif book_type == BOOK_TYPES.public_hotkey then
		fill_with_public_hotkey_script_data(scripts_table)
	elseif book_type == BOOK_TYPES.rcon then
		fill_with_rcon_data(scripts_table)
	else
		log("error")
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


---@param event EventData.on_player_created
function M.on_player_created(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end
	create_left_relative_gui(player)
	execute_custom_event(event, player)
end


---@param event EventData.on_player_removed
function M.on_player_removed(event)
	local player_index = event.player_index

	__players_admin_area_script[player_index] = nil
	__mod_data.public_script_bindings[player_index] = nil
	__mod_data.admin_script_bindings[player_index]  = nil
	for _, data in pairs(__mod_data.public_hotkey_scripts_ticks) do
		data[player_index] = nil
	end
end


---@param event EventData.on_gui_text_changed
function M.on_gui_text_changed(event)
	local element = event.element
	if not (element and element.valid) then return end
	local player = game.get_player(event.player_index)
	execute_custom_event(event, player)
	if element.name ~= "UB_program_input" then return end

	--TODO: refactor
	local button = element.parent.parent.buttons_row.UB_run_code
	if button then
		button.name = "UB_check_code"
		button.sprite = GuiTemplater.buttons.refresh.sprite
		button.hovered_sprite = GuiTemplater.buttons.refresh.hovered_sprite
		button.clicked_sprite = GuiTemplater.buttons.refresh.clicked_sprite
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
				-- TODO: change for public hotkeys
				if next(__public_script_data) == nil then
					player.print({"useful_book.no-public-scripts"})
				else
					switch_book(player, BOOK_TYPES.public)
				end
			end
		end
	end,
	UB_run_public_script = function(element, player)
		local id = tonumber(element.parent.name)
		local f = __compiled_public_code[id]
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
		local f = __compiled_admin_code[id]
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
		local flow = element.parent
		local id = tonumber(flow.name)
		---@cast id number
		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()
		__public_script_data[id] = nil
		__compiled_public_code[id] = nil
	end,
	UB_delete_admin_code = function(element, player)
		local flow = element.parent
		local id = tonumber(flow.name)
		---@cast id number
		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()
		__admin_script_data[id] = nil
		__compiled_admin_code[id] = nil
	end,
	UB_delete_admin_area_code = function(element, player)
		local flow = element.parent
		local name = flow.name
		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()
		__admin_area_script_data[name] = nil
		__compiled_admin_area_code[name] = nil
	end,
	UB_delete_rcon_code = function(element, player)
		local flow = element.parent
		local name = flow.name
		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()
		__rcon_script_data[name] = nil
		__compiled_rcon_code[name] = nil
	end,
	UB_delete_custom_event_code = function(element, player)
		local flow = element.parent
		local name = flow.name
		__custom_events_data[name] = nil
		__compiled_custom_events_data[name] = nil

		local main_frame = flow.parent.parent.parent
		local UB_event_names = main_frame.content_table.event_names_flow.UB_event_names
		local event_name = UB_event_names.items[UB_event_names.selected_index]
		local events_data = __custom_events_data[event_name]
		if events_data then
			events_data[name] = nil
		end
		local event_id = defines.events[event_name]
		if event_id then
			local compiled_events = __compiled_custom_events_data[event_id]
			if compiled_events then
				compiled_events[name] = nil
			end
		end
		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()
		delete_custom_event(event_id, name)
	end,
	UB_delete_custom_command = function(element, player)
		local name = element.parent.name
		data = __custom_commands_data[name]
		if data then
			if data.is_added then
				commands.remove_command(name)
				log("Remove a command with name: " .. name)
			end
			__custom_commands_data[name] = nil
			if __compiled_commands_code[name] then -- there's something weird about Factorio lua, so I shouldn't nil twice
				__compiled_commands_code[name] = nil
			end
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
	UB_change_custom_event_code = function(element, player)
		local flow = element.parent
		local name = flow.name
		local main_frame = flow.parent.parent.parent
		local UB_event_names = main_frame.content_table.event_names_flow.UB_event_names
		local event_name = UB_event_names.items[UB_event_names.selected_index]
		switch_code_editor(player, BOOK_TYPES.custom_event, name, event_name)
	end,
	UB_open_code_editor = function(element, player)
		local UB_book_frame = element.parent.parent
		local content_table = UB_book_frame.content_table
		local book_type = content_table.nav_flow.UB_book_type.selected_index
		local event_name
		if book_type == BOOK_TYPES.custom_event then
			local UB_event_names = content_table.event_names_flow.UB_event_names
			event_name = UB_event_names.items[UB_event_names.selected_index]
		end
		UB_book_frame.destroy()
		switch_code_editor(player, book_type, nil, event_name)
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
		local UB_book_type = flow.UB_book_type.slider_value
		local compiler_id = flow.UB_compiler_id.selected_index
		---@cast compiler_id integer
		local book_type = UB_book_type
		local is_enabled = flow.UB_is_public_script.enabled
		if not is_enabled then
			-- TODO: RECHECK
			local name = flow.id.caption
			if book_type == BOOK_TYPES.admin then
				local id = tonumber(name)
				---@cast id number
				add_admin_script(title, description, code, compiler_id, id)
			elseif book_type == BOOK_TYPES.public then
				local id = tonumber(name)
				---@cast id number
				add_public_script(title, description, code, compiler_id, id)
			elseif book_type == BOOK_TYPES.admin_area then
				add_admin_area_script(name, description, code, compiler_id)
			elseif book_type == BOOK_TYPES.custom_event then
				local event_name = flow.UB_event_name.text
				add_custom_event_script(event_name, name, description, code, compiler_id)
			elseif book_type == BOOK_TYPES.admin_hotkey then
				add_admin_hotkey_script(name, description, code, compiler_id)
			elseif book_type == BOOK_TYPES.public_hotkey then
				add_public_hotkey_script(name, description, code, compiler_id)
			elseif book_type == BOOK_TYPES.command then
				local is_valid, is_command_added = add_new_command(name, description, code, compiler_id)
				if is_valid and not is_command_added then
					player.print("There's a command with the same name")
				end
			elseif book_type == BOOK_TYPES.rcon then
				add_rcon_script(name, description, code, compiler_id)
			else
				log("error")
			end
		else
			if book_type == BOOK_TYPES.admin then
				add_admin_script(title, description, code, compiler_id)
			elseif book_type == BOOK_TYPES.public then
				add_public_script(title, description, code, compiler_id)
			elseif book_type == BOOK_TYPES.admin_area then
				add_admin_area_script(title, description, code, compiler_id)
			elseif book_type == BOOK_TYPES.admin_hotkey then
				add_admin_hotkey_script(title, description, code, compiler_id)
			elseif book_type == BOOK_TYPES.public_hotkey then
				add_public_hotkey_script(title, description, code, compiler_id)
			elseif book_type == BOOK_TYPES.custom_event then
				local event_name = flow.UB_event_name.text
				add_custom_event_script(event_name, title, description, code, compiler_id)
			elseif book_type == BOOK_TYPES.command then
				local is_valid, is_command_added = add_new_command(title, description, code, compiler_id)
				if is_valid and not is_command_added then
					player.print("There's a command with the same name")
				end
			elseif book_type == BOOK_TYPES.rcon then
				add_rcon_script(title, description, code, compiler_id)
			else
				log("error")
			end
		end

		element.parent.parent.parent.destroy()
		switch_book(player, book_type)
	end,
	UB_run_code = function(element, player)
		local parent = element.parent
		local UB_book_type = parent.UB_book_type.slider_value
		local is_command = (UB_book_type == BOOK_TYPES.command)
		local scroll_pane = parent.parent.scroll_pane
		local code = scroll_pane.UB_program_input.text
		local compiler_id = parent.UB_compiler_id.selected_index
		local is_ok, _error

		if compiler_id == COMPILER_IDS.candran then
			local _is_ok, result = pcall(candran.make, code)
			if _is_ok then
				code = result
			else
				player.print(result, RED_COLOR)
				return
			end
		elseif compiler_id == COMPILER_IDS.teal then
			local _is_ok, result = pcall(tl.gen, code)
			if _is_ok then
				-- It should be improved somehow
				local __is_ok, __message = tl.load(code)
				if __is_ok then
					code = result
				else
					player.print(__message, RED_COLOR)
					return
				end
			else
				player.print(result, RED_COLOR)
				return
			end
		elseif compiler_id == COMPILER_IDS.moonscript then
			local is_ok, lua_code, message = pcall(moonscript.to_lua, code) -- TODO: perhaps, xpcall
			if not is_ok then
				player.print(lua_code, RED_COLOR)
				return
			end

			if lua_code then
				code = lua_code
			else
				player.print(message, RED_COLOR)
				return
			end
		end

		if code == nil then
			player.print({"useful_book.empty_code_output_error"}, RED_COLOR)
			return
		end

		-- TODO: change for rcon!
		if is_command then
			local fake_event_data = {
				player_index = player.index,
				tick = game.tick,
				name = scroll_pane.UB_title.textfield.text
			}
			is_ok, _error = pcall(
				load("local event = " .. serpent.line(fake_event_data) ..
					"local player = game.get_player(event.player_index) " .. code
				)
			)
		else
			is_ok, _error = pcall(load(code), player)
		end
		if is_ok then return end

		local flow = element.parent
		local main_frame = flow.parent
		local error_message = main_frame.error_message
		error_message.caption = _error
		error_message.visible = true
		flow.UB_add_code.visible = false
		element.name = "UB_check_code"
		element.sprite = GuiTemplater.buttons.refresh.sprite
		element.hovered_sprite = GuiTemplater.buttons.refresh.hovered_sprite
		element.clicked_sprite = GuiTemplater.buttons.refresh.clicked_sprite
	end,
	UB_check_code = function(element, player)
		local flow = element.parent
		local main_frame = flow.parent
		local UB_linter = main_frame.scroll_pane.UB_linter
		---@type string
		local code = main_frame.scroll_pane.UB_program_input.text
		local compiler_id = flow.UB_compiler_id.selected_index
		if compiler_id == COMPILER_IDS.candran then
			local is_ok, result = pcall(candran.make, code)
			if is_ok then
				code = result
			else
				player.print(result, RED_COLOR)
				return
			end
		elseif compiler_id == COMPILER_IDS.teal then
			local _is_ok, result = pcall(tl.gen, code)
			if _is_ok then
				-- It should be improved somehow
				local __is_ok, __message = tl.load(code)
				if __is_ok then
					code = result
				else
					player.print(__message, RED_COLOR)
					return
				end
			else
				player.print(result, RED_COLOR)
				return
			end
		elseif compiler_id == COMPILER_IDS.moonscript then
			local is_ok, lua_code, message = pcall(moonscript.to_lua, code) -- TODO: perhaps, xpcall
			if not is_ok then
				player.print(lua_code, RED_COLOR)
				return
			end

			if lua_code then
				code = lua_code
			else
				player.print(message, RED_COLOR)
				return
			end
		end

		if code == nil then
			player.print({"useful_book.empty_code_output_error"}, RED_COLOR)
			UB_linter.text = ""
			UB_linter.visible = false
			return
		end

		if compiler_id ~= COMPILER_IDS.lua then
			UB_linter.text = ""
			UB_linter.visible = false
		else
			local report = luacheck.get_report(code)
			report = luacheck.process_reports({report}, LUACHECK_OPTIONS)
			if report[1] then
				local items = {}
				for i,v in ipairs(report[1]) do
					local str = luacheck.get_message(v)
					items[i] = str
				end
				if #items > 0 then
					table.insert(items, 1, "Luacheck: " .. luacheck._VERSION)
					table.insert(items, 2, "")
					if report.warnings > 0 then
						table.insert(items, 2, "Warnings: " .. report.warnings)
					end
					if report.errors > 0 then
						table.insert(items, 2, "Errors: " .. report.errors)
					end
					if report.fatals > 0 then
						table.insert(items, 2, "Fatals: " .. report.fatals)
					end
					local message = table.concat(items, "\n")
					UB_linter.text = message
					UB_linter.visible = true
				else
					UB_linter.text = ""
					UB_linter.visible = false
				end
			else
				UB_linter.text = ""
				UB_linter.visible = false
			end
		end

		local f = load(code)
		if type(f) == "function" then
			local UB_book_type = flow.UB_book_type.slider_value
			if UB_book_type ~= BOOK_TYPES.rcon and UB_book_type ~= BOOK_TYPES.custom_event then
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

		if import_scripts(UB_import_frame.children[2].UB_text_for_import.text, player) then
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
---@param event EventData.on_gui_click
function M.on_gui_click(event)
	local element = event.element
	if not (element and element.valid) then return end
	local player = game.get_player(event.player_index)
	execute_custom_event(event, player)

	local f = GUIS[element.name]
	if f then
		f(element, player, event)
	end
end


---@param event EventData.on_player_selected_area
function M.on_player_selected_area(event)
	local entities = event.entities
	if #entities == 0 then return end
	if event.item ~= "UB_admin_area_selection_tool" then return end
	local player_index = event.player_index
	local script_name = __players_admin_area_script[player_index]
	if script_name == nil then return end
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end
	if not player.admin then
		player.print({"command-output.parameters-require-admin"})
		return
	end

	local f = __compiled_admin_area_code[script_name]
	if f == nil then
		player.print("Such script doesn't exist anymore") -- TODO: add localization
		return
	end
	local is_ok, error = pcall(f, event.area, player, entities)
	if not is_ok then
		player.print(error, RED_COLOR)
	end
	execute_custom_event(event, player)
end


---@param event EventData.on_player_cursor_stack_changed
function M.on_player_cursor_stack_changed(event)
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
	execute_custom_event(event, player)
end

--#endregion


--#region Pre-game stage


---@param script_data table?
---@param compiled_script_data table
local function compile_script_data(script_data, compiled_script_data)
	if script_data == nil then return end
	for id, data in pairs(script_data) do
		local code = data.code
		if data.compiler_id == COMPILER_IDS.lua then
			compiled_script_data[id] = load(code)
		elseif data.compiler_id == COMPILER_IDS.candran then
			code = candran.make(code)
			compiled_script_data[id] = load(code)
		elseif data.compiler_id == COMPILER_IDS.teal then
			compiled_script_data[id] = tl.load(code)
		elseif data.compiler_id == COMPILER_IDS.moonscript then
			compiled_script_data[id] = moonscript.loadstring(code)
		end
	end
end

local function compile_all_text()
	compile_script_data(__admin_script_data , __compiled_admin_code)
	compile_script_data(__public_script_data, __compiled_public_code)
	compile_script_data(__admin_hotkey_script_data , __compiled_admin_hotkey_code)
	compile_script_data(__public_hotkey_script_data, __compiled_public_hotkey_code)
	compile_script_data(__admin_area_script_data, __compiled_admin_area_code)
	compile_script_data(__rcon_script_data, __compiled_rcon_code)
	for name, data in pairs(__custom_commands_data or {}) do
		if data.is_added then
			if game and not commands.commands[name] and not commands.game_commands[name] then
				data.is_added = true
				local f = format_command_code(data.code, data.compiler_id)
				__compiled_commands_code[name] = f
				commands.add_command(name, data.description or '', f) -- Perhaps, I should do something about other cases
				log("Added new command : " .. name)
			elseif game == nil then
				local f = format_command_code(data.code, data.compiler_id)
				__compiled_commands_code[name] = f
				commands.add_command(name, data.description or '', f) -- Perhaps, I should do something about other cases
				log("Added new command : " .. name)
			else
				data.is_added = false
			end
		end
	end
	for event_name, events_data in pairs(__custom_events_data or {}) do
		local event_id = defines.events[event_name]
		if event_id then
			__compiled_custom_events_data[event_id] = __compiled_custom_events_data[event_id] or {}
			local compiled_N_custom_events = __compiled_custom_events_data[event_id]
			for name, data in pairs(events_data) do
				local code = data.code
				if data.compiler_id == COMPILER_IDS.lua then
					compiled_N_custom_events[name] = load(code)
				elseif data.compiler_id == COMPILER_IDS.candran then
					code = candran.make(code)
					compiled_N_custom_events[name] = load(code)
				elseif data.compiler_id == COMPILER_IDS.teal then
					compiled_N_custom_events[name] = tl.load(code)
				elseif data.compiler_id == COMPILER_IDS.moonscript then
					compiled_N_custom_events[name] = moonscript.loadstring(code)
				end
			end
			add_custom_event(event_id)
		end
	end
end

local function link_data()
	__mod_data = global.useful_book
	__public_script_data = __mod_data.public_script_data
	__admin_script_data  = __mod_data.admin_script_data
	__admin_area_script_data = __mod_data.admin_area_script_data
	__rcon_script_data = __mod_data.rcon_script_data
	__custom_commands_data = __mod_data.custom_commands_data
	__players_admin_area_script = __mod_data.players_admin_area_script
	__custom_events_data = __mod_data.custom_events_data
	__public_hotkey_script_data = __mod_data.public_hotkey_script_data
	__admin_hotkey_script_data  = __mod_data.admin_hotkey_script_data
end

local function update_global_data()
	global.useful_book = global.useful_book or {}
	__mod_data = global.useful_book
	__mod_data.public_script_data = __mod_data.public_script_data or {}
	__mod_data.admin_script_data  = __mod_data.admin_script_data  or {}
	__mod_data.admin_area_script_data = __mod_data.admin_area_script_data or {}
	__mod_data.rcon_script_data   = __mod_data.rcon_script_data or {}
	__mod_data.custom_commands_data = __mod_data.custom_commands_data or {}
	__mod_data.custom_events_data   = __mod_data.custom_events_data   or {}
	__mod_data.public_hotkey_script_data = __mod_data.public_hotkey_script_data or {}
	__mod_data.admin_hotkey_script_data  = __mod_data.admin_hotkey_script_data  or {}
	---@type table<int, table<int, string[]>>
	__mod_data.public_script_bindings = __mod_data.public_script_bindings or {}
	---@type table<int, table<int, string[]>>
	__mod_data.admin_script_bindings  = __mod_data.admin_script_bindings or {}
	---@type table<string, table<integer, integer>>
	__mod_data.public_hotkey_scripts_ticks = __mod_data.public_hotkey_scripts_ticks or {}
	__mod_data.players_admin_area_script = {}
	__mod_data.last_public_id = __mod_data.last_public_id or 0
	__mod_data.last_admin_id  = __mod_data.last_admin_id  or 0

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

local is_on_init = false
M.on_init = function()
	is_on_init = true
	update_global_data()
	local UB_json_data = settings.global.UB_json_data.value
	if UB_json_data == '' then
		reset_scripts()
	else
		import_scripts(UB_json_data)
	end
end

M.on_configuration_changed = function(event)
	local mod_changes = event.mod_changes["useful_book"]
	if not (mod_changes and mod_changes.old_version) then return end
	if is_on_init == false then
		update_global_data()
	end

	local old_version = tonumber(string.gmatch(mod_changes.old_version, "%d+.%d+")())

	if old_version < 0.22 then
		for _, player in pairs(game.players) do
			-- it's in order to avoid potential bugs
			destroy_GUI(player)
		end
	end
	if old_version < 0.21 then
		for _, player in pairs(game.players) do
			-- it's in order to avoid potential bugs
			destroy_GUI(player)
		end
		add_admin_hotkey_script(
			"unstuck", "executes teal code",
			"local player, event = ..." ..
			"local character = player.character" ..
			"if not (character and character.valid) then return end\n" ..
			"local new_position = character.surface.find_non_colliding_position(character.name, character.position, 20, 1)" ..
			"if not new_position then return end\n" ..
			"player.teleport(new_position, character.surface)",
			COMPILER_IDS.lua
		)
	end
	if old_version < 0.19 then
		local function adapt_scripts(scripts)
			for _, data in pairs(scripts) do
				fix_old_data(data)
			end
		end
		adapt_scripts(__public_script_data)
		adapt_scripts(__admin_script_data)
		adapt_scripts(__admin_area_script_data)
		adapt_scripts(__rcon_script_data)
		adapt_scripts(__custom_commands_data)

		add_new_command(
			"tl", "executes teal code",
			"if event.parameter == nil then return end\n" ..
			"if event.player_index == 0 then\n" ..
			"	tl.load(event.parameter)()\n" ..
			"	return\n" ..
			"end\n" ..
			"if not player then return end\n" ..
			"if not player.admin then\n" ..
			"	player.print({'prohibited-server-command'})\n" ..
			"	return\n" ..
			"end\n" ..
			"tl.load(event.parameter)()",
			COMPILER_IDS.lua
		)
		add_new_command(
			"candran", "executes candran code",
			"if event.parameter == nil then return end\n" ..
			"if event.player_index == 0 then\n" ..
			"	load(candran.make(event.parameter))()\n" ..
			"	return\n" ..
			"end\n" ..
			"if not player then return end\n" ..
			"if not player.admin then\n" ..
			"	player.print({'prohibited-server-command'})\n" ..
			"	return\n" ..
			"end\n" ..
			"load(candran.make(event.parameter))()",
			COMPILER_IDS.lua
		)
	end

	if old_version < 0.18 then
		local function adapt_scripts(scripts)
			for _, data in pairs(scripts) do
				data.compiler_id = COMPILER_IDS.lua
			end
		end
		adapt_scripts(__public_script_data)
		adapt_scripts(__admin_script_data)
		adapt_scripts(__admin_area_script_data)
		adapt_scripts(__rcon_script_data)
		adapt_scripts(__custom_commands_data)
	end

	if old_version < 0.17 then
		local function adapt_scripts(scripts)
			for _, data in pairs(scripts) do
				data.version = data.version or "0.16.2"
			end
		end
		adapt_scripts(__public_script_data)
		adapt_scripts(__admin_script_data)
		adapt_scripts(__admin_area_script_data)
		adapt_scripts(__rcon_script_data)
	end

	if old_version < 0.16 then
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
			COMPILER_IDS.lua,
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
			COMPILER_IDS.lua,
			"0.15"
		)
	end

	if old_version < 0.15 then
		add_rcon_script(
			"Print Twitch message", "",
			'local username, message = ...\
			game.print({"", "[color=purple][Twitch][/color] ", username, {"colon"}, " ", message})',
			COMPILER_IDS.lua,
			"0.14"
		)
	end

	if old_version < 0.11 then
		add_admin_script(
			{"scripts-titles.kill-half-enemies"},
			{"scripts-description.kill-half-enemies"},
			'local player = ...\
			local raise_destroy = {raise_destroy=true}\
			local entities = player.surface.find_entities_filtered({force="enemy"})\
			for i=1, #entities, 2 do\
				entities[i].destroy(raise_destroy)\
			end',
			COMPILER_IDS.lua,
			nil,
			"0.10"
		)
	end

	if old_version < 0.10 then
		for _, player in pairs(game.players) do
			if player.valid then
				local UB_book = player.gui.relative.UB_book
				if UB_book then
					UB_book.destroy()
				end
				create_left_relative_gui(player)
			end
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
			return __mod_data
		end,
		reset_scripts = reset_scripts,
		delete_admin_script = function(id)
			__admin_script_data[id] = nil
			__compiled_admin_code[id] = nil
		end,
		delete_public_script = function(id)
			__public_script_data[id] = nil
			__compiled_public_code[id] = nil
		end,
		delete_admin_area_script = function(name)
			__admin_area_script_data[name] = nil
			__compiled_admin_area_code[name] = nil
		end,
		delete_rcon_script = function(name)
			__rcon_script_data[name] = nil
			__compiled_rcon_code[name] = nil
		end,
		delete_custom_event_script = function(event_name, name)
			local events_data = __custom_events_data[event_name]
			if events_data == nil then return end
			events_data[name] = nil
			local event_id = defines.events[event_name]
			if event_id == nil then return end
			local compiled_events = __compiled_custom_events_data[event_id]
			if compiled_events == nil then return end
			compiled_events[name] = nil
		end,
		delete_command = function(name)
			if __custom_commands_data[name] == nil then return end
			if __compiled_commands_code[name] then
				__compiled_commands_code[name] = nil
			end
			__custom_commands_data[name] = nil
		end,
		add_admin_script = add_admin_script,
		add_public_script = add_public_script,
		add_admin_area_script = add_admin_area_script,
		add_rcon_script = add_rcon_script,
		add_custom_event_script = add_custom_event_script,
		add_new_command = add_new_command,
		run_admin_script = function(id, player)
			local f = __compiled_public_code[id]
			if f == nil then return end
			local is_ok, error = pcall(f, player)
			if not is_ok then
				player.print(error, RED_COLOR)
			end
		end,
		run_public_script = function(id, player)
			local f = __compiled_public_code[id]
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
	UB_event_names = function(element, player)
		local selected_index = element.selected_index
		element.parent.parent.parent.destroy()
		switch_book(player, BOOK_TYPES.custom_event, selected_index)
	end,
	UB_admin_area_scripts_drop_down = function(element, player)
		local selected_index = element.selected_index
		__players_admin_area_script[player.index] = element.items[selected_index]
	end,
	UB_compiler_id = function(element, player)
		--TODO: refactor
		local content_frame = element.parent.parent
		local button = content_frame.buttons_row.UB_run_code
		local UB_linter = content_frame.scroll_pane.UB_linter
		if button then
			button.name = "UB_check_code"
			button.sprite = GuiTemplater.buttons.refresh.sprite
			button.hovered_sprite = GuiTemplater.buttons.refresh.hovered_sprite
			button.clicked_sprite = GuiTemplater.buttons.refresh.clicked_sprite
			button = content_frame.buttons_row.UB_add_code
			button.visible = false
		end

		if element.selected_index ~= COMPILER_IDS.lua then
			UB_linter.visible = false
		elseif #UB_linter.text > 0 then
			UB_linter.visible = true
		end
	end
}
M.events = {
	[defines.events.on_gui_click] = M.on_gui_click,
	[defines.events.on_gui_text_changed] = M.on_gui_text_changed,
	[defines.events.on_player_created] = M.on_player_created,
	[defines.events.on_player_removed] = M.on_player_removed,
	[defines.events.on_player_joined_game] = function(event)
		local player = game.get_player(event.player_index)
		destroy_GUI(player)
		execute_custom_event(event, player)
	end,
	[defines.events.on_player_left_game] = function(event)
		local player = game.get_player(event.player_index)
		destroy_GUI(player)
		execute_custom_event(event, player)
	end,
	[defines.events.on_player_demoted] = function(event)
		local player_index = event.player_index
		local player = game.get_player(player_index)

		destroy_GUI(player)
		execute_custom_event(event, player)

		__mod_data.admin_script_bindings[player_index] = nil
	end,
	[defines.events.on_player_selected_area] = M.on_player_selected_area,
	[defines.events.on_player_cursor_stack_changed] = M.on_player_cursor_stack_changed,
	[defines.events.on_runtime_mod_setting_changed] = function(event)
		local player
		local player_index = event.player_index
		if player_index then
			player = game.get_player(player_index)
		end
		execute_custom_event(event, player)
	end,
	[defines.events.on_gui_selection_state_changed] = function(event)
		local element = event.element
		if not (element and element.valid) then return end
		local f = DROP_DOWN_GUIS_FUNCS[element.name]
		local player = game.get_player(event.player_index)
		if f then
			f(element, player)
		end
		execute_custom_event(event, player)
	end
}


if script.mod_name ~= "level" then
	local inputs = {}
	for i=1, 100 do
		inputs[#inputs+1] = "UB_hotkey_" .. i
	end
	script.on_event(inputs, function(event)
		local player_index = event.player_index
		local player = game.get_player(event.player_index)
		if not (player and player.valid) then return end

		local _, _, hotkey = event.input_name:find("^UB_hotkey_(.+)")
		hotkey = tonumber(hotkey)

		local game_tick = event.tick
		local hotkey_scripts_tick = __mod_data.public_hotkey_scripts_ticks
		local script_hotkeys = __mod_data.public_script_bindings[player_index]
		if script_hotkeys then
			local script_names = script_hotkeys[hotkey]
			if script_names then
				for i=#script_names, 1, -1 do
					local script_name = script_names[i]
					local hotkey_script_ticks = hotkey_scripts_tick[script_name]
					if hotkey_script_ticks == nil then
						hotkey_scripts_tick[script_name] = {
							[player_index] = game_tick
						}
					else
						local tick = hotkey_script_ticks[player_index]
						if tick == nil then
							hotkey_script_ticks[player_index] = {
								[player_index] = game_tick
							}
						elseif tick ~= game_tick then
							hotkey_script_ticks[player_index] = game_tick
						else
							goto continue
						end
					end

					local f = __compiled_public_hotkey_code[script_name]
					if f then
						local is_ok, error = pcall(f, player, event)
						if not is_ok then
							player.print(error, RED_COLOR)
						end
					else
						table.remove(script_names, i)
					end
				    ::continue::
				end
			end
		end

		local script_hotkeys = __mod_data.admin_script_bindings[player_index]
		if script_hotkeys then
			local script_names = script_hotkeys[hotkey]
			if script_names then
				for i=#script_names, 1, -1 do
					local script_name = script_names[i]
					local f = __compiled_admin_hotkey_code[script_name]
					if f then
						local is_ok, error = pcall(f, player, event)
						if not is_ok then
							player.print(error, RED_COLOR)
						end
					else
						table.remove(script_names, i)
					end
				end
			end
		end
	end)
end


---@type table<string, fun(cmd: CustomCommandData)>
M.commands = {
	["Ubook-export"] = function(cmd)
		local raw_data = {
			public = {},
			admin = {},
			admin_area = __admin_area_script_data,
			rcon = __rcon_script_data,
			commands = __custom_commands_data,
			custom_events = __custom_events_data,
			public_hotkey_scripts = __public_hotkey_script_data,
			admin_hotkey_scripts  = __admin_hotkey_script_data,
		}

		local public_data = raw_data.public
		local admin_data = raw_data.admin
		for _, data in pairs(__public_script_data) do
			public_data[#public_data+1] = data
		end
		for _, data in pairs(__admin_script_data) do
			admin_data[#admin_data+1] = data
		end

		local filename = "useful_book_scripts.json"
		local json = game.table_to_json(raw_data)
		game.write_file(filename, json, false, cmd.player_index)

		local message = "All scripts has been exported in ...script-output/" .. filename
		local target
		-- TODO: add localization
		if cmd.player_index > 0 then
			target = game.get_player(cmd.player_index)
			target.print(message)
		else
			print(message)
		end
	end,
	["Ubook-import"] = function(cmd)
		import_scripts(cmd.parameter, game.get_player(cmd.player_index))
	end,
	["Ubook-reset"] = reset_scripts,
	["bind-admin-script"] = function(cmd)
		---@type int
		local player_index = cmd.player_index
		local player = game.get_player(player_index)
		---@cast player LuaPlayer
		local parameter = cmd.parameter or ""

		local start_i, _, hotkey = parameter:find("(%d+)%s*$")
		if hotkey then
			hotkey = tonumber(hotkey)
		end
		if hotkey == nil then
			player.print("useful_book-commands.bind-admin-script", RED_COLOR)
			return
		end

		local script_name = parameter:sub(1, start_i - 1)
		script_name = script_name:match'^%s*(.*%S)' -- trim
		if script_name == nil then
			player.print("useful_book-commands.bind-admin-script", RED_COLOR)
			return
		end

		local f = __compiled_admin_hotkey_code[script_name]
		if f == nil then
			-- TODO: add localization and improve
			player.print("There are no such script", RED_COLOR)
			return
		end

		-- TODO: add localization
		local message = "Script has been binded to a hotkey"
		local bindings = __mod_data.admin_script_bindings
		bindings[player_index] = bindings[player_index] or {}
		bindings = bindings[player_index]
		if bindings[hotkey] == nil then
			bindings[hotkey] = {script_name}
			player.print(message, GREEN_COLOR)
			return
		end

		bindings = bindings[player_index]
		for i, v in pairs(bindings) do
			if v == script_name then
				-- TODO: add localization
				player.print("Script has been unbinded to the hotkey", YELLOW_COLOR)
				table.remove(bindings, i)
				return
			end
		end

		bindings[#bindings+1] = script_name
		player.print(message, GREEN_COLOR)
	end,
	["bind-public-script"] = function(cmd)
		---@type int
		local player_index = cmd.player_index
		local player = game.get_player(player_index)
		---@cast player LuaPlayer
		local parameter = cmd.parameter or ""

		local start_i, _, hotkey = parameter:find("(%d+)%s*$")
		if hotkey then
			hotkey = tonumber(hotkey)
		end
		if hotkey == nil then
			player.print("useful_book-commands.bind-admin-script", RED_COLOR)
			return
		end

		local script_name = parameter:sub(1, start_i - 1)
		script_name = script_name:match'^%s*(.*%S)' -- trim
		if script_name == nil then
			player.print("useful_book-commands.bind-admin-script", RED_COLOR)
			return
		end

		local f = __compiled_public_hotkey_code[script_name]
		if f == nil then
			-- TODO: add localization and improve
			player.print("There are no such script", RED_COLOR)
			return
		end

		-- TODO: add localization
		local message = "Script has been binded to the hotkey"
		local bindings = __mod_data.public_script_bindings
		bindings[player_index] = bindings[player_index] or {}
		bindings = bindings[player_index]
		if bindings[hotkey] == nil then
			bindings[hotkey] = {script_name}
			player.print(message, GREEN_COLOR)
			return
		end

		bindings = bindings[player_index]
		for i, v in pairs(bindings) do
			if v == script_name then
				-- TODO: add localization
				player.print("Script has been unbinded to the hotkey", YELLOW_COLOR)
				table.remove(bindings, i)
				return
			end
		end

		if #bindings < 3 then
			bindings[#bindings+1] = script_name
		else
			-- TODO: add localization
			player.print("You can't bind more than 3 scripts to a hothey", RED_COLOR)
			return
		end

		player.print(message, GREEN_COLOR)
	end,
}

return M
