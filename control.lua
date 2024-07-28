script.on_event({defines.events.on_player_selected_area}, function(event)
    if event.item == 'floor-selection-tool' then
        process_selected_area_with_this_mod(event, false)
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    local name = event.element.name
    local player = game.players[event.player_index]
    if name == "floor_item_picker_confirm_button" then
        close_tool_picker_ui(player, true)
        --resume_process_selected_area_with_this_mod()
    elseif name == "floor_item_picker_cancel_button" then
        close_tool_picker_ui(player, false)
    else
        local button_prefix = "floor_item_picker_button_"
        if string.find(name, button_prefix) == 1 then
            handle_gui_element_click(name, player)
        end
    end
end)

function close_tool_picker_ui(player, confirmed)
    local frame = player.gui.screen.floor_item_picker_frame

    if frame then 
        --if confirmed then
        --    player.mod_settings["pump-always-show"] = { value = frame.pump_tool_picker_always_show.state }
        --end
        frame.destroy()
    end
end

local prefix = "floor_item_picker_button_"

function handle_gui_element_click(element_name, player)
    local frame = player.gui.screen.floor_item_picker_frame
    local current_action = global.current_action

    if frame then

    --player.print(serpent.block(global.current_action))

      local item_name = string.sub(element_name, string.len(prefix) + 1)
      player.print("Item: " .. item_name)
      local tile_name = global.current_action.tile_items[item_name]
      player.print("Tile: " .. tile_name)

      area = global.current_action.area_bounds

      for x=math.floor(area.left_top.x),math.ceil(area.right_bottom.x)-1 do
        for y=math.floor(area.left_top.y),math.ceil(area.right_bottom.y)-1 do
          local tile = player.surface.get_tile(x, y)

          --if tile.collides_with("water-tile") then
          --  local ghost = player.surface.create_entity {
          --    name = "tile-ghost",
          --    inner_name = "landfill",
          --    position = {x, y},
          --    force = player.force,
          --    player = player
          --  }
          --else
          local ghost = player.surface.create_entity {
            name = "tile-ghost",
            inner_name = tile_name,
            position = {x, y},
            force = player.force,
            player = player
          }
        end
      end
    end
end

function process_selected_area_with_this_mod(event, force_ui)
    local player = game.get_player(event.player_index)

    -- The game is not paused with a ui open. So make sure a second selection is ignore until the window is closed.
    --if is_ui_open(player) then return end

    -- Store required input in global, so it can resume after the ui is potentially shown.
    global.current_action = {failure = nil}
    local current_action = global.current_action

    current_action.player_index = event.player_index
    current_action.area_bounds = event.area
    current_action.surface_index = event.surface.index

    local area = event.area

    local available_tiles = game.get_filtered_tile_prototypes{{filter="blueprintable"}}

    local items = {}

    for _, tile in pairs(available_tiles) do
      -- can_be_part_of_blueprint 
      --player.print(tile.name)
      --player.print(serpent.block(tile.items_to_place_this))
      for _, placing_item in pairs(tile.items_to_place_this) do
        local name = placing_item.name
        if not items[name] then
          items[name] = tile.name
        end
      end
    end

    current_action.tile_items = items
    player.print(serpent.block(items))

    local frame = player.gui.screen.add {
        type = "frame",
        name = "floor_item_picker_frame",
        direction = "vertical",
        caption = {"floor-item-picker.title"},
    }
    frame.auto_center = true
    player.opened = frame
    --local label = frame.add {
    --    type = "label",
    --    caption = "Check it out a frame",            
    --}
    --label.style.maximal_width = 300
    --label.style.single_line = false

    local innerFrame = frame.add {
        type = "frame",
        name = "all_toolbox_options",
        direction = "vertical",
        style="inside_shallow_frame",
    }

    innerFrame.add {type = "line", style="frame_division_fake_horizontal_line"}
    local flow = innerFrame.add {
        type = "flow",
        direction = "horizontal",
        name = "Tile to use"
    }

    for item_name, _ in pairs(items) do
      local style = "slot_sized_button"
--        if pick_name == toolbox_options.pick.selected then
--            style = "slot_sized_button_pressed"
--        end
      local button = flow.add {
          type = "choose-elem-button",
          name = "floor_item_picker_button_" .. item_name,
          elem_type = "item",
          --elem_filters = {{filter = "name", name = toolbox_options.pick.available}},
          item = item_name,
          style = style
      }
      button.locked = true
    end
    local bottom_flow = frame.add {
        type = "flow",
        direction = "horizontal",
    }

    bottom_flow.style.top_padding = 4
    bottom_flow.add {
        type = "button",
        name = "floor_item_picker_cancel_button",
        caption = {"floor-item-picker.cancel"},
        style = "back_button"
    }        
    local filler = bottom_flow.add{
        type = "empty-widget",
        style = "draggable_space",
        ignored_by_interaction = true,
    }
    filler.style.height = 32
    filler.style.horizontally_stretchable = true
    bottom_flow.add {
        type = "button",
        name = "floor_item_picker_confirm_button",
        caption = {"floor-item-picker.confirm"},
        style = "confirm_button"
    }


--    if not current_action.failure then
--        current_action.failure = add_resource_category(current_action,
--                                                       event.entities)
--    end
--
--    if not current_action.failure then
--        current_action.failure = add_toolbox(current_action, player, force_ui)
--    end
--
--    if not is_ui_open(player) then
--        resume_process_selected_area_with_this_mod()
--    end
end