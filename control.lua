local prefix = "floor_item_picker_button_"

-- Helper function to get the max tiles per tick setting for a player
-- This is a runtime-per-user setting, so each player can have their own value
function get_max_tiles_per_tick(player)
    return settings.get_player_settings(player)["floor-placer-max-tiles-per-tick"].value
end

function log_error(msg)
    local log_prefix = "ERROR: "
    log(log_prefix .. msg)
    game.print(log_prefix .. msg)
end

-- Phase 2: Initialize storage variables for placement queue
script.on_init(function()
    storage.placement_queue = storage.placement_queue or {}
    storage.tick_handler_registered = storage.tick_handler_registered or false
end)

script.on_configuration_changed(function()
    storage.placement_queue = storage.placement_queue or {}
    storage.tick_handler_registered = storage.tick_handler_registered or false
end)

script.on_event({ defines.events.on_player_cursor_stack_changed }, function(event)
    local player = game.get_player(event.player_index)
    if not player then
        log_error("player nil"); return
    end

    if player.cursor_stack and player.cursor_stack.valid_for_read then
        -- Check if the cursor stack item is not the specific item you want
        if player.cursor_stack.name ~= "floor-selection-tool" then
            toggle_off(player)
        end
    else
        if storage.active then
            toggle_off(player)
        end
    end
end)

script.on_event({ defines.events.on_player_selected_area }, function(event)
    if event.item == 'floor-selection-tool' then
        if not storage.active then
            log_error("Selected area but GUI was not toggled on")
            return
        end

        local selected = storage.selected
        if not selected then
            log_error("No item selected")
        end
        process_selected_area_with_this_mod(event, selected)
    end
end)

script.on_event({ defines.events.on_lua_shortcut }, function(event)
    handle_on_lua_shortcut(event)
end)

script.on_event("floor-selection-tool-toggle", function(event)
    local player = game.get_player(event.player_index)
    if not player then
        log_error("player nil"); return
    end

    handle_on_lua_shortcut({
        prototype_name = "floor-shortcut",
        player_index = event.player_index
    })
end)

script.on_event("floor-selection-tool-next-tile", function(event)
    local player = game.get_player(event.player_index)
    if not player then
        log_error("player nil"); return
    end

    if storage.active then
        cycle_tile(player, 1)
    end
end)

script.on_event("floor-selection-tool-previous-tile", function(event)
    local player = game.get_player(event.player_index)
    if not player then
        log_error("player nil"); return
    end

    if storage.active then
        cycle_tile(player, -1)
    end
end)

function handle_on_lua_shortcut(event)
    if event.prototype_name == "floor-shortcut" then
        local data = storage
        local player = game.get_player(event.player_index)
        if not player then
            log_error("player nil"); return
        end

        if not data.active then
            data.active = true

            show_gui(player)

            -- Enable the selection cursor
            -- Check if the cursor stack is valid and clear it if so
            if player.cursor_stack and player.cursor_stack.valid_for_read then
                player.cursor_stack.clear()
            end

            player.cursor_stack.set_stack({ name = "floor-selection-tool", count = 1 })
        else
            toggle_off(player)
        end
    end
end

function toggle_off(player)
    storage.active = false
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
    local player = game.get_player(event.player_index)
    if not player then return end

    local player = game.players[event.player_index]
    if name == "floor_item_picker_close_button" then
        toggle_off(player)
    elseif name == "floor_picker_clear_queue_button" then
        clear_placement_queue()
    else
        local button_prefix = "floor_item_picker_button_"
        if string.find(name, button_prefix) == 1 then
            handle_gui_element_click(name, player)
        end
    end
end)

script.on_event(defines.events.on_gui_location_changed, function(event)
    local element = event.element
    if not (element and element.valid) then
        return
    end

    if element.name ~= "floor_item_picker_frame" then
        return
    end

    storage.gui_location = storage.gui_location or {}
    storage.gui_location[event.player_index] = element.location
end)

function hide_gui(player)
    local frame = player.gui.screen.floor_item_picker_frame

    if frame then
        frame.destroy()
    end
end

function get_available_tile_items()
    local available_tiles = prototypes.get_tile_filtered { { filter = "blueprintable" } }

    local tile_list = {}
    local item_to_tile = {}
    for _, tile in pairs(available_tiles) do
        if tile.items_to_place_this then
            for _, placing_item in pairs(tile.items_to_place_this) do
                local name = placing_item.name
                if not item_to_tile[name] then
                    table.insert(tile_list, name)
                    item_to_tile[name] = tile.name
                end
            end
        end
    end

    return tile_list, item_to_tile
end

function update_gui_selection(player, selected_item)
    storage.selected = selected_item

    local frame = player.gui.screen.floor_item_picker_frame
    if not (frame and frame.valid) then return end

    local inner = frame.inner_frame
    if not (inner and inner.valid) then return end

    local scroll = inner.tile_scroll_pane
    if not (scroll and scroll.valid) then return end

    local selector = scroll.tile_selector
    if not (selector and selector.valid) then return end

    for _, option_name in pairs(selector.children_names) do
        local item_name = string.sub(option_name, string.len(prefix) + 1)
        if item_name == selected_item then
            selector[option_name].style = "slot_sized_button_pressed"
        else
            selector[option_name].style = "slot_sized_button"
        end
    end
end

function handle_gui_element_click(element_name, player)
    local selected_item = string.sub(element_name, string.len(prefix) + 1)
    update_gui_selection(player, selected_item)
end

function cycle_tile(player, direction)
    local tile_list = select(1, get_available_tile_items())

    if #tile_list == 0 then
        return
    end

    -- Find the current selected tile index
    local current_index = nil
    for i, item_name in ipairs(tile_list) do
        if item_name == storage.selected then
            current_index = i
            break
        end
    end

    if not current_index then
        -- If no tile is selected or it's not in the list, select the first one
        current_index = 1
    else
        -- Move to next or previous tile with wrapping
        current_index = current_index + direction
        if current_index > #tile_list then
            current_index = 1
        elseif current_index < 1 then
            current_index = #tile_list
        end
    end

    local new_selected = tile_list[current_index]
    update_gui_selection(player, new_selected)
end

function show_gui(player)
    local tile_list, items = get_available_tile_items()

    local old_selected = storage.selected
    local new_selected = nil

    for _, name in ipairs(tile_list) do
        if old_selected == nil then
            old_selected = name
            new_selected = name
        else
            if old_selected == name then
                new_selected = old_selected
            end
        end
    end

    if not new_selected then
        log_error("No available items to place paths")
        storage.selected = nil
        return false
    end

    storage.selected = new_selected
    -- Store the list for easy reference when processing button clicks
    storage.tile_items = items

    -- per-player storage
    storage.gui_location = storage.gui_location or {}
    local saved_location = storage.gui_location[player.index]

    local frame = player.gui.screen.add {
        type = "frame",
        name = "floor_item_picker_frame",
        direction = "vertical",
    }

    if saved_location then
        frame.location = saved_location
    else
        frame.auto_center = true
    end

    local titlebar_flow = frame.add {
        type = "flow",
        direction = "horizontal",
    }
    titlebar_flow.style.horizontal_spacing = 6

    titlebar_flow.drag_target = frame
    titlebar_flow.add {
        type = "label",
        caption = { "floor-placer-gui.title" },
        ignored_by_interaction = true,
        style = "frame_title"
    }

    local widget = titlebar_flow.add {
        type = "empty-widget",
        ignored_by_interaction = true,
    }
    --widget.style.parent = "draggable_space_header"
    widget.style.height = 24
    widget.style.horizontally_stretchable = true
    --widget.style.left_margin = 4
    --widget.style.right_margin = 4

    -- Add clear queue button
    local clear_button = titlebar_flow.add {
        type = "sprite-button",
        name = "floor_picker_clear_queue_button",
        sprite = "utility/trash_white",
        hovered_sprite = "utility/trash",
        clicked_sprite = "utility/trash",
        tooltip = { "floor-placer-gui.clear-queue-tooltip" },
    }
    clear_button.style.height = 24
    clear_button.style.width = 24

    local close_button = titlebar_flow.add {
        type = "sprite-button",
        name = "floor_item_picker_close_button",
        sprite = "utility/close",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        tooltip = { "floor-placer-gui.close-button-tooltip" },
        --style="close_button"
    }
    close_button.style.height = 24
    close_button.style.width = 24

    local innerFrame = frame.add {
        type = "frame",
        name = "inner_frame",
        direction = "vertical",
        style = "inside_shallow_frame",
    }

    -------------------------------------

    local scroll_pane = innerFrame.add {
        type = "scroll-pane",
        name = "tile_scroll_pane",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto",
    }
    scroll_pane.style.maximal_height = 300
    scroll_pane.style.minimal_width = 400
    scroll_pane.style.padding = 4

    local flow = scroll_pane.add {
        type = "table",
        name = "tile_selector",
        column_count = 12,
        style = "table",
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

    player.opened = frame
    return frame
end

-- Calculate the total number of tiles in an area
function calculate_total_tiles(area)
    local width = math.ceil(area.right_bottom.x) - math.floor(area.left_top.x)
    local height = math.ceil(area.right_bottom.y) - math.floor(area.left_top.y)
    return width * height
end

-- Convert a linear offset to (x, y) coordinates within an area
-- Processes tiles row-by-row (left-to-right, top-to-bottom)
function get_tile_coords_for_offset(area, offset)
    local left = math.floor(area.left_top.x)
    local top = math.floor(area.left_top.y)
    local width = math.ceil(area.right_bottom.x) - left

    local x = left + (offset % width)
    local y = top + math.floor(offset / width)

    return { x = x, y = y }
end

-- Returns an array of coordinate tables: { {x=x1, y=y1}, {x=x2, y=y2}, ... }
function get_tiles_to_process_this_tick(job, max_tiles)
    local total_tiles = calculate_total_tiles(job.area)
    local tiles_remaining = total_tiles - job.offset
    local tiles_to_process = math.min(max_tiles, tiles_remaining)

    local coords = {}
    for i = 0, tiles_to_process - 1 do
        local coord = get_tile_coords_for_offset(job.area, job.offset + i)
        table.insert(coords, coord)
    end

    return coords
end

function register_tick_handler()
    if not storage.tick_handler_registered then
        script.on_event(defines.events.on_tick, process_placement_queue)
        storage.tick_handler_registered = true
    end
end

function deregister_tick_handler()
    if storage.tick_handler_registered then
        script.on_event(defines.events.on_tick, nil)
        storage.tick_handler_registered = false
    end
end

function clear_placement_queue()
    storage.placement_queue = {}
    deregister_tick_handler()
end

function process_placement_queue(event)
    -- Check if queue is empty
    if not storage.placement_queue or #storage.placement_queue == 0 then
        deregister_tick_handler()
        return
    end

    -- Get the first (oldest) job from the queue
    local job = storage.placement_queue[1]

    -- Get the player's setting value
    local max_tiles_per_tick = get_max_tiles_per_tick(job.player)

    -- Calculate which tiles to process this tick
    local coords = get_tiles_to_process_this_tick(job, max_tiles_per_tick)

    -- Process each tile
    for _, coord in ipairs(coords) do
        process_tile_placement(coord.x, coord.y, job.tile_name, job.surface, job.force, job.player)
    end

    -- Update the job's offset
    job.offset = job.offset + #coords

    -- Check if job is complete
    local total_tiles = calculate_total_tiles(job.area)
    if job.offset >= total_tiles then
        -- Job complete, remove from queue
        table.remove(storage.placement_queue, 1)
    end

    -- If queue is now empty, deregister handler
    if #storage.placement_queue == 0 then
        deregister_tick_handler()
    end
end

-- Process placement of a single tile at coordinates (x, y)
-- Extracted from the double-loop in process_selected_area_with_this_mod
function process_tile_placement(x, y, tile_name, surface, force, player)
    local tile = surface.get_tile(x, y)

    -- From satellite view it is possible to select a tile from a chunk that
    -- hasn't been generated yet. These need to be skipped.
    if not tile.valid then
        return
    end

    local placing_tile_prototype = prototypes.tile[tile_name]
    if not placing_tile_prototype then
        log_error("No prototype for tile: " .. tile_name)
        return
    end

    -- TODO: Test this on non-Nauvis planets
    -- Non-foundation tiles must be placed on ground or foundation ghosts
    -- Foundation tiles must be placed on water
    local can_place = not placing_tile_prototype.is_foundation and tile.collides_with("ground_tile") or
        (placing_tile_prototype.is_foundation and tile.collides_with("water_tile"))

    local existing = tile.get_tile_ghosts(force)

    for _, entity in pairs(existing) do
        if entity.ghost_type == "tile" then
            if not placing_tile_prototype.is_foundation and prototypes.tile[entity.ghost_name].is_foundation then
                -- We're trying to place a ground tile on water, which normally
                -- isn't allowed, but there is a landfill ghost waiting to be placed
                -- so we can layer on top of it.
                --
                -- A possible future feature is to allow auto-placing of landfill (need to consider non-Nauvis planets).
                can_place = true
            else
                -- This tile doesn't pair with what we're placing, destroy it so we can replace it.
                entity.destroy()
            end
        end
    end

    -- If the tile is already the tile we're trying to place, nothing to do!
    if tile.name == tile_name then
        can_place = false
    end

    if can_place then
        surface.create_entity {
            name = "tile-ghost",
            inner_name = tile_name,
            position = { x, y },
            force = force,
            player = player
        }
    end
end

function process_selected_area_with_this_mod(event, selected)
    local player = game.get_player(event.player_index)
    if not player then return end

    local area = event.area

    local tile_name = storage.tile_items[selected]
    if not tile_name then
        log_error("No tile available for item " .. selected)
        return
    end

    local total_tiles = calculate_total_tiles(area)
    local max_tiles_per_tick = get_max_tiles_per_tick(player)

    if total_tiles <= max_tiles_per_tick then
        -- Fast path: Process immediately for small areas
        for x = math.floor(area.left_top.x), math.ceil(area.right_bottom.x) - 1 do
            for y = math.floor(area.left_top.y), math.ceil(area.right_bottom.y) - 1 do
                process_tile_placement(x, y, tile_name, player.surface, player.force, player)
            end
        end
    else
        -- Queue path: Create job and enqueue for rate-limited processing
        local job = {
            area = area,
            tile_name = tile_name,
            surface = player.surface,
            force = player.force,
            player = player,
            offset = 0
        }

        table.insert(storage.placement_queue, job)
        register_tick_handler()
    end
end
