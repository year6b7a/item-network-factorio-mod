local GlobalState = require "src.GlobalState"
local M = {}

M.entity_name = "network-tank"
M.window_name = "570e17690fa28f717dbd3f2dbc16f135"
M.WIDTH = 600
M.HEIGHT = 500
M.elem_handlers = {}

local PROVIDE_RADIO_BTN_ID = "b47c2883fdf5528c13df768d0909c8e3"
table.insert(M.elem_handlers, {
  elem_id = PROVIDE_RADIO_BTN_ID,
  event = "on_gui_click",
  handler = function(event, state)
    state.request_btn.state = false
  end,
})

local REQUEST_RADIO_BTN_ID = "46c71b81915f031baf51bf40b6f35dea"
table.insert(M.elem_handlers, {
  elem_id = REQUEST_RADIO_BTN_ID,
  event = "on_gui_click",
  handler = function(event, state)
    state.provide_btn.state = false
  end,
})

local PICK_FLUID_BTN_ID = "1edd2b2ca53130f0314471acd6bebf5d"
table.insert(M.elem_handlers, {
  elem_id = PICK_FLUID_BTN_ID,
  event = "on_gui_elem_changed",
  handler = function(event, state)
  end,
})

local TEMP_INPUT_ID = "bda9e13d37e8ad4d4f2bae91581d45fa"
table.insert(M.elem_handlers, {
  elem_id = TEMP_INPUT_ID,
  event = "on_gui_click",
  handler = function(event, state)
  end,
})

function M.on_open_window(state, player, entity)
  local entity_info = GlobalState.get_entity_info(state.entity.unit_number)

  local frame = player.gui.screen.add({
    type = "frame",
    caption = "Configure Network Tank",
  })
  frame.style.size = { M.WIDTH, M.HEIGHT }
  frame.auto_center = true

  local main_flow = frame.add({ type = "flow", direction = "vertical" })

  local type_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  type_flow.add({ type = "label", caption = "Type:" })
  state.provide_btn = type_flow.add({
    type = "radiobutton",
    state = entity_info.config.type == "provide",
    tags = { elem_id = PROVIDE_RADIO_BTN_ID },
  })
  type_flow.add({ type = "label", caption = "Provide" })
  state.request_btn = type_flow.add({
    type = "radiobutton",
    state = entity_info.config.type == "request",
    tags = { elem_id = REQUEST_RADIO_BTN_ID },
  })
  type_flow.add({ type = "label", caption = "Request" })

  local fluid_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  fluid_flow.add({ type = "label", caption = "Fluid:" })
  state.fluid_picker = fluid_flow.add({
    type = "choose-elem-button",
    elem_type = "fluid",
    elem_value = entity_info.config.fluid,
    tags = { elem_id = PICK_FLUID_BTN_ID },
  })
  state.fluid_picker.elem_value = entity_info.config.fluid

  local temp_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  temp_flow.add({ type = "label", caption = "Temperature:" })
  local temp_input = temp_flow.add({
    type = "textfield",
    numeric = true,
    allow_decimal = true,
    allow_negative = true,
    tags = { elem_id = TEMP_INPUT_ID },
  })
  if entity_info.config.temp ~= nil then
    temp_input.text = string.format("%s", entity_info.config.temp)
  end
  temp_input.style.width = 100
  state.temp_input = temp_input

  return frame
end

function M.on_close_window(state)
  local info = GlobalState.get_entity_info(state.entity.unit_number)

  if state.request_btn.state then
    info.config.type = "request"
  else
    info.config.type = "provide"
  end

  local temp = tonumber(state.temp_input.text)
  if temp ~= nil then
    info.config.temp = temp
  end

  local fluid = state.fluid_picker.elem_value
  if fluid ~= nil then
    info.config.fluid = fluid
  end
end

return M
