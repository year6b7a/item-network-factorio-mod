local GlobalState = require "src.GlobalState"
local Helpers = require "src.Helpers"
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
    state.config.type = "provide"
    M.rerender(state)
  end,
})

local REQUEST_RADIO_BTN_ID = "46c71b81915f031baf51bf40b6f35dea"
table.insert(M.elem_handlers, {
  elem_id = REQUEST_RADIO_BTN_ID,
  event = "on_gui_click",
  handler = function(event, state)
    state.config.type = "request"
    M.rerender(state)
  end,
})

local PICK_FLUID_BTN_ID = "1edd2b2ca53130f0314471acd6bebf5d"
table.insert(M.elem_handlers, {
  elem_id = PICK_FLUID_BTN_ID,
  event = "on_gui_elem_changed",
  handler = function(event, state)
    state.config.fluid = event.element.elem_value
    M.rerender(state)
  end,
})

local TEMP_INPUT_ID = "bda9e13d37e8ad4d4f2bae91581d45fa"
table.insert(M.elem_handlers, {
  elem_id = TEMP_INPUT_ID,
  event = "on_gui_text_changed",
  handler = function(event, state)
    local temp = tonumber(event.element.text)
    state.config.temp = temp
  end,
})

local TEMP_DROPDOWN_ID = "45ad2a2d3d081002fc624b7f3ae3f266"
table.insert(M.elem_handlers, {
  elem_id = TEMP_DROPDOWN_ID,
  event = "on_gui_selection_state_changed",
  handler = function(event, state)
    local value = state.temp_options[event.element.selected_index]
      .value
    state.config.temp = value
    M.rerender(state)
  end,
})

function M.rerender(state)
  state.frame.clear()

  local main_flow = state.frame.add({ type = "flow", direction = "vertical" })
  local type_flow = main_flow.add({ type = "flow", direction = "horizontal" })

  type_flow.add({ type = "label", caption = "Type:" })
  state.provide_btn = type_flow.add({
    type = "radiobutton",
    state = state.config.type == "provide",
    tags = { elem_id = PROVIDE_RADIO_BTN_ID },
  })

  type_flow.add({ type = "label", caption = "Provide" })
  state.request_btn = type_flow.add({
    type = "radiobutton",
    state = state.config.type == "request",
    tags = { elem_id = REQUEST_RADIO_BTN_ID },
  })
  type_flow.add({ type = "label", caption = "Request" })

  if state.config.type == "request" then
    local fluid_flow = main_flow.add({ type = "flow", direction = "horizontal" })
    fluid_flow.add({ type = "label", caption = "Fluid:" })
    state.fluid_picker = fluid_flow.add({
      type = "choose-elem-button",
      elem_type = "fluid",
      elem_value = state.config.fluid,
      tags = { elem_id = PICK_FLUID_BTN_ID },
    })
    state.fluid_picker.elem_value = state.config.fluid

    local temp_flow = main_flow.add({ type = "flow", direction = "horizontal" })
    temp_flow.add({ type = "label", caption = "Temperature:" })
    local temp_input = temp_flow.add({
      type = "textfield",
      numeric = true,
      allow_decimal = true,
      allow_negative = true,
      tags = { elem_id = TEMP_INPUT_ID },
    })
    if state.config.temp ~= nil then
      temp_input.text = string.format("%s", state.config.temp)
    end
    temp_input.style.width = 100
    state.temp_input = temp_input

    -- temperature dropdown
    state.temp_options = {
      { label = "Choose Temp", value = nil },
    }
    if state.config.fluid ~= nil then
      local available_temps = GlobalState.get_fluid_temps(state.config.fluid)
      for _, temp in ipairs(available_temps) do
        local formatted_temp = string.format("%s", temp)
        table.insert(state.temp_options, {
          label = formatted_temp, value = temp,
        })
      end
    end
    local dropdown_items = {}
    for _, option in ipairs(state.temp_options) do
      table.insert(dropdown_items, option.label)
    end
    temp_flow.add({
      type = "drop-down",
      items = dropdown_items,
      selected_index = 1,
      tags = { elem_id = TEMP_DROPDOWN_ID },
    })
  end
end

function M.on_open_window(state, player, entity)
  local entity_info = GlobalState.get_entity_info(state.entity.unit_number)

  local frame = player.gui.screen.add({
    type = "frame",
    caption = "Configure Network Tank",
  })
  frame.style.size = { M.WIDTH, M.HEIGHT }
  frame.auto_center = true
  state.frame = frame
  state.config = Helpers.shallow_copy(entity_info.config)

  M.rerender(state)

  return frame
end

function M.on_close_window(state)
  local info = GlobalState.get_entity_info(state.entity.unit_number)
  info.config = state.config
end

return M
