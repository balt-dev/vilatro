--- STEAMODDED HEADER
--- MOD_NAME: vilatro
--- MOD_ID: VI
--- PREFIX: vi
--- MOD_AUTHOR: [baltdev]
--- MOD_DESCRIPTION: Proper keyboard bindings for Balatro. Controller support not guaranteed.
--- VERSION: 0.1.0
----------------------

local mod = SMODS.current_mod

G.kb_select_offset = 0

local selected_id
local last_state 
local last_highlighted

local function reset_vars()
	if G.kb_selected_area then G.kb_selected_area:unhighlight_all() end
	G.kb_selected_area = nil
	selected_id = nil
	if last_highlighted then
		last_highlighted:stop_hover()
		last_highlighted = nil
	end
end

local function can(action)
	local fakebutton = {config = {}}
	G.FUNCS["can_" .. action](fakebutton)
	return fakebutton.config.button ~= nil
end

local function get_size()
	if not G.kb_selected_area then return 0 end
	if not G.kb_selected_area.cards then return 0 end
	if not G[selected_id] then 
		reset_vars()
	return 0 end
	return #G.kb_selected_area.cards
end

local function update_offset(value)
	G.kb_select_offset = value
	if G.kb_selected_area and G.kb_selected_area.cards then
		for i = G.kb_select_offset, G.kb_select_offset + 9 do
			local card = G.kb_selected_area.cards[i + 1]
			if not card then break end
			card:juice_up(.1, .2)
		end
	end
end

local function add_offset(amount)
	if not G.kb_selected_area then return end
	if not G[selected_id] then 
		reset_vars()
	return end
	local size = get_size()
	if G.kb_select_offset + amount < 0 then 
		local o = math.floor(size / 10) * 10
		if o == size then
			o = o - 10
		end
		update_offset(o)
		return
	elseif G.kb_select_offset + amount > size then
		update_offset(0)
		return
	end
	update_offset(G.kb_select_offset + amount)
end

local function set_selected(id)
	print("Switching to " .. id)
	if not G[id] or not G[id].cards or #G[id].cards == 0 then 
		if selected_id == id then
			reset_vars()
		end
	return end
	G.CONTROLLER:recall_cardarea_focus(id)
	selected_id = id
	G.kb_selected_area = G[id]
	update_offset(G.kb_select_offset)
end

local function toggle_selected(index)
	if G.kb_selected_area and G.kb_selected_area.cards and #G.kb_selected_area.cards == 0 then
		reset_vars()
	end
	if not G.kb_selected_area then 
		-- Some sensible defaults
		if G.STATE == G.STATES.SELECTING_HAND then
			set_selected('hand')
		elseif G.STATE == G.STATES.BLIND_SELECT
			or G.STATE == G.STATES.HAND_PLAYED
			or G.STATE == G.STATES.ROUND_EVAL
			then set_selected('jokers')
		elseif G.STATE == G.STATES.TAROT_PACK
			or G.STATE == G.STATES.PLANET_PACK
			or G.STATE == G.STATES.SPECTRAL_PACK
			or G.STATE == G.STATES.BUFFOON_PACK
			or G.STATE == G.STATES.STANDARD_PACK
		then set_selected("pack_cards")
		elseif G.STATE == G.STATES.SHOP then
			set_selected("shop_jokers")
		else return end
	end
	if not G[selected_id] then 
		reset_vars()
	return end
	if not G.kb_selected_area.cards then return end
	local total_index = G.kb_select_offset + index + 1
	if 1 > total_index or total_index > #G.kb_selected_area.cards then return end
	local card = G.kb_selected_area.cards[total_index]
	if card.highlighted then
		if last_highlighted then
			last_highlighted:stop_hover()
		end
		last_highlighted = nil
		G.kb_selected_area:remove_from_highlighted(card)
	elseif G.kb_selected_area:can_highlight(card) then
		if last_highlighted then
			last_highlighted:stop_hover()
		end
		G.kb_selected_area:add_to_highlighted(card)
		last_highlighted = card
		last_highlighted:hover()
	end
end

local function reroll()
	if G.STATE == G.STATES.SHOP then
		if can("reroll") then
			G.FUNCS.reroll_shop({})
			return
		end
	elseif G.STATE == G.STATES.BLIND_SELECT then
		local fakebutton = {config = {}, children = {{children = {{config = {}}}}}}
		G.FUNCS.reroll_boss_button(fakebutton)
		if fakebutton.config.button then
			G.FUNCS.reroll_boss()
			return
		end
	end
end

-- backspace to skip pack -- done
-- backspace for next round -- done
-- backspace to skip blind -- DONE OMFFGGGGG


local function discard()
	if G.STATE == G.STATES.BLIND_SELECT then
		-- Can't fake it fully, we need the tag
		
		local current_blind = G.GAME.blind_on_deck or 'Small'
		if current_blind == "Boss" then return end
		
		_tag = Tag(G.GAME.round_resets.blind_tags[current_blind], nil, current_blind)
		
		if not _tag then
			error("tag is null for blind " .. current_blind)
		end
		
		local fakebutton = {
			UIBox = {
				get_UIE_by_ID = function()
					return {config = {ref_table = _tag}}
				end
			}
		}
		
		G.FUNCS.skip_blind(fakebutton)
		return
	end
	if G.STATE == G.STATES.TAROT_PACK
		or G.STATE == G.STATES.PLANET_PACK
		or G.STATE == G.STATES.SPECTRAL_PACK
		or G.STATE == G.STATES.BUFFOON_PACK
		or G.STATE == G.STATES.STANDARD_PACK
	then
		if can("skip_booster") then
			G.FUNCS.skip_booster()
			reset_vars()
			return
		end
	end
	if G.STATE == G.STATES.SHOP then
		G.FUNCS.toggle_shop()
		reset_vars()
		return
	end
		
	if G.STATE ~= G.STATES.SELECTING_HAND then return end
	if not G.GAME.current_round then return end
	if not G.kb_selected_area then return end
	if G.hand and G.kb_selected_area ~= G.hand then return end
	if not can("discard") then return end
	G.FUNCS.discard_cards_from_highlighted(nil, false) 
	reset_vars()
end

-- enter to select from pack
-- enter to select blind -- done

local function context_use()
	if G.STATE == G.STATES.ROUND_EVAL then
		local fakebutton = {config = {}}
		G.FUNCS.cash_out(fakebutton)
		return
	end
	if G.STATE == G.STATES.BLIND_SELECT then
		-- Can't fake it, we need the real button
		local current_blind = G.GAME.blind_on_deck or 'Small'
		local blind_index = (current_blind == 'Small' and 1) or (current_blind == 'Big' and 2) or 3
		local button = G.blind_select.UIRoot.children[1].children[blind_index].config.object:get_UIE_by_ID('select_blind_button')
		G.FUNCS.select_blind(button)
		return
	end
	if not G.kb_selected_area then return end
	if G.kb_selected_area.highlighted and #G.kb_selected_area.highlighted == 0 then
		toggle_selected(0)
		return
	end
	if G.STATE == G.STATES.SELECTING_HAND and G.hand and G.kb_selected_area == G.hand then
		if can("play") then
			G.FUNCS.play_cards_from_highlighted()
			reset_vars()
		end
		return
	end
	if G.jokers and G.kb_selected_area == G.jokers then return end
	if G.consumeables and G.kb_selected_area == G.consumeables then
		if G.kb_selected_area.highlighted and
			G.kb_selected_area.highlighted[1] and
			G.kb_selected_area.highlighted[1]:can_use_consumeable()
		then
			G.FUNCS.use_card {
				config = {ref_table = G.kb_selected_area.highlighted[1]}
			}
			reset_vars()
			return
		end
	end
	if G.STATE == G.STATES.SHOP and G.kb_selected_area == G.shop_jokers or G.kb_selected_area == G.shop_vouchers or G.kb_selected_area == G.shop_booster then
		local card = G.kb_selected_area.highlighted and G.kb_selected_area.highlighted[1]
		if not card then return end
		
		local button = {config = {ref_table = card}}
		
		if card.area == G.shop_booster then
			G.FUNCS.can_open(button)
			if button.config.button then
				G.FUNCS.use_card(button)
				reset_vars()
				return
			end
		end
		
		if card.area == G.shop_vouchers then
			G.FUNCS.can_redeem(button)
			if button.config.button then
				G.FUNCS.use_card(button)
				reset_vars()
				return
			end
		end
		
		if card.area == G.shop_jokers then
			G.FUNCS.can_buy(button)
			if button.config.button then
				G.FUNCS.buy_from_shop(button)
				return
			end
		end
	end
	
	if G.kb_selected_area == G.pack_cards then
		local card = G.kb_selected_area.highlighted and G.kb_selected_area.highlighted[1]
		if not card then return end
		if card.ability.consumeable and not card:can_use_consumeable() then return end
		
		local button = {config = {ref_table = card}}
		G.FUNCS.can_select_card(button)
		if button.config.button then
			G.FUNCS.use_card(button)
			reset_vars()
			return
		end
	end
end

local function buy_and_use()
	if not G.kb_selected_area then return end
	if G.kb_selected_area.highlighted and #G.kb_selected_area.highlighted == 0 then
		toggle_selected(0)
		return
	end
	if not (G.STATE == G.STATES.SHOP and G.kb_selected_area == G.shop_jokers) then return end
	local card = G.kb_selected_area.highlighted and G.kb_selected_area.highlighted[1]
	if not card then return end
		
	local button = {config = {ref_table = card, id = "buy_and_use"}, UIBox = {states = {}}}
		
	G.FUNCS.can_buy_and_use(button)
	if button.config.button then
		G.FUNCS.buy_from_shop(button)
		reset_vars()
		return
	end
end

local function sell()
	if G.kb_selected_area and G.kb_selected_area.cards then
		for i, card in ipairs(G.kb_selected_area.cards) do
			if card.area and card.area.config.type == "joker" and card.highlighted then
				local fakebutton = {config = {ref_table = card}}
				G.FUNCS.can_sell_card(fakebutton)
				if fakebutton.config.button then
					G.FUNCS.sell_card(fakebutton)
				end
			end
		end
	end
end

local function cycle_selected(amount)
	local selections = {
		"hand",
		"jokers",
		"consumeables",
		"shop_jokers",
		"shop_vouchers",
		"shop_booster",
		"pack_cards"
	}
	local index
	local sel_id = selected_id or "hand"
	local sel_idx
	for i, sel in ipairs(selections) do
		if sel == sel_id then
			sel_idx = i
			break
		end
	end
	if sel_idx == nil then
		print("Warning: Selection index not found! Current selection id: " .. selected_id)
		selected_id = "hand"
		sel_idx = 1
	end
	
	for i = 1, #selections do
		i = i * amount -- 1 or -1
		local offset_idx = ((sel_idx + i - 1) % #selections) + 1
		if G[selections[offset_idx]] and G[selections[offset_idx]].cards and #G[selections[offset_idx]].cards > 0 then
			if not (selections[offset_idx]:sub(1, 4) == "shop" and G.STATE ~= G.STATES.SHOP) then
				set_selected(selections[offset_idx])
				return
			end
		end
	end
end

local function sort_suit()
	if not G.hand then return end
	G.FUNCS.sort_hand_suit()
end

local function sort_rank()
	if not G.hand then return end
	G.FUNCS.sort_hand_value()
end

local function peek_deck()
	if not G.deck then return end
	if not G.deck_preview and not G.OVERLAY_MENU then
		G.deck_preview = UIBox{
            definition = G.UIDEF.deck_preview(),
            config = {align='tm', offset = {x=0,y=-0.8},major = G.hand, bond = 'Weak'}
        }
	else
		if G.deck_preview then
			G.deck_preview:remove()
		end
		G.deck_preview = nil
	end
end
	

-- Monkey-patching

local update_card = Card.update
local update_area = CardArea.update
local draw_card = Card.draw

function Card:update(dt)
	update_card(self, dt)
	if not self.area then
		self.__kb_index = nil
	end
	if not last_state or G.STATE ~= last_state then
		reset_vars()
		last_state = G.STATE
	end
end

function CardArea:update(dt)
	update_area(self, dt)
	if self.cards then
		for i, card in ipairs(self.cards) do
			card.__kb_index = i
		end
	end
end

function Card:draw()
	draw_card(self)
	
	if self.area == G.kb_selected_area 
		and self.__kb_index
		and self.__kb_index > G.kb_select_offset
		and self.__kb_index <= G.kb_select_offset + 10
	then
		local transform = self.VT or self.T
		love.graphics.push()
		love.graphics.scale(G.TILESCALE, G.TILESCALE)
		love.graphics.translate(transform.x*G.TILESIZE+transform.w*G.TILESIZE*0.5, transform.y*G.TILESIZE+transform.h*G.TILESIZE*0.5)
		love.graphics.rotate(transform.r)
		love.graphics.translate(-transform.w*G.TILESIZE*0.5, -transform.h*G.TILESIZE*0.5)
		love.graphics.setColor(G.C.UI.OUTLINE_LIGHT_TRANS)
		love.graphics.arc('fill', transform.w*G.TILESIZE*0.5, transform.h*G.TILESIZE*-0.1, 0.2*G.TILESIZE, -3 * math.pi / 4, -math.pi / 4, 1)
		love.graphics.pop() 
	end
end

-- Mod stuff

local keybinds = {
	["Inc10"] = function()
		add_offset(10) -- 
	end,
	["Dec10"] = function()
		add_offset(-10) --
	end,
	["Discard"] = discard,
	["Use"] = context_use,
	["BuyAndUse"] = buy_and_use,
	["SelectHand"] = function()
		set_selected("hand")
	end,
	["SelectJokers"] = function()
		set_selected("jokers")
	end,
	["SelectConsumeables"] = function()
		set_selected("consumeables")
	end,
	["SelectShopJokers"] = function()
		set_selected("shop_jokers")
	end,
	["SelectShopVouchers"] = function()
		set_selected("shop_vouchers")
	end,
	["SelectShopBooster"] = function()
		set_selected("shop_booster")
	end,
	["SelectPackCards"] = function()
		set_selected("pack_cards")
	end,
	["SelectCycleLeft"] = function()
		cycle_selected(-1)
	end,
	["SelectCycleRight"] = function()
		cycle_selected(1)
	end,
	["DeselectAll"] = function()
		reset_vars()
	end,
	["Reroll"] = reroll,
	["Sell"] = sell,
	["SortSuit"] = sort_suit,
	["SortRank"] = sort_rank,
	["PeekDeck"] = peek_deck,
}

for i = 1, 10 do
	keybinds["Select" .. tostring(i % 10)] = function()
		toggle_selected((i + 9) % 10)
	end
end

for key, action in pairs(keybinds) do
	if mod.config[key] ~= false then
		SMODS.Keybind {
			key = "vilatro_binding_" .. key,
			key_pressed = mod.config[key],
			action = function()
				if not G.OVERLAY_MENU then action() end
			end
		}
	end
end


-- UI stuff

-- from https://gist.github.com/GabrielBdeC/b055af60707115cbc954b0751d87ec23
function string:split(delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(self, delimiter, from, true)
    while delim_from do
        if (delim_from ~= 1) then
            table.insert(result, string.sub(self, from, delim_from-1))
        end
        from = delim_to + 1
        delim_from, delim_to = string.find(self, delimiter, from, true)
    end
    if (from <= #self) then table.insert(result, string.sub(self, from)) end
    return result
end

local function create_keybind_button(args)
	args.align = args.align or "cm"
	args.active_colour = args.active_colour or G.C.GREY
	args.w = args.w or 0.8
	args.h = args.h or 0.8
	args.scale = args.scale or 1
	args.label_scale = args.label_scale or 0.5
	
	local children = {}
	
	if args.label then
		children[#children+1] = {
			n = G.UIT.C,
			config = { align = "cm", colour = G.C.CLEAR },
			nodes = {
				{
					n = G.UIT.T,
					config = {
						text = localize(args.label),
						scale = args.label_scale,
						colour = G.C.UI.TEXT_LIGHT,
						shadow = true
					}
				},
				{
					n = G.UIT.B,
					config = { w = 0.1, h = 0.1, colour = G.C.CLEAR }
				}
			}
		}
	end
	
	children[#children+1] = {
		n = G.UIT.C,
		config = {
			align = "cm", colour = args.active_colour,
			hover = true, r = 0.1, padding = 0.1,
			minw = args.w, minh = args.h,
			button = 'bind_key',
			ref_table = args.ref_table,
			ref_value = args.ref_value,
		},
		nodes = {{
			n = G.UIT.T,
			config = {
				text = args.ref_table[args.ref_value] or localize("vi_keybind_unset"),
				scale = 0.4,
				colour = G.C.UI.TEXT_LIGHT,
				shadow = false,
			}
		}}
	}
	
	return {
		n = G.UIT.C,
		config = {
			align = args.align,
			padding = 0.1,
			r = 0.1,
			colour = G.C.CLEAR,
			focus_args = { funnel_from = true },
			tooltip = args.info and {text = localize(args.info):split("\n")}
		},
		nodes = children
	}
end

function G.FUNCS.bind_key(e)
	e.children[1].config.text = "..."
	e.children[1].UIBox:recalculate()
	
	G.keybind_callback = function(key)
		if not e then return end
		if not e.children then return end
		if not e.children[1] then return end
		if not e.children[1].config then return end
		
		local bound_key = key
		if bound_key == "escape" then
			bound_key = false
		end
		
		e.config.ref_table[e.config.ref_value] = bound_key
		e.children[1].config.text = bound_key or localize("vi_keybind_unset")
		e.children[1].UIBox:recalculate()
		
	end
end

mod.config_tab = function()
	return {
		n=G.UIT.ROOT,
		config = {align = "cm", padding = 0.05, r = 0.1, minw=8, minh=6, colour = G.C.BLACK}, 
		nodes = {
			{
				n = G.UIT.R,
				config = {
					align = "cm", colour = G.C.UI.CLEAR, padding = 0
				},
				nodes = {{
					n = G.UIT.C,
					config = {
						align = "cm", colour = G.C.RED, r = 0.1, padding = 0.1
					},
					nodes = {{
						n = G.UIT.T,
						config = {
							text = localize("vi_keybind_restart"),
							colour = G.C.UI.TEXT_LIGHT,
							scale = 0.6,
							padding = 0.05,
							shadow = false
						}
					}}
				}}
			},
			{n=G.UIT.R, config={align = "cm", colour = G.C.CLEAR}, nodes={
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Select1",
					label = "vi_keybind_sel",
					info = "vi_keybind_sel_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Select2",
					info = "vi_keybind_sel_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Select3",
					info = "vi_keybind_sel_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Select4",
					info = "vi_keybind_sel_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Select5",
					info = "vi_keybind_sel_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Select6",
					info = "vi_keybind_sel_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Select7",
					info = "vi_keybind_sel_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Select8",
					info = "vi_keybind_sel_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Select9",
					info = "vi_keybind_sel_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Select0",
					info = "vi_keybind_sel_desc"
				},
			}},
			{n=G.UIT.R, config={align = "cm", colour = G.C.CLEAR}, nodes={
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Dec10",
					label = "vi_keybind_dec10",
					info = "vi_keybind_dec10_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Inc10",
					label = "vi_keybind_inc10",
					info = "vi_keybind_inc10_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "DeselectAll",
					label = "vi_keybind_desel",
					info = "vi_keybind_desel_desc"
				},
			}},
			{n=G.UIT.R, config={align = "cm", colour = G.C.CLEAR}, nodes={
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "SelectHand",
					label = "vi_keybind_sel_hand",
					info = "vi_keybind_sel_hand_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "SelectJokers",
					label = "vi_keybind_sel_jokers",
					info = "vi_keybind_sel_jokers_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "SelectConsumeables",
					label = "vi_keybind_sel_consumables",
					info = "vi_keybind_sel_consumables_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "SelectPackCards",
					label = "vi_keybind_sel_pack_cards",
					info = "vi_keybind_sel_pack_cards_desc"
				},
			}},
			{n=G.UIT.R, config={align = "cm", colour = G.C.CLEAR}, nodes={
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "SelectShopJokers",
					label = "vi_keybind_sel_shop",
					info = "vi_keybind_sel_shop_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "SelectShopVouchers",
					info = "vi_keybind_sel_shop_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "SelectShopBooster",
					info = "vi_keybind_sel_shop_desc"
				},
			}},
			{n=G.UIT.R, config={align = "cm", colour = G.C.CLEAR}, nodes={
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "SelectCycleLeft",
					label = "vi_keybind_sel_left",
					info = "vi_keybind_sel_left_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "SelectCycleRight",
					label = "vi_keybind_sel_right",
					info = "vi_keybind_sel_right_desc"
				},
			}},
			{n=G.UIT.R, config={align = "cm", colour = G.C.CLEAR}, nodes={
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Discard",
					label = "vi_keybind_discard",
					info = "vi_keybind_discard_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Use",
					label = "vi_keybind_use",
					info = "vi_keybind_use_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "BuyAndUse",
					label = "vi_keybind_buy_and_use",
					info = "vi_keybind_buy_and_use_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "PeekDeck",
					label = "vi_keybind_peek_deck",
					info = "vi_keybind_peek_deck_desc"
				},
			}},
			{n=G.UIT.R, config={align = "cm", colour = G.C.CLEAR}, nodes={
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Reroll",
					label = "vi_keybind_reroll",
					info = "vi_keybind_reroll_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "Sell",
					label = "vi_keybind_sell",
					info = "vi_keybind_sell_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "SortSuit",
					label = "vi_keybind_sort_suit",
					info = "vi_keybind_sort_suit_desc"
				},
				create_keybind_button {
					ref_table = mod.config,
					ref_value = "SortRank",
					label = "vi_keybind_sort_rank",
					info = "vi_keybind_sort_rank_desc"
				},
			}},
		}
	}
end