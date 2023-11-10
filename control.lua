local zk_modules = require("__zk-lib__/defines").modules

---@type table<string, module>
local modules = {}
modules.better_commands = require("__BetterCommands__/BetterCommands/control")
modules.useful_book  = require("models/useful_book")
modules.GuiTemplater = require(zk_modules.static_libs.control_stage.GuiTemplater)

if remote.interfaces["disable-useful_book"] then
	local module = modules.useful_book
	module.events = nil
	module.on_nth_tick = nil
	module.commands = nil
	module.on_load = nil
	module.add_remote_interface = nil
	module.add_commands = nil
	local module = modules.GuiTemplater
	module.events = nil
	module.on_nth_tick = nil
	module.commands = nil
	module.on_load = nil
	module.add_remote_interface = nil
	module.add_commands = nil
end


local event_handler
if script.active_mods["zk-lib"] then
	-- Same as Factorio "event_handler", but slightly better performance
	local is_ok, zk_event_handler = pcall(require, zk_modules.static_libs.event_handler_vZO)
	if is_ok then
		event_handler = zk_event_handler
	end
end
event_handler = event_handler or require("event_handler")


modules.better_commands.COMMAND_PREFIX = "UB_"
modules.better_commands.handle_custom_commands(modules.useful_book) -- adds commands
if modules.better_commands.expose_global_data then
	modules.better_commands.expose_global_data()
end


event_handler.add_libraries(modules)


if script.active_mods["zk-lib"] then
	local is_ok, remote_interface_util = pcall(require, zk_modules.static_libs.control_stage.remote_interface_util)
	if is_ok and remote_interface_util.expose_global_data then
		remote_interface_util.expose_global_data()
	end
	local is_ok, rcon_util = pcall(require, zk_modules.static_libs.control_stage.rcon_util)
	if is_ok and rcon_util.expose_global_data then
		rcon_util.expose_global_data()
	end
end


-- This is a part of "gvv", "Lua API global Variable Viewer" mod. https://mods.factorio.com/mod/gvv
-- It makes possible gvv mod to read sandboxed variables in the map or other mod if following code is inserted at the end of empty line of "control.lua" of each.
if script.active_mods["gvv"] then require("__gvv__.gvv")() end
