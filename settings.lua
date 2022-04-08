require("models/BetterCommands/control"):create_settings() -- Adds switchable commands

data:extend({
	{type = "string-setting", name = "UB_json_data", setting_type = "runtime-global", default_value = '', allow_blank = true, auto_trim = true},
})