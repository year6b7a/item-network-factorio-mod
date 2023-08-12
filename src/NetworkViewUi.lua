local GlobalState = require "src.GlobalState"
local UiConstants = require "src.UiConstants"

local M = {}

M.WIDTH = 490
M.HEIGHT = 500

-- Builds the GUI for the item, fluid, and shortage tabs.
local function build_item_page(parent)
  local main_flow = parent.add({
    type = "flow",
    direction = "vertical",
  })

  return main_flow
end

function M.open_main_frame(player_index)
  local ui = GlobalState.get_ui_state(player_index)
  if ui.net_view ~= nil then
    M.destroy(player_index)
    return
  end

  local player = game.get_player(player_index)
  if player == nil then
    return
  end

  local width = M.WIDTH
  local height = M.HEIGHT + 32

  --[[
  I want the GUI to look like this:

  +--------------------------------------------------+
  | Network View ||||||||||||||||||||||||||||| [R][X]|
  +--------------------------------------------------+
  | Items | Fluids | Shortages |                     | <- tabs
  +--------------------------------------------------+
  | [I]  [I]  [I]  [I]  [I]  [I]  [I]  [I]  [I]  [I] | <- content
    ... repeated ...
  | [I]  [I]  [I]  [I]  [I]  [I]  [I]  [I]  [I]  [I] |
  +--------------------------------------------------+

  [R] is refresh button and [X] is close. [I] are item icons with the number overlay.
  I want the ||||| stuff to make the window draggable.
  Right now, I can get it to look right, but it isn't draggable.
  OR I can omit the [R][X] buttons make it draggable.
  ]]

  -- create the main window
  local frame = player.gui.screen.add({
    type = "frame",
    name = UiConstants.NV_FRAME,
    -- enabling the frame caption enables dragging, but
    -- doesn't allow the buttons to be on the top line
    --caption = "Network View",
  })
  player.opened = frame
  frame.style.size = { width, height }
  frame.auto_center = true

  local main_flow = frame.add({
    type = "flow",
    direction = "vertical",
  })

  local header_flow = main_flow.add({
    type = "flow",
    direction = "horizontal",
    style = "dialog_buttons_horizontal_flow",
  })

  header_flow.add {
    type = "label",
    caption = "Network View",
    style = "frame_title",
  }

  header_flow.add {
    type = "empty-widget",
    --style = "draggable_space_header"
    ignored_by_interaction = true,
    style = "flib_titlebar_drag_handle",
  }

  header_flow.add {
    type = "sprite-button",
    sprite = "utility/refresh",
    style = "frame_action_button",
    tooltip = { "gui.refresh" },
    tags = { event = UiConstants.NV_REFRESH_BTN },
  }

  header_flow.add {
    type = "sprite-button",
    sprite = "utility/close_white",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    style = "close_button",
    tags = { event = UiConstants.NV_CLOSE_BTN },
  }

  -- add tabbed stuff
  local tabbed_pane = main_flow.add {
    type = "tabbed-pane",
    tags = { event = UiConstants.NV_TABBED_PANE },
  }

  local tab_item = tabbed_pane.add { type = "tab", caption = "Items" }
  local tab_fluid = tabbed_pane.add { type = "tab", caption = "Fluids" }
  local tab_shortage = tabbed_pane.add { type = "tab", caption = "Shortages" }

  tabbed_pane.add_tab(tab_item, build_item_page(tabbed_pane))
  tabbed_pane.add_tab(tab_fluid, build_item_page(tabbed_pane))
  tabbed_pane.add_tab(tab_shortage, build_item_page(tabbed_pane))

  -- select "items" (not really needed, as that is the default)
  tabbed_pane.selected_tab_index = 1

  ui.net_view = {
    frame = frame,
    tabbed_pane = tabbed_pane,
  }

  M.update_items(player_index)
end

-- used when setting the active tab
local tab_idx_to_view_type = {
  "item",
  "fluid",
  "shortage",
}

function M.update_items(player_index)
  local ui = GlobalState.get_ui_state(player_index)
  local net_view = ui.net_view
  if net_view == nil then
    return
  end
  local tabbed_pane = net_view.tabbed_pane

  net_view.view_type = tab_idx_to_view_type[tabbed_pane.selected_tab_index]
  local main_flow = tabbed_pane.tabs[tabbed_pane.selected_tab_index].content
  if main_flow == nil then
    return
  end

  local item_flow = main_flow[UiConstants.NV_ITEM_FLOW]
  if item_flow ~= nil then
    item_flow.destroy()
  end

  item_flow = main_flow.add({
    type = "scroll-pane",
    direction = "vertical",
    name = UiConstants.NV_ITEM_FLOW,
    vertical_scroll_policy = "always",
  })
  item_flow.style.size = { width = M.WIDTH - 30, height = M.HEIGHT - 82 }

  local rows = M.get_rows_of_items(net_view.view_type)
  for _, row in ipairs(rows) do
    local item_h_stack = item_flow.add({
      type = "flow",
      direction = "horizontal",
    })
    for _, item in ipairs(row) do
      local item_name
      local tooltip
      local sprite_path = net_view.view_type
      if sprite_path == "shortage" then
        if item.temp ~= nil then
          sprite_path = "fluid"
        else
          sprite_path = "item"
        end
      end
      if sprite_path == "item" then
        item_name = game.item_prototypes[item.item].localised_name
        tooltip = { "", item_name, ": ", item.count }
      else
        item_name = game.fluid_prototypes[item.item].localised_name
        tooltip = {
          "",
          item_name,
          ": ",
          string.format("%.0f", item.count),
          " at ",
          { "format-degrees-c", string.format("%.0f", item.temp) },
        }
      end
      local item_view = item_h_stack.add({
        type = "sprite-button",
        elem_type = net_view.view_type,
        sprite = sprite_path .. "/" .. item.item,
        tooltip = tooltip,
      })
      item_view.number = item.count
    end
  end
end

local function items_list_sort(left, right)
  return left.count > right.count
end

function M.get_list_of_items(view_type)
  local items = {}

  if view_type == "item" then
    local items_to_display = GlobalState.get_items()
    for item_name, item_count in pairs(items_to_display) do
      if item_count > 0 then
        table.insert(items, { item = item_name, count = item_count })
      end
    end
  elseif view_type == "fluid" then
    local fluids_to_display = GlobalState.get_fluids()
    for fluid_name, fluid_temps in pairs(fluids_to_display) do
      for temp, count in pairs(fluid_temps) do
        table.insert(items, { item = fluid_name, count = count, temp = temp })
      end
    end
  elseif view_type == "shortage" then
    -- add item shortages
    local missing = GlobalState.missing_item_filter()
    for item_name, count in pairs(missing) do
      table.insert(items, { item = item_name, count = count })
    end

    -- add fluid shortages
    missing = GlobalState.missing_fluid_filter()
    for fluid_key, count in pairs(missing) do
      local fluid_name, temp = GlobalState.fluid_temp_key_decode(fluid_key)
      table.insert(items, { item = fluid_name, count = count, temp = temp })
    end
  end

  table.sort(items, items_list_sort)

  return items
end

function M.get_rows_of_items(view_type)
  local items = M.get_list_of_items(view_type)
  local max_row_count = 10
  local rows = {}
  local row = {}

  for _, item in ipairs(items) do
    if #row == max_row_count then
      table.insert(rows, row)
      row = {}
    end
    table.insert(row, item)
  end

  if #row > 0 then
    table.insert(rows, row)
  end
  return rows
end

function M.destroy(player_index)
  local ui = GlobalState.get_ui_state(player_index)
  if ui.net_view ~= nil then
    ui.net_view.frame.destroy()
    ui.net_view = nil
  end
end

function M.on_gui_closed(event)
  M.destroy(event.player_index)
end

function M.on_every_5_seconds(event)
  for player_index, _ in pairs(GlobalState.get_player_info_map()) do
    M.update_items(player_index)
  end
end

return M
