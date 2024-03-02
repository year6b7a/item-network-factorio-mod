local GlobalState = require "src.GlobalState"
local Helpers = require "src.Helpers"
local NetworkChestHelpers = require "src.NetworkChestHelpers"

local M = {}

M.entity_name = "network-loader"
M.window_name = "fbe34f21d5ab8e3c93d1b61b17db6d6a"
M.WIDTH = 600
M.HEIGHT = 500
M.elem_handlers = {}

local FILTERED_ITEM_BTN_ID = "91db5388786f916661cd9a4d0b00aa0b"
table.insert(M.elem_handlers, {
  elem_id = FILTERED_ITEM_BTN_ID,
  event = "on_gui_elem_changed",
  handler = function(event, state)
    local entity = state.entity
    entity.set_filter(1, event.element.elem_value)
    state.frame.destroy()
  end,
})

local SUGGESTED_FILTER_BTN_ID = "b0d36d6c45be711d7292d89ebcd25982"
table.insert(M.elem_handlers, {
  elem_id = SUGGESTED_FILTER_BTN_ID,
  event = "on_gui_click",
  handler = function(event, state)
    local entity = state.entity
    local item = event.element.tags.item
    entity.set_filter(1, item)
    state.frame.destroy()
  end,
})

function M.on_open_window(state, player, entity)
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
    if NetworkChestHelpers.is_network_chest(container.name) then
      local info = GlobalState.get_entity_info(container.unit_number)
      if info ~= nil then
        for _, request in ipairs(info.config.requests) do
          if request.type == "request" then
            add_suggested_filter(request.item)
          end
        end
      end
    end
  end

  local frame = player.gui.screen.add({
    type = "frame",
    caption = "Configure Network Loader",
    name = M.window_name,
  })
  frame.style.size = { M.WIDTH, M.HEIGHT }
  frame.auto_center = true

  local main_flow = frame.add({ type = "flow", direction = "vertical" })

  local filter_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  filter_flow.add({ type = "label", caption = "Filter:" })
  filter_flow.add({
    type = "choose-elem-button",
    elem_type = "item",
    item = filter_item,
    tags = {
      elem_id = FILTERED_ITEM_BTN_ID,
    },
  })

  main_flow.add({ type = "label", caption = "Set Filter from Attached Container:" })

  local suggested_filters_rows = Helpers.split_list_by_batch_size(
    suggested_filters, 10
  )
  local suggested_filters_flow = main_flow.add({
    type = "scroll-pane",
    direction = "vertical",
    vertical_scroll_policy = "always",
  })
  suggested_filters_flow.style.size = {
    width = M.WIDTH - 30,
    height = M.HEIGHT - 130,
  }
  for _, row in ipairs(suggested_filters_rows) do
    local suggested_filter_flow = suggested_filters_flow.add({
      type = "flow",
      direction = "horizontal",
    })
    for _, item_name in ipairs(row) do
      suggested_filter_flow.add({
        type = "sprite-button",
        sprite = "item/" .. item_name,
        tags = {
          elem_id = SUGGESTED_FILTER_BTN_ID,
          item = item_name,
        },
      })
    end
  end

  return frame
end

function M.on_close_window(state)
end

return M
