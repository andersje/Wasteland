minetest.register_entity(":__builtin:item", {
	initial_properties = {
		hp_max = 1,
		physical = true,
		collisionbox = {-0.17,-0.17,-0.17, 0.17,0.17,0.17},
		visual = "sprite",
		visual_size = {x=0.5, y=0.5},
		textures = {""},
		spritediv = {x=1, y=1},
		initial_sprite_basepos = {x=0, y=0},
		is_visible = false,
		timer = 0,
	},
	
	itemstring = '',
	physical_state = true,

	set_item = function(self, itemstring)
		self.itemstring = itemstring
		local stack = ItemStack(itemstring)
		local itemtable = stack:to_table()
		local itemname = nil
		if itemtable then
			itemname = stack:to_table().name
		end
		local item_texture = nil
		local item_type = ""
		if minetest.registered_items[itemname] then
			item_texture = minetest.registered_items[itemname].inventory_image
			item_type = minetest.registered_items[itemname].type
		end
		prop = {
			is_visible = true,
			visual = "sprite",
			textures = {"unknown_item.png"}
		}
		--[[if item_texture and item_texture ~= "" then
			prop.visual = "sprite"
			prop.textures = {item_texture}
			prop.visual_size = {x=0.50, y=0.50}
		else]]
			prop.visual = "wielditem"
			prop.textures = {itemname}
			prop.visual_size = {x=0.20, y=0.20}
			prop.automatic_rotate = math.pi * 0.25
		--end
		self.object:set_properties(prop)
	end,

	get_staticdata = function(self)
		--return self.itemstring
		return minetest.serialize({
			itemstring = self.itemstring,
			always_collect = self.always_collect,
			timer = self.timer,
		})
	end,

	on_activate = function(self, staticdata, dtime_s)
		if string.sub(staticdata, 1, string.len("return")) == "return" then
			local data = minetest.deserialize(staticdata)
			if data and type(data) == "table" then
				self.itemstring = data.itemstring
				self.always_collect = data.always_collect
				self.timer = data.timer
				if not self.timer then
					self.timer = 0
				end
				self.timer = self.timer+dtime_s
			end
		else
			self.itemstring = staticdata
		end
		self.object:set_armor_groups({immortal=1})
		self.object:setvelocity({x=0, y=2, z=0})
		self.object:setacceleration({x=0, y=-10, z=0})
		self:set_item(self.itemstring)
	end,
	
	on_step = function(self, dtime)
		local time = minetest.setting_get("remove_items")
		if not time then
			time = 300
		end
		if not self.timer then
			self.timer = 0
		end
		self.timer = self.timer + dtime
		time = tonumber(time)
		if time ~= 0 and (self.timer > time) then
			self.object:remove()
		end
		
		local p = self.object:getpos()
		
		local name = minetest.env:get_node(p).name
		if name == "default:lava_flowing" or name == "default:lava_source" then
			minetest.sound_play("builtin_item_lava", {pos=self.object:getpos()})
			self.object:remove()
			return
		end
		
		if minetest.registered_nodes[name].liquidtype == "flowing" then
			get_flowing_dir = function(self)
				local pos = self.object:getpos()
				local param2 = minetest.env:get_node(pos).param2
				for i,d in ipairs({-1, 1, -1, 1}) do
					if i<3 then
						pos.x = pos.x+d
					else
						pos.z = pos.z+d
					end
					
					local name = minetest.env:get_node(pos).name
					local par2 = minetest.env:get_node(pos).param2
					if name == "default:water_flowing" and par2 < param2 then
						return pos
					end
					
					if i<3 then
						pos.x = pos.x-d
					else
						pos.z = pos.z-d
					end
				end
			end
			
			local vec = get_flowing_dir(self)
			if vec then
				local v = self.object:getvelocity()
				if vec and vec.x-p.x > 0 then
					self.object:setvelocity({x=0.5,y=v.y,z=0})
				elseif vec and vec.x-p.x < 0 then
					self.object:setvelocity({x=-0.5,y=v.y,z=0})
				elseif vec and vec.z-p.z > 0 then
					self.object:setvelocity({x=0,y=v.y,z=0.5})
				elseif vec and vec.z-p.z < 0 then
					self.object:setvelocity({x=0,y=v.y,z=-0.5})
				end
				self.object:setacceleration({x=0, y=-10, z=0})
				self.physical_state = true
				self.object:set_properties({
					physical = true
				})
				return
			end
		end
		
		p.y = p.y - 0.3
		local nn = minetest.env:get_node(p).name
		-- If node is not registered or node is walkably solid
		if not minetest.registered_nodes[nn] or minetest.registered_nodes[nn].walkable then
			if self.physical_state then
				self.object:setvelocity({x=0,y=0,z=0})
				self.object:setacceleration({x=0, y=0, z=0})
				self.physical_state = false
				self.object:set_properties({
					physical = false
				})
			end
		else
			if not self.physical_state then
				self.object:setvelocity({x=0,y=0,z=0})
				self.object:setacceleration({x=0, y=-10, z=0})
				self.physical_state = true
				self.object:set_properties({
					physical = true
				})
			end
		end
	end,

	on_punch = function(self, hitter)
		if self.itemstring ~= '' then
			local left = hitter:get_inventory():add_item("main", self.itemstring)
			if not left:is_empty() then
				self.itemstring = left:to_string()
				return
			end
		end
		self.object:remove()
	end,
})

if minetest.setting_get("log_mods") then
	minetest.log("action", "builtin_item loaded")
end
