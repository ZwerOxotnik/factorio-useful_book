local event_handler = require("event_handler")

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

event_handler.add_libraries(modules)
