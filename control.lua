local prefix = "floor_item_picker_button_"

function log_error(msg)
  local log_prefix = "ERROR: "
  log(log_prefix .. msg)
  game.print(log_prefix .. msg)
end

script.on_event({defines.events.on_player_cursor_stack_changed}, function(event)
  local player = game.get_player(event.player_index)
  if not player then log_error("player nil"); return end

  if player.cursor_stack and player.cursor_stack.valid_for_read then
    -- Check if the cursor stack item is not the specific item you want
    if player.cursor_stack.name ~= "floor-selection-tool" then
      toggle_off(player)
    end
  else
    if global.active then
      toggle_off(player)
    end
  end
end)

script.on_event({defines.events.on_player_selected_area}, function(event)
    if event.item == 'floor-selection-tool' then
      if not global.active then
        log_error("Selected area but GUI was not toggled on")
        return
      end

      local selected = global.selected
      if not selected then
        log_error("No item selected")
      end
      process_selected_area_with_this_mod(event, selected)
    end
end)

script.on_event({defines.events.on_lua_shortcut}, function(event)
  handle_on_lua_shortcut(event)
end)

function handle_on_lua_shortcut(event)
  if event.prototype_name == "floor-shortcut" then
    local data = global
    local player = game.get_player(event.player_index)
    if not player then log_error("player nil"); return end

    log("handling event: on_lua_shortcut")
    --log(serpent.block(data))
    --player.print(serpent.block(data))

    if not data.active then
      data.active = true

      show_gui(player)

      -- Enable the selection cursor
      -- Check if the cursor stack is valid and clear it if so
      if player.cursor_stack and player.cursor_stack.valid_for_read then
        player.cursor_stack.clear()
      end

      player.cursor_stack.set_stack({name = "floor-selection-tool", count = 1})
    else
      toggle_off(player)
    end
  end
end

function toggle_off(player)
  global.active = false
  hide_gui(player)
  -- Clear the selection cursor
  -- This check _should_ be redundant, stack should always be present when GUI is
  if player.cursor_stack and player.cursor_stack.valid_for_read then
    if player.cursor_stack.name == "floor-selection-tool" then
      player.cursor_stack.clear()
    end
  end
end

script.on_event(defines.events.on_gui_closed, function(event)
    local player = game.get_player(event.player_index)
    if event.element and event.element.name == "floor_item_picker_frame" then
      toggle_off(player)
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    local name = event.element.name
    log("on gui click handler: " .. name)
    local player = game.get_player(event.player_index)
    if not player then return end

    local player = game.players[event.player_index]
    if name == "floor_item_picker_close_button" then
      toggle_off(player)
    else
      local button_prefix = "floor_item_picker_button_"
      if string.find(name, button_prefix) == 1 then
        handle_gui_element_click(name, player)
      end
    end
end)

script.on_event(defines.events.on_gui_location_changed, function(event)
    local element = event.element
    
    if element.name == "floor_item_picker_frame" then
      global.gui_location = element.location
    end
end)

function hide_gui(player)
  local frame = player.gui.screen.floor_item_picker_frame

  if frame then 
      --if confirmed then
      --    player.mod_settings["pump-always-show"] = { value = frame.pump_tool_picker_always_show.state }
      --end
    frame.destroy()
  end
end

function handle_gui_element_click(element_name, player)
  global.selected = string.sub(element_name, string.len(prefix) + 1)

  local frame = player.gui.screen.floor_item_picker_frame
  local selector = frame.inner_frame.tile_selector

  for _, option_name in pairs(selector.children_names) do
    if option_name == element_name then
      selector[option_name].style = "slot_sized_button_pressed"
    else
      selector[option_name].style = "slot_sized_button"
    end
  end
end

function show_gui(player)
  -- Collect all blueprintable items that place tiles, to be presented as
  -- selections in the GUI
  local available_tiles = game.get_filtered_tile_prototypes{{filter="blueprintable"}}

  local items = {}
  local old_selected = global.selected
  local new_selected = nil

  for _, tile in pairs(available_tiles) do
    for _, placing_item in pairs(tile.items_to_place_this) do
      local name = placing_item.name
      if not items[name] then
        items[name] = tile.name

        if old_selected == nil then
          old_selected = name
          new_selected = name
        else
          if old_selected == name then
            new_selected = old_selected
          end
        end
      end
    end
  end

  if not new_selected then
    log_error("No available items to place paths")
    global.selected = nil
    return false
  end
  
  global.selected = new_selected
  -- Store the list for easy reference when processing button clicks
  global.tile_items = items

  local frame = player.gui.screen.add {
      type = "frame",
      name = "floor_item_picker_frame",
      direction = "vertical",
  }
  local location = global.gui_location
  if location then
    frame.location = location
  end

  local titlebar_flow = frame.add {
      type="flow",
      direction="horizontal",
  }
  titlebar_flow.style.horizontal_spacing=6

  titlebar_flow.drag_target = frame
    titlebar_flow.add{
      type="label",
      caption={"floor-placer-gui.title"},
      ignored_by_interaction=true,
      style="frame_title"
    }
    local widget = titlebar_flow.add{
      type="empty-widget",
      ignored_by_interaction=true,
    }
    --widget.style.parent = "draggable_space_header"
    widget.style.height = 24
    widget.style.horizontally_stretchable = "on"
    widget.style.left_margin = 4
    widget.style.right_margin = 4

    local close_button = titlebar_flow.add{
        type="sprite-button",
        name="floor_item_picker_close_button",
        sprite="utility/close_white",
        hovered_sprite="utility/close_black",
        clicked_sprite="utility/close_black",
        tooltip={"floor-placer-gui.close-button-tooltip"},
        --style="close_button"
    }
    close_button.style.height = 24
    close_button.style.width = 24
  --frame.auto_center = true
  player.opened = frame
  --local label = frame.add {
  --    type = "label",
  --    caption = "Check it out a frame",            
  --}
  --label.style.maximal_width = 300
  --label.style.single_line = false

  local innerFrame = frame.add {
      type = "frame",
      name = "inner_frame",
      direction = "vertical",
      style="inside_shallow_frame",
  }

  innerFrame.add {type = "line", style="frame_division_fake_horizontal_line"}
  local flow = innerFrame.add {
      type = "flow",
      direction = "horizontal",
      name = "tile_selector"
  }

  for item_name, _ in pairs(items) do
    local style = "slot_sized_button"
    if item_name == new_selected then
        style = "slot_sized_button_pressed"
    end

    local button = flow.add {
      type = "choose-elem-button",
      name = "floor_item_picker_button_" .. item_name,
      elem_type = "item",
      item = item_name,
      style = style
    }
    button.locked = true
  end
end

function process_selected_area_with_this_mod(event, selected)
  local player = game.get_player(event.player_index)
  if not player then return end

  local area = event.area

  log("Selected: " .. selected)
  local tile_name = global.tile_items[selected]
  if not tile_name then
    log_error("No tile available for item " .. selected)
    return
  end

  for x=math.floor(area.left_top.x),math.ceil(area.right_bottom.x)-1 do
    for y=math.floor(area.left_top.y),math.ceil(area.right_bottom.y)-1 do
      local tile = player.surface.get_tile(x, y)

      local tile_prototype = game.tile_prototypes[tile_name]
      if not tile_prototype then
        log_error("No prototype for tile: " .. tile_name)
        return
      end

      -- TODO: Check space exploration validity
      -- TODO: This landfill thing feels like a hack, but I can't figure out how
      -- do it from collision masks on the landfill prototype (vs other tile
      -- types) since they are all the same {"ground-tile"}. This might become
      -- clearer when looking at SE prototypes...
      if (tile_name == "landfill" and tile.collides_with("water-tile")) or (tile_name ~= "landfill" and not tile.collides_with("water-tile")) then
        local existing = tile.get_tile_ghosts(player.force)

        for _, x in pairs(existing) do
          x.destroy()
        end

        player.surface.create_entity {
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