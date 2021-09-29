if script.active_mods["useful_book"] then
	local event_handler = require("event_handler")
	event_handler.add_lib(require("__useful_book__/models/useful_book"))
end
