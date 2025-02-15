local floorSelectionTool = table.deepcopy(
                              data.raw["selection-tool"]["selection-tool"])

floorSelectionTool.name = "floor-selection-tool"
-- floorSelectionTool.icon = "__pump__/graphics/icons/pump_icon_32.png"
-- floorSelectionTool.icon_size = 32
-- floorSelectionTool.icon_mipmaps = 0
floorSelectionTool.select.mode = {"any-tile"}
floorSelectionTool.flags = {"only-in-cursor", "spawnable", "not-stackable"}
floorSelectionTool.subgroup = "tool"
floorSelectionTool.order = "c[automated-construction]-d[floor-selection-tool]"
floorSelectionTool.stack_size = 1

local floorShortcut = table.deepcopy(data.raw["shortcut"]["give-blueprint"])
floorShortcut.name = "floor-shortcut"
floorShortcut.action = "lua"
floorShortcut.technology_to_unlock = nil
floorShortcut.localised_name = nil
floorShortcut.associated_control_input = "floor-selection-tool-toggle"
floorShortcut.style = "default"

data:extend{floorSelectionTool, floorShortcut}

data:extend{
    {
        type = "custom-input",
        name = "floor-selection-tool-toggle",
        key_sequence = "CONTROL + SHIFT + F",
    },
}