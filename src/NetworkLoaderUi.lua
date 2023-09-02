local GlobalState = require "src.GlobalState"
local UiConstants = require "src.UiConstants"

local M = {}

function M.on_gui_opened(player, entity)
  local ui = GlobalState.get_ui_state(player.index)

  -- delete previous frame if exists
  M.reset(player, ui)

  local filter_item = entity.get_filter(1)

  local container = entity.loader_container
  local suggested_filters_dict = {}
  local suggested_filters = {}
  local function add_suggested_filter(item)
    if suggested_filters_dict[item] == nil then
      suggested_filters_dict[item] = true
      table.insert(suggested_filters, item)
    end
  end

  if container ~= nil then
    if container.name == "network-chest" then
      local info = GlobalState.get_chest_info(container.unit_number)
      if info ~= nil then
        for _, request in ipairs(info.requests) do
          if request.type == "take" then
            add_suggested_filter(request.item)
          end
        end
      end
    end
  end


  local width = 600
  local height = 500

  local frame = player.gui.screen.add({
    type = "frame",
    caption = "Configure Network Loader",
    name = UiConstants.NL_MAIN_FRAME,
  })
  frame.style.size = { width, height }
  frame.auto_center = true

  local main_flow = frame.add({ type = "flow", direction = "vertical" })

  local filter_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  filter_flow.add({ type = "label", caption = "Filter:" })
  filter_flow.add({
    type = "choose-elem-button",
    elem_type = "item",
    item = filter_item,
    tags = {
      event = UiConstants.NL_FILTERED_ITEM_BTN,
    },
  })

  main_flow.add({ type = "label", caption = "Set Filter from Attached Container:" })

  local attached_filters_flow = main_flow.add({
    type = "flow",
    direction = "horizontal",
  })
  for _, item_name in ipairs(suggested_filters) do
    attached_filters_flow.add({
      type = "sprite-button",
      sprite = "item/" .. item_name,
      tags = {
        event = UiConstants.NL_SUGGESTED_FILTER_BTN,
        item = item_name,
      },
    })
  end

  player.opened = frame

  local ui = GlobalState.get_ui_state(player.index)
  ui.loader = {
    entity = entity,
  }
end

function M.on_gui_closed(event)
  local ui = GlobalState.get_ui_state(event.player_index)

  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end

  M.reset(player, ui)
end

function M.reset(player, ui)
  M.destroy_frame(player, UiConstants.NL_MAIN_FRAME)
end

function M.destroy_frame(player, frame_name)
  local frame = player.gui.screen[frame_name]
  if frame ~= nil then
    frame.destroy()
  end
end

return M
