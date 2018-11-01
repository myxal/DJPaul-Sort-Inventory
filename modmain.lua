-- GLOBAL.CHEATS_ENABLED = true
-- GLOBAL.require("debugkeys")
-- GLOBAL.require("debugtools")


--- Sort through the bag and return the items' new offsets.
--
-- @param items
-- @param bag
-- @param offset Item position within bag.
-- @return Sorted item offsets
local function sortItems(items, bag, offset)
	table.sort(items, function(a, b)

		-- Sort by name then value.
		if bag[offset].sortBy == 'name' then
			if bag[offset].contents[a].obj.name ~= bag[offset].contents[b].obj.name then
				return bag[offset].contents[a].obj.name < bag[offset].contents[b].obj.name
			end
			return bag[offset].contents[a].value > bag[offset].contents[b].value

		-- Sort by value then name.
		else
			if bag[offset].contents[a].value ~= bag[offset].contents[b].value then
				return bag[offset].contents[a].value > bag[offset].contents[b].value
			end
			return bag[offset].contents[a].obj.name < bag[offset].contents[b].obj.name
		end
	end)

	return items
end

--- Does the item provide armour?
--
-- @param inst InventoryItem object
-- @return bool
local function itemIsArmour(inst)
	return inst.components.armor ~= nil
end

--- Is the item a food for the current player?
--
-- @param inst InventoryItem object
-- @return bool
local function itemIsFood(inst)
	local itemIsGear = inst.components.edible and inst.components.edible.foodtype == GLOBAL.FOODTYPE.GEARS
	return inst.components.edible and (inst.components.perishable or itemIsGear)
end

--- Is the item a light?
--
-- @param inst InventoryItem object
-- @return bool
local function itemIsLight(inst)
	return inst.components.fueled and (inst.components.lighter or inst.HasTag == "light")
end

--- Is the item a priority resource?
-- These items were manually selected from a frequency analysis of recipe components in the game
-- as of 10th March 2015. The idea is that the player will care most about having a quantity of
-- these items (because they are used commonly in item recipes), so let's sort them together.
--
-- @param inst InventoryItem object
-- @return bool
local function itemIsResource(inst)
	-- Highest frequency to lowest fequency
	local items = {
		"Twigs",
		"Nightmare Fuel",
		"Rope",
		"Gold Nugget",
		"Boards",
		"Silk",
		"Papyrus",
		"Cut Grass",
		"Thulecite",
		"Cut Stone",
		"Flint",
		"Log",
		"Living Log",
		"Pig Skin",
		"Thulecite Fragments",
		"Rocks",
		"Nitre",
	}

	for i = 1, #items do
		local keys = {}
		if items[i] == inst.name then
			return true
		end
	end

	return false
end

--- Is the item a tool?
-- As of 28th August 2016, the only prefab with "terraformer" is the pitchfork.
--
-- @param inst InventoryItem object
-- @return bool
local function itemIsTool(inst)
	return inst.components.equippable and inst.components.finiteuses and (inst.components.tool or inst.components.terraformer)
end

--- Is the item a weapon?
--
-- @param inst InventoryItem object
-- @return bool
local function itemIsWeapon(inst)
	return inst.components.weapon ~= nil
end

--- Find the best slot in the backpack for an item. Suppports stacking.
-- Ported version of core's Inventory:GetNextAvailableSlot.
-- The backpack is a Container, not an Inventory object. See http://goo.gl/hX9R98
--
-- @param item InventoryItem object.
-- @param player
-- @return Offset, container.
local function getNextAvailableBackpackSlot(item, player)
	local inventory  = player.components.inventory
	local backpack   = inventory:GetOverflowContainer()
	local prefabName = nil

	-- Function assumes a backpack exists. Don't use it otherwise.
	if backpack == nil then
		return nil, nil
	end

	if item.components.stackable ~= nil then
		prefabName = item.prefab

		-- Check for stacks that aren't full.
		for k, v in pairs(inventory.itemslots) do
			if v.prefab == prefabName and v.components.stackable and not v.components.stackable:IsFull() then
				return k, inventory.itemslots
			end
		end

		for k, v in pairs(backpack.slots) do
			if v.prefab == prefabName and v.components.stackable and not v.components.stackable:IsFull() then
				return k, backpack
			end
		end
	end

	local empty = nil

	-- Check for empty space in the container.
	for k = 1, backpack.numslots do
		if backpack:CanTakeItemInSlot(item, k) and not backpack:GetItemInSlot(k) then

			if prefabName ~= nil then
				if empty == nil then
					empty = k
				end
			else
				return k, backpack
			end

		end
	end

	return empty, backpack
end

--- Find the best slot in a player's overall inventory for the specified item to be put in. Supports stacking.
--
-- @param player
-- @param item InventoryItem object.
-- @param bagPreference If new slot required, which container to use. Either "backpack" or "inventory".
-- @return Offset, inventory/container object.
local function getNextAvailableInventorySlot(player, item, bagPreference)
	local inventory         = player.components.inventory
	local backpack          = inventory:GetOverflowContainer()
	local backpackSlotCount = backpack and backpack:GetNumSlots() or 0

	local container = nil
	local slot      = nil


	-- Has the player chosen to store this type of item in their backpack?
	if bagPreference == "backpack" and backpack and backpack:NumItems() < backpackSlotCount then
		slot, container = getNextAvailableBackpackSlot(item, player)
		if slot == nil then
			slot, container = getNextAvailableInventorySlot(player, item, "inventory")
		end

	-- Has the player chosen to store this type of item in their inventory?
	-- Or, did they want to store it in their backpack, but it has no space?
	else
		slot, container = inventory:GetNextAvailableSlot(item)
		if slot == nil and backpack then
			slot, container = getNextAvailableInventorySlot(player, item, "backpack")
		end
	end

	-- If we got itemslots, return the original inventory
	-- equipslots are handled in the calling code!
	if slot then
		if container == inventory.itemslots then
			container = inventory
		end

		-- backpack is handled by default.
	end
	return slot, container
end

--- Sorts the player's inventory into a sensible order.
--
-- @param player Sort this player's inventory.
-- @param maxLights Max. number of torches to sort.
-- @param backpackCategory Category of item to sort into backpack.
local function sortInventory(player, maxLights, backpackCategory)
	local inventory    = player and player.components.inventory or nil
	local isPlayerHurt = (player.components.health:GetPercent() * 100) <= 30
	local backpack     = (inventory and inventory:GetOverflowContainer() and inventory:GetOverflowContainer().itemtestfn == nil) and inventory:GetOverflowContainer() or nil
	local armourBag    = { contents = {}, sortBy = 'value', type = 'armour' }
	local foodBag      = { contents = {}, sortBy = 'value', type = 'food' }
	local lightBag     = { contents = {}, sortBy = 'value', type = 'light' }
	local miscBag      = { contents = {}, sortBy = 'name',  type = 'misc' }
	local resourceBag  = { contents = {}, sortBy = 'name',  type = 'resources' }
	local toolBag      = { contents = {}, sortBy = 'name',  type = 'tools' }
	local weaponBag    = { contents = {}, sortBy = 'value', type = 'weapons' }

	if player:HasTag("playerghost") or not inventory then
		return
	end

	local backpackSlotCount = backpack and backpack:GetNumSlots() or 0
	local invSlotCount      = inventory:GetNumSlots()
	local totalSlots        = backpackSlotCount + invSlotCount


	-- Categorise the player's inventory.
	for i = 1, totalSlots do
		local item = nil

		-- Loop through the main inventory.
		if i <= invSlotCount then
			item = inventory:GetItemInSlot(i)

		-- Loop through the backpack.
		else
			if not backpack then
				return
			end

			item = backpack:GetItemInSlot(i - invSlotCount)
		end

		-- Figure out what kind of item we're dealing with.
		if item then
			local bag  = miscBag
			local sort = 0

			-- Armour (chest and head)
			if itemIsArmour(item) then
				bag  = armourBag
				sort = item.components.armor:GetPercent()

			-- Food
			elseif itemIsFood(item) then
				bag  = foodBag
				sort = isPlayerHurt and item.components.edible.healthvalue or item.components.edible.hungervalue

			-- Light
			elseif itemIsLight(item) then
				bag  = lightBag
				sort = item.components.fueled:GetPercent()

				-- If bag has more lights than maxLights, store the extras in miscBag.
				if #lightBag.contents >= maxLights then
					bag = miscBag
				end

			-- Priority resources
			elseif itemIsResource(item) then
				bag = resourceBag

			-- Tools
			elseif itemIsTool(item) then
				bag  = toolBag
				sort = item.components.finiteuses:GetUses()

			-- Weapons (MUST be below the tools block)
			elseif itemIsWeapon(item) then
				bag  = weaponBag
				sort = item.components.weapon.damage
			end


			table.insert(bag.contents, {
				obj   = item,
				value = sort
			})
		end

		-- Detach the item from the player's inventory.
		inventory:RemoveItem(item, true)
	end


	--[[
	"Oh you may not think I'm pretty,
	But don't judge on what you see,
	I'll eat myself if you can find
	A smarter hat than me."
	--]]
	local sortingHat = {
		lightBag,
		toolBag,
		weaponBag,
		foodBag,
		armourBag,
		resourceBag,
		miscBag,
	}


	-- Sort the categorised items.
	for i = 1, #sortingHat do
		local keys = {}
		for key in pairs(sortingHat[i].contents) do
			table.insert(keys, key)
		end

		-- keys contains the sorted order for the current bag (sortingHat[i]).
		keys = sortItems(keys, sortingHat, i)

		for _, key in ipairs(keys) do
			local bagPreference = "inventory"
			local itemObj       = sortingHat[i].contents[key].obj

			-- Has the player chosen to store this type of item in their backpack?
			if backpack and sortingHat[i].type == backpackCategory then
				bagPreference = "backpack"
			end

			-- Put the item in its sorted slot/container.
			local slot, container = getNextAvailableInventorySlot(player, itemObj, bagPreference)
			if slot ~= nil and container == inventory.equipslots then
				-- You can't GiveItem to equipslots. So manually combine the itemObj with the equipped stack.
				local eitem = inventory:GetEquippedItem(slot)
				-- Combine the sorted itemstack with the equipped stack. Remainder is returned to itemObj.
				itemObj = (eitem.components.stackable ~= nil) and eitem.components.stackable:Put(itemObj) or itemObj
				if itemObj ~= nil and itemObj:IsValid() then
					-- Giving remainder into inventory.
					local slot, container = getNextAvailableInventorySlot(player, itemObj, bagPreference)
					container:GiveItem(itemObj, slot, nil)
				else
					-- Should we do something with itemObj?
					print "The sorted item was consumed by the equipslot"
				end
			else
				container:GiveItem(itemObj, slot, nil)
			end
		end
	end

end

--- Inventory must be sorted server-side, so listen for a RPC.
AddModRPCHandler(modname, "dsiRemoteSortInventory", function(player, modVersion, maxLights, backpackCategory)
	sortInventory(player, maxLights, backpackCategory)
end)


--- Press "G" to sort your inventory.
GLOBAL.TheInput:AddKeyDownHandler(GetModConfigData("keybind"), function()
	if not (GLOBAL.TheFrontEnd:GetActiveScreen() and
			GLOBAL.TheFrontEnd:GetActiveScreen().name and
			type(GLOBAL.TheFrontEnd:GetActiveScreen().name) == "string" and
			GLOBAL.TheFrontEnd:GetActiveScreen().name == "HUD") then
		return
	end

	local backpackCategory = GetModConfigData("backpackCategory")
	local maxLights        = GLOBAL.tonumber(GetModConfigData("maxLights"))
	local modVersion       = GLOBAL.KnownModIndex:GetModInfo(modname).version

	-- Server-side
	if GLOBAL.TheNet:GetIsServer() then
		sortInventory(GLOBAL.ThePlayer, maxLights, backpackCategory)

	-- Client-side
	else
		SendModRPCToServer(MOD_RPC[modname]["dsiRemoteSortInventory"], modVersion, maxLights, backpackCategory)
	end

	if GLOBAL.ThePlayer and GetModConfigData("funMode") == "yes" then
		GLOBAL.ThePlayer.SoundEmitter:PlaySound("dontstarve/creatures/perd/gobble")
	end
end)
