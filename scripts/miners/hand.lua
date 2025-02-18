local string = require(modpath.."scripts.lualib.string")

local dead_trees = {
	["dead-dry-hairy-tree"] = true,
	["dead-grey-trunk"] = true,
	["dead-tree-desert"] = true,
	["dry-hairy-tree"] = true,
	["dry-tree"] = true
}

---@class PlantRegeneration
---@field entity LuaEntity
---@field regen_at uint

---@alias global.plant_regen PlantRegeneration[]
---@type global.plant_regen
local script_data = {}

---@param event on_player_mined_entity|on_robot_mined_entity
local function onMined(event)
	local entity = event.entity
	if not (entity and entity.valid) then return end
	if entity.type == "resource" and entity.amount == 240 then -- 240 is a pure resource node
		-- pure resource nodes should only yield 3 items, not 4
		local buffer = event.buffer
		buffer[1].count = 3
		return
	end
	if entity.type == "tree" then
		local buffer = event.buffer
		buffer.clear()
		buffer.insert{name="wood",count=math.random(1,2)}
		-- do some fancy shenanigans to add extras to trees
		if not dead_trees[entity.name] then
			buffer.insert{name="leaves",count=math.random(4,10)}
		end
		-- may give Mycelia (dirt), Flower Petals (grass), Limestone (sand) or Silica (desert) based on the tile
		local tile = entity.surface.get_hidden_tile(entity.position) or entity.surface.get_tile(entity.position).name
		if string.starts_with(tile,"grass") then
			local count = math.floor(math.random(1,5)*math.random(1,5)/5) -- 0-5
			if count > 0 then
				buffer.insert{name="flower-petals",count=count}
			end
		end
		if string.starts_with(tile,"sand") then
			local count = math.floor(math.random(1,4)*math.random(1,4)/4)*2 -- 0,2,4,6,8
			if count > 0 then
				buffer.insert{name="stone",count=count}
			end
		end
		if string.starts_with(tile,"dirt") then
			local count = math.floor(math.random(1,5)*math.random(1,5)/5) -- 0-5
			if count > 0 then
				buffer.insert{name="mycelia",count=count}
			end
		end
		if string.starts_with(tile,"red-desert") or tile == "dry-dirt" then
			local count = math.floor(math.random(1,5)*math.random(1,5)/5) -- 0-5
			if count > 0 then
				buffer.insert{name="silica",count=count}
			end
		end
	end
end

-- plants may be harvested, and may leave behind a "harvested" entity which can later regenerate
local function onHarvest(event)
	-- check if the "open GUI" event is intended for a plant...
	local player = game.players[event.player_index]
	if not (player.selected and player.selected.valid) then return end
	if not player.is_cursor_empty() then return end
	local entity = player.selected
	if entity.name == "paleberry" or entity.name == "beryl-nut" or entity.name == "bacon-agaric" then
		-- ensure it's not too far away...
		if player.can_reach_entity(entity) then
			if game.entity_prototypes[entity.name.."-harvested"] then
				local remains = entity.surface.create_entity{
					name = entity.name.."-harvested",
					position = entity.position,
					force = game.forces.neutral
				}
				table.insert(script_data, {
					entity = remains,
					regen_at = event.tick + math.random(3*3600*60,4*3600*60) -- plant regrows after 3-4 hours
				})
			end
			player.mine_entity(entity)
			player.play_sound{
				path = "entity-mined/tree-01"
			}
		else
			-- create flying text like when trying to mine normally
			player.create_local_flying_text{
				text = {"cant-reach"},
				create_at_cursor = true
			}
			player.play_sound{
				path = "utility/cannot_build"
			}
		end
	end
end

---@param event NthTickEventData
local function checkForRegrowth(event)
	for i,plant in pairs(script_data) do
		if plant.regen_at < event.tick then
			if plant.entity.valid then
				plant.entity.surface.create_entity{
					name = string.remove_suffix(plant.entity.name, "-harvested"),
					position = plant.entity.position,
					force = "neutral"
				}
				plant.entity.destroy()
			end
			script_data[i] = nil
		end
	end
end

return {
	on_init = function()
		global.plant_regen = global.plant_regen or script_data
	end,
	on_load = function()
		script_data = global.plant_regen or script_data
	end,
	on_nth_tick = {
		[600] = checkForRegrowth
	},
	events = {
		["interact"] = onHarvest,
		[defines.events.on_player_mined_entity] = onMined,
		[defines.events.on_robot_mined_entity] = onMined
	}
}