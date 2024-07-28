script.on_event({defines.events.on_player_selected_area}, function(event)
    if event.item == 'floor-selection-tool' then
        process_selected_area_with_this_mod(event, false)
    end
end)

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

    for x=math.floor(area.left_top.x),math.ceil(area.right_bottom.x)-1 do
      for y=math.floor(area.left_top.y),math.ceil(area.right_bottom.y)-1 do
        local tile = player.surface.get_tile(x, y)

        if tile.collides_with("water-tile") then
          local ghost = player.surface.create_entity {
            name = "tile-ghost",
            inner_name = "landfill",
            position = {x, y},
            force = player.force,
            player = player
          }
        else
          local ghost = player.surface.create_entity {
            name = "tile-ghost",
            inner_name = "stone-path",
            position = {x, y},
            force = player.force,
            player = player
          }
        end
      end
    end

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