ore_to_move = {}
copied_oil = {}

function start_with(a,b)
	return string.sub(a,1,string.len(b)) == b
end
function end_with(a,b)
	return string.sub(a,string.len(a)-string.len(b)+1) == b
end

local round = function(nr)
	local dec = nr-math.floor(nr)
	if dec >= 0.5 then
		return math.floor(nr)+1
	else
		return math.floor(nr)
	end
end

script.on_event(defines.events.on_player_alt_selected_area, function(event)

end)

script.on_event(defines.events.on_player_selected_area, function(event)
	if event.item == "ore-move-planner" then
		local player = game.players[event.player_index]
		local surface = player.surface
		if ore_to_move[event.player_index] == nil then
			ore_to_move[event.player_index] = {ore={},centre={},samples = {},catch = {found = false, samples = {}}}
		end
		local centre = {x=0,y=0}
		local qnt = 0
		local oil_qnt = 0
		for _,entity in pairs(event.entities) do
			if entity.type == "resource" then
				if entity.name == 'crude-oil' then
					oil_qnt = oil_qnt + 1
					if copied_oil[event.player_index] == nil then
						copied_oil[event.player_index] = {}
					end
					table.insert(copied_oil[event.player_index], entity.amount)
					log(serpent.block(copied_oil[event.player_index]))
					player.insert({name="oil-patch-item", count=1, amount=entity.amount, nitzan_custom=entity.amount})
					entity.destroy()
				else
					qnt=qnt+1
					local pos = entity.position
					centre.x=centre.x+pos.x
					centre.y=centre.y+pos.y
					ore_to_move[event.player_index].ore[#ore_to_move[event.player_index].ore+1]={name=entity.name,pos=pos,surface = entity.surface}
				end
			end
		end
		centre.x=round(centre.x/qnt)
		centre.y=round(centre.y/qnt)
		ore_to_move[event.player_index].centre.x=centre.x
		ore_to_move[event.player_index].centre.y=centre.y
		ore_to_move[event.player_index].catch.samples = {}
		local found=false
		for _, ore in pairs(ore_to_move[event.player_index].ore) do
			ore.pos.x=ore.pos.x-centre.x
			ore.pos.y=ore.pos.y-centre.y
			for i,s in pairs(ore_to_move[event.player_index].samples) do
				local p = {}
				p.x = s.pos.x
				p.y = s.pos.y
				if p.x==ore_to_move[event.player_index].centre.x+ore.pos.x and p.y==ore_to_move[event.player_index].centre.y+ore.pos.y then
					ore_to_move[event.player_index].catch.found = true
					table.insert(ore_to_move[event.player_index].catch.samples,i)
				end
			end
		end
			--player.insert({name = resource, count = miscount})
		if qnt > 0 then
			player.print(string.format("Copied %d resources.", qnt))
		end
		if oil_qnt > 0 then
			player.print(string.format("Sent %d oil patches to inventory.", oil_qnt))
		end
	end
end)

script.on_event(defines.events.on_player_alt_selected_area, function(event)
	if event.item == "ore-move-planner" then
		if ore_to_move[event.player_index] == nil then
			player.print("No copied resources.")
			return
		end
		local qnt = #ore_to_move[event.player_index].ore
		if qnt == 0 then
			player.print("No copied resources.")
			return
		end
		local player = game.players[event.player_index]
		local surface = player.surface
		local centre = {x=round((event.area.left_top.x+event.area.right_bottom.x)/2),y=round((event.area.left_top.y+event.area.right_bottom.y)/2)}
		local surface = player.surface
		local dist = math.sqrt(math.pow(centre.x-ore_to_move[event.player_index].centre.x,2)+math.pow(centre.y-ore_to_move[event.player_index].centre.y,2))
		if ore_to_move[event.player_index].catch.found then
			dist=dist+ore_to_move[event.player_index].samples[ore_to_move[event.player_index].catch.samples[1]].dist
		end
		--dist=dist+ore_to_move[event.player_index].cost
		log("ore mover v2:")
		log(serpent.block(ore_to_move[event.player_index]))
		for _, ore in pairs(ore_to_move[event.player_index].ore) do
			local entities = surface.find_entities_filtered{
			  area= {{ore_to_move[event.player_index].centre.x+ore.pos.x -0.5, ore_to_move[event.player_index].centre.y+ore.pos.y -0.5},
			  {ore_to_move[event.player_index].centre.x+ore.pos.x +0.5, ore_to_move[event.player_index].centre.y+ore.pos.y +0.5}},
			  name=ore.name,
			}
			
			local cost = 1
			for _, ent in pairs(entities) do
				local pos = {}
				pos.x = centre.x+ore.pos.x
				pos.y = centre.y+ore.pos.y
				local amount = round(ent.amount*cost)-3
				if amount > 0 then
					ore.surface.create_entity({name = ore.name , position = pos, force = ent.force, amount = round(ent.amount*cost)})
				end
				ent.destroy()
			end
		end
		if ore_to_move[event.player_index].catch.found then
			for _, s in pairs(ore_to_move[event.player_index].catch.samples) do
				ore_to_move[event.player_index].samples[s].pos.x = ore_to_move[event.player_index].samples[s].pos.x -ore_to_move[event.player_index].centre.x+centre.x
				ore_to_move[event.player_index].samples[s].pos.y = ore_to_move[event.player_index].samples[s].pos.y -ore_to_move[event.player_index].centre.y+centre.y
				ore_to_move[event.player_index].samples[s].dist=dist
			end
			ore_to_move[event.player_index].catch.found=false
		else
			local sample_size = math.min(#ore_to_move[event.player_index].ore,5)
			math.randomseed(#ore_to_move[event.player_index].ore)
			local picked = {}
			for i=1,sample_size do
				local chosen = 0
				while picked[chosen] ~= nil or chosen==0 do
					chosen = math.random(1,#ore_to_move[event.player_index].ore)
				end
				picked[chosen]= true
				local pos = {}
				pos.x = centre.x+ore_to_move[event.player_index].ore[chosen].pos.x
				pos.y = centre.y+ore_to_move[event.player_index].ore[chosen].pos.y
				table.insert(ore_to_move[event.player_index].samples,{pos=pos,dist = dist})
			end
		end
		ore_to_move[event.player_index].ore={}
		ore_to_move[event.player_index].centre.x=centre.x
		ore_to_move[event.player_index].centre.y=centre.y

		player.print(string.format("Pasted %d resources.", qnt))
	end
end)

script.on_event(defines.events.on_built_entity, function(event)
	-- player.insert({name="oil-patch-item", count=1, amount=entity.amount, nitzan_custom=entity.amount})
	if event.stack.name == 'oil-patch-item' then
		player_oil = copied_oil[event.player_index]

		if player_oil == nil then
			local player = game.players[event.player_index]
			player.print("Warning: incorrectly null copied oil list; did you restart the game after copying and before placing?")
			return
		end

		amount = table.remove(player_oil, 1)
		if amount ~= nil then
			event.created_entity.amount = amount
		else
			local player = game.players[event.player_index]
			player.print("Warning: incorrectly empty copied oil list.")
		end
	end
end)


-- game.player.surface.create_entity({name="crude-oil", amount=100000, position={game.player.position.x+x*7-7, game.player.position.y+y*7-7}})