local Helpers = require "src.Helpers"
local Priority = require "src.Priority"
local GlobalState = require "src.GlobalState"

local M = {}

M.entity_name = "logistic-network-chest"
M.window_name = "8adad23796fd5f01d0b8ecdfff51640b"
M.WIDTH = 600
M.HEIGHT = 400
M.elem_handlers = {}

local MAX_REQUEST_ROW_SIZE = 10

local ADD_ITEM_BUTTON_ID = "838ec0ec7243c435a89ccb02b8c0df6e"
table.insert(M.elem_handlers, {
  elem_id = ADD_ITEM_BUTTON_ID,
  event = "on_gui_elem_changed",
  handler = function(event, state)
    local element = event.element
    local item = element.elem_value
    element.elem_value = nil

    local item_already_picked = false
    for _, request in ipairs(state.requests) do
      if request.item == item then
        item_already_picked = true
        break
      end
    end

    if not item_already_picked then
      table.insert(state.requests, { item = item })
      state.selected_item = #state.requests
      state.has_made_changes = true

      M.rerender(state)
    end
  end,
})

local VIEW_REQUEST_SPRITE_BUTTON_ID = "5c7f290fe03db063b032a8249e349237"
table.insert(M.elem_handlers, {
  elem_id = VIEW_REQUEST_SPRITE_BUTTON_ID,
  event = "on_gui_click",
  handler = function(event, state)
    local request_idx = event.element.tags.request_idx

    if event.button == defines.mouse_button_type.right and event.shift then
      local new_requests = {}
      for idx, request in ipairs(state.requests) do
        if idx ~= request_idx then
          table.insert(new_requests, request)
        end
      end
      state.requests = new_requests
      if state.selected_item > request_idx then
        state.selected_item = state.selected_item - 1
      end
      state.selected_item = math.min(
        state.selected_item,
        #state.requests
      )
    else
      state.selected_item = request_idx
    end
    M.rerender(state)
  end,
})

function M.on_open_window(state, player, entity)
  local entity_info = GlobalState.get_entity_info(entity.unit_number)
  assert(entity_info ~= nil)
  local requests = entity_info.config.requests

  local window_requests = {}
  for _, request in ipairs(requests) do
    table.insert(window_requests, Helpers.shallow_copy(request))
  end
  state.requests = window_requests

  state.dump_mode = entity_info.config.dump_mode

  if #requests > 0 then
    state.selected_item = 1
  end

  state.entity = entity

  local frame = player.gui.screen.add({
    type = "frame",
    caption = "Configure Logistic Network Chest",
    name = M.window_name,
  })
  frame.style.size = { M.WIDTH, M.HEIGHT }
  frame.auto_center = true
  state.frame = frame

  M.rerender(state)

  return frame
end

function M.rerender(state)
  state.frame.clear()

  local main_flow = state.frame.add({
    type = "flow",
    direction = "vertical",
  })

  local add_item_flow = main_flow.add({
    type = "flow",
    direction = "horizontal",
  })
  add_item_flow.add({
    type = "label",
    caption = "Add Request:",
  })

  -- TODO: figure out how to exclude already picked items
  add_item_flow.add({
    type = "choose-elem-button",
    elem_type = "item",
    tags = { elem_id = ADD_ITEM_BUTTON_ID },
  })

  state.requests_flow = main_flow.add({
    type = "scroll-pane",
    direction = "vertical",
    vertical_scroll_policy = "always",
  })
  state.requests_flow.style.size = { M.WIDTH - 30, M.HEIGHT - 120 }
  M.rerender_requests(state)
end

function M.rerender_requests(state)
  state.requests_flow.clear()
  local requests = state.requests
  local request_rows = Helpers.split_list_by_batch_size(
    requests,
    MAX_REQUEST_ROW_SIZE
  )
  local request_idx = 1
  for _, row in ipairs(request_rows) do
    local request_h_stack = state.requests_flow.add({
      type = "flow",
      direction = "horizontal",
    })
    for _, request in ipairs(row) do
      local item_proto = game.item_prototypes[request.item]
      local name = item_proto.localised_name
      local sprite_button = {
        type = "sprite-button",
        elem_type = "item",
        sprite = "item/" .. request.item,
        tags = { elem_id = VIEW_REQUEST_SPRITE_BUTTON_ID, request_idx = request_idx },
        number = request.n_slots,
        toggled = request_idx == state.selected_item,
        tooltip = {
          "in_lnc.sprite_btn_tooltip",
          name,
        },
      }
      local icon = request_h_stack.add(sprite_button)
      icon.number = sprite_button.number
      request_idx = request_idx + 1
    end
  end
end

function M.on_close_window(state)
  local entity_info = GlobalState.get_entity_info(state.entity.unit_number)

  entity_info.config.requests = state.requests
end

return M
