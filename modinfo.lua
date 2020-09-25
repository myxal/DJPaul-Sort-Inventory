name        = "DJPaul's Sort Inventory"
description = "Automatically stacks and sorts your inventory into a sensible order."
author      = "Paul Gibbs (DJPaul)"
version     = "1.9c"
forumthread = "/topic/54138-new-mod-djpauls-sort-inventory/"

api_version                = 10  -- DST api version
dont_starve_compatible     = false
reign_of_giants_compatible = false
shipwrecked_compatible     = false
dst_compatible             = true
priority                   = 0  -- Relative load order
server_filter_tags         = { "djpaul", "sort inventory" }
icon_atlas                 = "modicon.xml"
icon                       = "modicon.tex"

client_only_mod         = false
all_clients_require_mod = true

configuration_options = {
	{
		default = 103,  -- ASCII code for "g"
		label   = "Press to sort:",
		name    = "keybind",
		options = (function()
			local KEY_A  = 97  -- ASCII code for "a"
			local values = {}
			local chars  = {
				"A","B","C","D","E","F","G","H","I","J","K","L","M",
				"N","O","P","Q","R","S","T","U","V","W","X","Y","Z"
			}

			for i = 1, #chars do
				values[#values + 1] = { description = chars[i], data = i + KEY_A - 1 }
			end

			return values
		end)()
	},
	{
		default = 2,
		label   = "Preferred torch count:",
		name    = "maxLights",
		options = (function()
			local values = {}
			for i = 1, 10 do
				values[#values + 1] = { description = i, data = i }
			end

			return values
		end)()
	},
	{
		default = "resources",
		label   = "Store these in backpack:",
		name    = "backpackCategory",
		options = {
			{ description = "Armour",    data = "armour" },
			{ description = "Food",      data = "food" },
			{ description = "Junk",      data = "misc" },
			{ description = "Lights",    data = "light" },
			{ description = "Resources", data = "resources" },
			{ description = "Tools",     data = "tools" },
			{ description = "Weapons",   data = "weapons" },
		}
	},
	{
		default = "yes",
		label   = "Fun Mode?",
		name    = "funMode",
		options = {
			{ description = "Yes", data = "yes" },
			{ description = "No",  data = "no" },
		}
	},
}
