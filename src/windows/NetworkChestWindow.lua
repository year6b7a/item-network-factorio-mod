local GlobalState = require "src.GlobalState"
local Helpers = require "src.Helpers"

local M = {}

M.entity_name = "network-chest"
M.window_name = "d93ab6fc758ec77450209c321cbe1f9f"
M.WIDTH = 600
M.HEIGHT = 700
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
      table.insert(state.requests, {
        type = "provide",
        item = item,
      })
      state.selected_item = #state.requests
      M.rerender_requests(state)
      M.renreder_selected_item_flow(state)
    end
  end,
})

local VIEW_REQUEST_SPRITE_BUTTON_ID = "5c7f290fe03db063b032a8249e349237"
table.insert(M.elem_handlers, {
  elem_id = VIEW_REQUEST_SPRITE_BUTTON_ID,
  event = "on_gui_click",
  handler = function(event, state)
    local request_idx = event.element.tags.request_idx
    state.selected_item = request_idx
    M.renreder_selected_item_flow(state)
  end,
})

local REQUEST_MODE_DROPDOWN_OPTIONS = {
  { label = "Provide to Network",   value = "provide" },
  { label = "Request from Network", value = "request" },
}

local REQUEST_MODE_DROPDOWN_ID = "b93ece4f5efe2e0d2f45ecd61c44ca9d"
table.insert(M.elem_handlers, {
  elem_id = REQUEST_MODE_DROPDOWN_ID,
  event = "on_gui_selection_state_changed",
  handler = function(event, state)
    local request_idx = state.selected_item
    local request = state.requests[request_idx]
    local value = REQUEST_MODE_DROPDOWN_OPTIONS[event.element.selected_index]
      .value
    state.requests[request_idx] = {
      type = value,
      item = request.item,
    }
    M.renreder_selected_item_flow(state)
  end,
})

local REMOVE_REQUEST_BTN_ID = "35a6053bbb570ace4a806bb32c0f186c"
table.insert(M.elem_handlers, {
  elem_id = REMOVE_REQUEST_BTN_ID,
  event = "on_gui_click",
  handler = function(event, state)
    local request_idx = state.selected_item
    local new_requests = {}
    for idx, request in ipairs(state.requests) do
      if idx ~= request_idx then
        table.insert(new_requests, request)
      end
    end
    state.requests = new_requests
    state.selected_item = nil
    M.rerender_requests(state)
    M.renreder_selected_item_flow(state)
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


  local frame = player.gui.screen.add({
    type = "frame",
    caption = "Configure Network Chest",
    name = M.window_name,
  })
  frame.style.size = { M.WIDTH, M.HEIGHT }
  frame.auto_center = true

  local main_flow = frame.add({
    type = "flow",
    direction = "vertical",
  })

  local add_item_flow = main_flow.add({
    type = "flow",
    direction = "horizontal",
  })
  add_item_flow.add({
    type = "label",
    caption = "Add Item:",
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
  state.requests_flow.style.size = { M.WIDTH - 30, M.HEIGHT - 300 }
  M.rerender_requests(state)

  state.selected_item_flow = main_flow.add({
    type = "flow",
    direction = "vertical",
  })
  M.renreder_selected_item_flow(state)

  state.entity = entity


  return frame
end

function M.rerender_requests(state)
  state.requests_flow.clear()
  local requests = state.requests
  local request_rows = Helpers.split_list_by_batch_size(
    requests,
    MAX_REQUEST_ROW_SIZE
  )
  for _, row in ipairs(request_rows) do
    local request_h_stack = state.requests_flow.add({
      type = "flow",
      direction = "horizontal",
    })
    for request_idx, request in ipairs(row) do
      local sprite_button = {
        type = "sprite-button",
        elem_type = "item",
        sprite = "item/" .. request.item,
        tags = { elem_id = VIEW_REQUEST_SPRITE_BUTTON_ID, request_idx = request_idx },
      }
      request_h_stack.add(sprite_button)
    end
  end
end

function M.renreder_selected_item_flow(state)
  state.selected_item_flow.clear()
  if state.selected_item ~= nil then
    local request = state.requests[state.selected_item]
    local item_proto = game.item_prototypes[request.item]
    local name = item_proto.localised_name

    state.selected_item_flow.add({
      type = "label",
      caption = {
        "",
        "Selected Item: ",
        name,
      },
    })

    local mode_flow = state.selected_item_flow.add({
      type = "flow",
      direction = "horizontal",
    })
    mode_flow.add({
      type = "label",
      caption = "Mode:",
    })
    local dropdown_items = {}
    local selected_index = 0
    for option_idx, option in ipairs(REQUEST_MODE_DROPDOWN_OPTIONS) do
      table.insert(dropdown_items, option.label)
      if option.value == request.type then
        selected_index = option_idx
      end
    end
    mode_flow.add({
      type = "drop-down",
      items = dropdown_items,
      selected_index = selected_index,
      tags = { elem_id = REQUEST_MODE_DROPDOWN_ID },
    })

    local inv = state.entity.get_output_inventory()
    local contents = inv.get_contents()

    state.selected_item_flow.add({
      type = "label",
      caption = {
        "",
        "In Chest: Stored=",
        contents[request.item] or 0,
        ", Desired Capacity=",
        request.desired_capacity or "?",
        ", Capacity=",
        request.capacity or "?",
        ", Slots=",
        request.n_slots or "?",
      },
    })

    local material_info = GlobalState.get_material_info(request.item)
    state.selected_item_flow.add({
      type = "label",
      caption = {
        "",
        "In Network: Stored=",
        material_info.amount,
        ", Limit=",
        material_info.deposit_limit,
      },
    })

    local entity_info = GlobalState.get_entity_info(state.entity.unit_number)
    state.selected_item_flow.add({
      type = "label",
      caption = {
        "",
        "Current Delay: ",
        entity_info.prev_delay or "?",
        ", Max Delay: ",
        GlobalState.get_default_update_period(),
      },
    })

    state.selected_item_flow.add({
      type = "button",
      caption = {
        "",
        "Remove ",
        name,
      },
      tags = { elem_id = REMOVE_REQUEST_BTN_ID },
    })
  end
end

function M.on_close_window(state)
  local entity_info = GlobalState.get_entity_info(state.entity.unit_number)
  entity_info.config = {
    requests = state.requests,
  }
end

return M
