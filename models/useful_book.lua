---@class UB : module
local M = {}

--#region Global data
local mod_data
---@type table <number, table>
local public_script_data
---@type table <number, table>
local admin_script_data
--#endregion

---@type table <number, function>
local compiled_public_code = {}
---@type table <number, function>
local compiled_admin_code = {}


--#region Constants
local DEFAULT_TEXT = "local player = ...\nplayer.print(player.name)"
local FLOW = {type = "flow"}
local EMPTY_WIDGET = {type = "empty-widget"}
local RED_COLOR = {1, 0, 0}
local print_to_rcon = rcon.print
--#endregion


if script.mod_name ~= "useful_book" then
	remote.remove_interface("disable-useful_book")
	remote.add_interface("disable-useful_book", {})
end


--#region Function for RCON

---@param name string
function getRconData(name)
	print_to_rcon(game.table_to_json(mod_data[name]))
end

--#endregion


--#region utils

---@param json string
---@param player? LuaPlayer
function import_scripts(json, player)
	-- TODO: improve (check erros)
	local raw_data = game.json_to_table(json)
	if raw_data.public then
		for _, data in pairs(raw_data.public) do
			add_public_script(data.title, data.descripton, data.code)
		end
	end
	if raw_data.admin then
		for _, data in pairs(raw_data.admin) do
			add_admin_script(data.title, data.descripton, data.code)
		end
	end

	local target = player or game
	-- TODO: add localization
	target.print("Scripts has been imported for \"useful book\"")
end

function reset_scripts()
	mod_data.admin_script_data = {}
	admin_script_data = mod_data.admin_script_data
	mod_data.public_script_data = {}
	public_script_data = mod_data.public_script_data
	ompiled_admin_code = {}
	compiled_public_code = {}
	add_admin_script(
		{"scripts-titles.reveal-gen-map"},
		{"scripts-description.reveal-gen-map"},
		"local player = ...\nplayer.force.chart_all()"
	)
	add_admin_script(
		{"scripts-titles.kill-all-enemies"},
		{"scripts-description.kill-all-enemies"},
		'local player = ...\
		local entities = player.surface.find_entities_filtered({force="enemy"})\
		for i=1, #entities do\
			entities[i].destroy()\
		end'
	)
	add_admin_script(
		{"scripts-titles.kill-half-enemies"},
		{"scripts-description.kill-half-enemies"},
		'local player = ...\
		local entities = player.surface.find_entities_filtered({force="enemy"})\
		for i=1, #entities, 2 do\
			entities[i].destroy()\
		end'
	)
	add_admin_script(
		{"scripts-titles.reg-resources"},
		{"scripts-description.reg-resources"},
		'local player = ...\n\
		local surface = player.surface\
		local entities = surface.find_entities_filtered{type="resource"}\
		for i=1, #entities do\
			local e = entities[i]\
			if e.prototype.infinite_resource then\
				e.amount = e.initial_amount\
			else\
				e.destroy()\
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

	for _, player in pairs(game.players) do
		if player.valid and player.admin then
			-- TODO: add localization
			player.print("Scripts has been reset for \"useful book\"")
		end
	end
end

-- Replaces tabulation with 2 spaces and removes unnecessary spaces
---@param code string
---@return string #code
function format_code(code)
	return code:gsub("[ ]+\n", "\n"):gsub("\t", "  ")
end

---@param title string|LocalisedString
---@param description? string
---@param code string
---@return number? #id
function add_admin_script(title, description, code)
	code = format_code(code)
	local f = load(code)
	if type(f) == "function" then
		local id = mod_data.last_admin_id + 1
		mod_data.last_admin_id = id
		compiled_admin_code[id] = load(code)
		admin_script_data[id] = {
			description = description,
			title = title,
			code = code
		}
		return id
	end
end

---@param title string|LocalisedString
---@param description? string
---@param code string
---@return number? #id
function add_public_script(title, description, code)
	code = format_code(code)
	local f = load(code)
	if type(f) == "function" then
		local id = mod_data.last_public_id + 1
		mod_data.last_public_id = id
		compiled_public_code[id] = load(code)
		public_script_data[id] = {
			description = description,
			title = title,
			code = code
		}
		return id
	end
end

local function destroy_GUI_event(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	local screen = player.gui.screen
	if screen.UB_book_frame then
		screen.UB_book_frame.destroy()
	end
	if screen.UB_code_editor then
		screen.UB_code_editor.destroy()
	end
end

---@param player PlayerIdentification
---@param is_public_code boolean
---@param id? number
function open_code_editor(player, is_public_code, id)
	local screen = player.gui.screen
	if screen.UB_code_editor then
		screen.UB_code_editor.destroy()
		return
	end

	local data
	if id then
		if is_public_code then
			data = public_script_data[id]
		else
			data = admin_script_data[id]
		end
	end

	local main_frame = screen.add{type = "frame", name = "UB_code_editor", direction = "vertical"}
	local flow = main_frame.add(FLOW)
	flow.add{
		type = "label",
		style = "frame_title",
		caption = {"useful_book.code_editor"},
		ignored_by_interaction = true
	}
	local drag_handler = flow.add{type = "empty-widget", style = "draggable_space"}
	drag_handler.drag_target = main_frame
	drag_handler.style.right_margin = 0
	drag_handler.style.horizontally_stretchable = true
	drag_handler.style.height = 32
	flow.add{
		type = "sprite-button",
		name = "UB_close",
		style = "frame_action_button",
		sprite = "utility/close_white",
		hovered_sprite = "utility/close_black",
		clicked_sprite = "utility/close_black"
	}

	flow = main_frame.add(FLOW)
	flow.name = "buttons_row"
	local content = {type = "sprite-button"}
	content.name = "UB_check_code"
	content.sprite = "refresh"
	flow.add(content)
	content.name = "UB_add_code"
	content.sprite = "plus_white"
	flow.add(content).visible = false
	flow.add{type = "label", caption = {'', {"useful_book.is_public_script"}, {"colon"}}}
	flow.add{type = "checkbox", name = "UB_is_public_script", state = is_public_code, enabled = id and false}
	if id then
		flow.add{type = "label", name = "id", caption = tonumber(id), visible = false}
	end

	main_frame.add({type = "label", name = "error_message", style = "bold_red_label", visible = false})

	local scroll_pane = main_frame.add{type = "scroll-pane", name = "scroll_pane"}
	flow = scroll_pane.add(FLOW)
	flow.name = "UB_title"
	flow.add{type = "label", caption = {'', "Title", {"colon"}}}

	local is_text = (data == nil) or (type(data.title) == "string")
	if is_text then
		local textfield = flow.add{type = "textfield", name = "textfield"}
		textfield.text = data and data.title or ''
		textfield.style.horizontally_stretchable = true
		textfield.style.maximal_width = 0
	else
		flow.add{type = "label", name = "textfield", caption = data.title}
	end

	is_text = (data == nil) or (type(data.title) == "string")
	if is_text then
		scroll_pane.add{type = "label", caption = {'', "Description", {"colon"}}}
		local text_box = scroll_pane.add{type = "text-box", name = "UB_description"}
		text_box.text = data and data.description or ''
		text_box.style.horizontally_stretchable = true
		text_box.style.maximal_width = 0
		text_box.style.height = 90
	else
		scroll_pane.add{type = "label", name = "UB_description", caption = data.title, visible = false}
	end

	local input = scroll_pane.add{type = "text-box", name = "UB_program_input", style = "UB_program_input"}
	input.text = data and data.code or DEFAULT_TEXT
	main_frame.force_auto_center()
end

local function fill_with_public_data(table_element, player)
	local LABEL = {type = "label"}
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
	local LABEL = {type = "label"}
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

---@param player PlayerIdentification
---@param is_public_data boolean
function switch_book(player, is_public_data)
	local screen = player.gui.screen
	if screen.UB_book_frame then
		screen.UB_book_frame.destroy()
	end

	local main_frame = screen.add{type = "frame", name = "UB_book_frame", direction = "vertical"}
	main_frame.style.minimal_width = 260
	local flow = main_frame.add(FLOW)
	flow.add{
		type = "label",
		style = "frame_title",
		caption = {"mod-name.useful_book"},
		ignored_by_interaction = true
	}
	local drag_handler = flow.add{type = "empty-widget", style = "draggable_space"}
	drag_handler.drag_target = main_frame
	drag_handler.style.right_margin = 0
	drag_handler.style.horizontally_stretchable = true
	drag_handler.style.height = 32
	if player.admin then
		flow.add{
			type = "sprite-button",
			name = "UB_open_code_editor",
			style = "frame_action_button",
			sprite = "plus_white",
			hovered_sprite = "plus",
			clicked_sprite = "plus"
		}
	end
	flow.add{
		type = "sprite-button",
		name = "UB_close",
		style = "frame_action_button",
		sprite = "utility/close_white",
		hovered_sprite = "utility/close_black",
		clicked_sprite = "utility/close_black"
	}

	local title_table = main_frame.add{type = "table", column_count = 3}
	title_table.add(EMPTY_WIDGET).style.horizontally_stretchable = true
	if is_public_data then
		title_table.add{type = "label", caption = {"useful_book.public_scripts"}}
	else
		title_table.add{type = "label", caption = {"useful_book.admin_scripts"}}
	end
	if player.admin then
		if is_public_data then
			title_table.name = "public_cover"
		else
			title_table.name = "admin_cover"
		end
		local sub_flow = title_table.add(FLOW)
		sub_flow.style.horizontally_stretchable = true
		sub_flow.add{
			type = "sprite-button",
			name = "UB_change_book",
			style = "frame_action_button",
			sprite = "utility/reset_white",
			hovered_sprite = "utility/reset",
			clicked_sprite = "utility/reset"
		}
	else
		title_table.add(EMPTY_WIDGET).style.horizontally_stretchable = true
	end

	local scroll_pane = main_frame.add{type = "scroll-pane", name = "scroll_pane"}
	local scripts_table = scroll_pane.add{type = "table", column_count = 2}
	if is_public_data then
		fill_with_public_data(scripts_table, player)
	else
		fill_with_admin_data(scripts_table)
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
				open_code_editor(player, not event.shift)
			else
				switch_book(player, not event.shift)
			end
		else
			local UB_book_frame = player.gui.screen.UB_book_frame
			if UB_book_frame then
				UB_book_frame.destroy()
			else
				if next(public_script_data) == nil then
					player.print({"useful_book.no-public-scripts"})
				else
					switch_book(player, true)
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
		public_script_data[id] = nil
		compiled_public_code[id] = nil
		local flow = element.parent
		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()
	end,
	UB_delete_admin_code = function(element, player)
		local id = tonumber(element.parent.name)
		admin_script_data[id] = nil
		compiled_admin_code[id] = nil
		local flow = element.parent
		flow.parent.children[flow.get_index_in_parent() - 1].destroy()
		flow.destroy()
	end,
	UB_change_public_script = function(element, player)
		open_code_editor(player, true, tonumber(element.parent.name))
	end,
	UB_change_admin_code = function(element, player)
		open_code_editor(player, false, tonumber(element.parent.name))
	end,
	UB_open_code_editor = function(element, player)
		player.gui.screen.UB_book_frame.destroy()
		open_code_editor(player, true)
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
		local is_public_code = UB_is_public_script.state
		local is_enabled = UB_is_public_script.enabled
		if not is_enabled then
			local id = tonumber(flow.id.caption)
			if is_public_code then
				compiled_public_code[id] = load(code)
				public_script_data[id] = {
					description = description,
					title = title,
					code = code
				}
			else
				compiled_admin_code[id] = load(code)
				admin_script_data[id] = {
					description = description,
					title = title,
					code = code
				}
			end
		else
			if is_public_code then
				add_public_script(title, description, code)
			else
				add_admin_script(title, description, code)
			end
		end
		element.parent.parent.destroy()
		switch_book(player, is_public_code)
	end,
	UB_run_code = function(element, player)
		local is_ok, error = pcall(load(element.parent.parent.scroll_pane.UB_program_input.text), player)
		if not is_ok then
			local main_frame = element.parent.parent
			local error_message = main_frame.error_message
			error_message.caption = error
			error_message.visible = true
			element.parent.UB_add_code.visible = false
			element.name = "UB_check_code"
			element.sprite = "refresh"
			element.hovered_sprite = ''
			element.clicked_sprite = ''
		end
	end,
	UB_check_code = function(element, player)
		local main_frame = element.parent.parent
		local f = load(main_frame.scroll_pane.UB_program_input.text)
		if type(f) == "function" then
			element.name = "UB_run_code"
			element.sprite = "lua_snippet_tool_icon_white"
			element.hovered_sprite = "utility/lua_snippet_tool_icon"
			element.clicked_sprite = "utility/lua_snippet_tool_icon"
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
	UB_change_book = function(element, player)
		local table_element = element.parent.parent
		if table_element.name == "admin_cover" then
			table_element.parent.destroy()
			switch_book(player, true)
		else
			table_element.parent.destroy()
			switch_book(player, false)
		end
	end
}
local function on_gui_click(event)
	local element = event.element
	if not (element and element.valid) then return end

	local f = GUIS[element.name]
	if f then
		f(element, game.get_player(event.player_index), event)
	end
end

--#endregion


--#region Pre-game stage

local function compile_all_text()
	for id, data in pairs(public_script_data) do
		compiled_public_code[id] = load(data.code)
	end
	for id, data in pairs(admin_script_data) do
		compiled_admin_code[id] = load(data.code)
	end
end

local function link_data()
	mod_data = global.useful_book
	public_script_data = mod_data.public_script_data
	admin_script_data = mod_data.admin_script_data
end

local function update_global_data()
	global.useful_book = global.useful_book or {}
	mod_data = global.useful_book
	mod_data.public_script_data = mod_data.public_script_data or {}
	mod_data.admin_script_data = mod_data.admin_script_data or {}
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

	if version < 0.11 then
		add_admin_script(
			{"scripts-titles.kill-half-enemies"},
			{"scripts-description.kill-half-enemies"},
			'local player = ...\
			local entities = player.surface.find_entities_filtered({force="enemy"})\
			for i=1, #entities, 2 do\
				entities[i].destroy()\
			end'
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
			return script.mod_name
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
		add_admin_script = add_admin_script,
		add_public_script = add_public_script,
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


M.events = {
	[defines.events.on_gui_click] = on_gui_click,
	[defines.events.on_gui_text_changed] = on_gui_text_changed,
	[defines.events.on_player_created] = on_player_created,
	[defines.events.on_player_joined_game] = destroy_GUI_event,
	[defines.events.on_player_left_game] = destroy_GUI_event,
	[defines.events.on_player_demoted] = destroy_GUI_event
}

M.commands = {
	["Ubook-export"] = function(cmd)
		local raw_data = {
			public = {},
			admin = {}
		}


		local public_data = raw_data.public
		local admin_data = raw_data.admin
		for _, data in pairs(public_script_data) do
			public_data[#public_data+1] = data
		end
		for _, data in pairs(admin_script_data) do
			admin_data[#admin_data+1] = data
		end

		local json = game.table_to_json(raw_data)
		game.write_file("useful_book_scripts.json", json, false, cmd.player_index)
		local target = game.get_player(cmd.player_index) or game
		-- TODO: add localization
		target.print("Json data has been exported on in ...script-output/useful_book_scripts.json")
	end,
	["Ubook-import"] = function(cmd)
		import_scripts(cmd.parameter, game.get_player(cmd.player_index))
	end,
	["Ubook-reset"] = reset_scripts,
}

return M
