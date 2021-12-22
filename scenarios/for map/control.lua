if script.active_mods["useful_book"] then
	local event_handler
	if script.active_mods["zk-lib"] then
		event_handler = require("__zk-lib__/static-libs/lualibs/event_handler_vZO.lua")
	else
		event_handler = require("event_handler")
	end
	event_handler.add_lib(require("__useful_book__/models/useful_book"))
end
