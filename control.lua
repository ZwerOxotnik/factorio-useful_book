---@type table<string, module>
local modules = {}
modules["useful_book"] = require("models/useful_book")
local module = modules["useful_book"]

if remote.interfaces["disable-useful_book"] then
	module.events = nil
	module.on_nth_tick = nil
	module.commands = nil
	module.on_load = nil
	module.add_remote_interface = nil
	module.add_commands = nil
end

local event_handler
if script.active_mods["zk-lib"] then
	event_handler = require("__zk-lib__/static-libs/lualibs/event_handler_vZO.lua")
else
	event_handler = require("event_handler")
end
event_handler.add_libraries(modules)
