local GlobalState = require "src.GlobalState"
local UiConstants = require "src.UiConstants"

local M = {}

M.WIDTH = 490
M.HEIGHT = 500

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
  local height = M.HEIGHT

  local frame = player.gui.screen.add({
    type = "frame",
    name = UiConstants.NV_FRAME,
    caption = "Network View",
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
  })

  local item_radio = header_flow.add({
    type = "radiobutton",
    state = true,
    tags = { event = UiConstants.NV_ITEM_RADIO },
  })
  header_flow.add({ type = "label", caption = "Items" })

  local fluid_radio = header_flow.add({
    type = "radiobutton",
    state = false,
    tags = { event = UiConstants.NV_FLUID_RADIO },
  })
  header_flow.add({ type = "label", caption = "Fluids" })

  header_flow.add({
    type = "button",
    caption = "Refresh",
    tags = { event = UiConstants.NV_REFRESH_BTN },
  })

  ui.net_view = {
    frame = frame,
    main_flow = main_flow,
    view_type = "item",
    item_radio = item_radio,
    fluid_radio = fluid_radio,
  }

  M.update_items(player_index)
end

function M.update_items(player_index)
  local ui = GlobalState.get_ui_state(player_index)
  local net_view = ui.net_view
  if net_view == nil then
    return
  end
  local item_flow = net_view.main_flow[UiConstants.NV_ITEM_FLOW]
  if item_flow ~= nil then
    item_flow.destroy()
  end

  item_flow = net_view.main_flow.add({
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
      if net_view.view_type == "item" then
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
        sprite = net_view.view_type .. "/" .. item.item,
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
  else
    local fluids_to_display = GlobalState.get_fluids()
    for fluid_name, fluid_temps in pairs(fluids_to_display) do
      for temp, count in pairs(fluid_temps) do
        table.insert(items, { item = fluid_name, count = count, temp = temp })
      end
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
