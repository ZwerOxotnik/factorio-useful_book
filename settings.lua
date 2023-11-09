local better_commands = require("__BetterCommands__/BetterCommands/control")
better_commands.COMMAND_PREFIX = "UB_"
better_commands.create_settings("useful_book", "UB_") -- Adds switchable commands


data:extend({
	{type = "string-setting", name = "UB_json_data", setting_type = "runtime-global", default_value = '', allow_blank = true, auto_trim = true},
})
