local GlobalState = require "src.GlobalState"
local UiConstants = require "src.UiConstants"

local M = {}

M.WIDTH = 490
M.HEIGHT = 500

function M.open_main_frame(player_index)
  local ui = GlobalState.get_ui_state(player_index)
  if ui.net_view ~= nil then
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

  ui.net_view = {
    frame = frame,
  }

  M.update_items(player_index)
end

function M.update_items(player_index)
  local ui = GlobalState.get_ui_state(player_index)
  local net_view = ui.net_view
  if net_view == nil then
    return
  end
  local item_flow = net_view.frame[UiConstants.MV_ITEM_FLOW]
  if item_flow ~= nil then
    item_flow.destroy()
  end

  item_flow = net_view.frame.add({
    type = "scroll-pane",
    direction = "vertical",
    name = UiConstants.MV_ITEM_FLOW,
    vertical_scroll_policy = "always",
  })
  item_flow.style.size = { width = M.WIDTH - 30, height = M.HEIGHT - 52 }

  local rows = M.get_rows_of_items()
  for _, row in ipairs(rows) do
    local item_h_stack = item_flow.add({
      type = "flow",
      direction = "horizontal",
    })
    for _, item in ipairs(row) do
      local item_view = item_h_stack.add({
        type = "sprite-button",
        elem_type = "item",
        sprite = "item/" .. item.item,
      })
      item_view.number = item.count
    end
  end
end

local function items_list_sort(left, right)
  return left.count > right.count
end

function M.get_list_of_items()
  local items = {}

  for item_name, item_count in pairs(GlobalState.get_items()) do
    if item_count > 0 then
      table.insert(items, { item = item_name, count = item_count })
    end
  end

  table.sort(items, items_list_sort)

  return items
end

function M.get_rows_of_items()
  local items = M.get_list_of_items()
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

function M.on_gui_closed(event)
  local ui = GlobalState.get_ui_state(event.player_index)
  if ui.net_view ~= nil then
    ui.net_view.frame.destroy()
    ui.net_view = nil
  end
end

function M.on_every_5_seconds(event)
  for player_index, _ in pairs(GlobalState.get_player_info_map()) do
    M.update_items(player_index)
  end
end

return M
