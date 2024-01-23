local GlobalState = require "src.GlobalState"
local Helpers = require "src.Helpers"
local M = {}

M.window_name = "587cd09398c9bdedbae71dfd4d85ad5d"
M.WIDTH = 600
M.HEIGHT = 500
M.elem_handlers = {}

local FLUID_SPRITE_BUTTON_ID = "31753ec1c16be04d2ee672f95d044880"
table.insert(M.elem_handlers, {
  elem_id = FLUID_SPRITE_BUTTON_ID,
  event = "on_gui_click",
  handler = function(event, state)
    local fluid_idx = event.element.tags.fluid_idx
    state.fluid_idx = fluid_idx
    state.temp = nil
    M.rerender(state)
  end,
})

local TEMP_INPUT_ID = "392405bfdb7de2a00a0feed49e2ca233"
table.insert(M.elem_handlers, {
  elem_id = TEMP_INPUT_ID,
  event = "on_gui_text_changed",
  handler = function(event, state)
    local temp = tonumber(event.element.text)
    state.temp = temp
    state.submit_btn.enabled = state.temp ~= nil
  end,
})

local TEMP_DROPDOWN_ID = "a0bcfd071ab1b903fa9d4b026bf40818"
table.insert(M.elem_handlers, {
  elem_id = TEMP_DROPDOWN_ID,
  event = "on_gui_selection_state_changed",
  handler = function(event, state)
    local value = state.temp_options[event.element.selected_index]
      .value
    state.temp = value
    M.rerender(state)
  end,
})

local SUBMIT_BTN_ID = "6c8ac2c0f27cf712119e6d7417420ec6"
table.insert(M.elem_handlers, {
  elem_id = SUBMIT_BTN_ID,
  event = "on_gui_click",
  handler = function(event, state)
    local player = game.get_player(event.player_index)
    local fluid = state.fluid_options[state.fluid_idx]
    local temp = state.temp
    if player ~= nil and temp ~= nil then
      local entity_info = GlobalState.get_entity_info(state.entity.unit_number)
      entity_info.config = {
        type = "request",
        fluid = fluid.name,
        temp = temp,
      }
      player.opened = nil
    end
  end,
})

function M.open_window(player, entity, fluid_options)
  assert(#fluid_options > 0)
  local frame = player.gui.screen.add({
    type = "frame",
    name = M.window_name,
    caption = { "in_ntp.frame_name" },
  })
  frame.style.size = { M.WIDTH, M.HEIGHT }
  frame.auto_center = true


  local state = {
    name = M.window_name,
    entity = entity,
    frame = frame,
    fluid_options = fluid_options,
    fluid_idx = 1,
  }

  M.rerender(state)

  local player_state = GlobalState.get_player_info(player.index)
  player_state.window = state
  player.opened = frame
end

function M.rerender(state)
  state.frame.clear()

  local main_flow = state.frame.add({ type = "flow", direction = "vertical" })

  main_flow.add({ type = "label", caption = { "in_ntp.choose_fluid_type" } })

  local fluids_flow = main_flow.add({
    type = "scroll-pane",
    direction = "vertical",
    vertical_scroll_policy = "always",
  })
  fluids_flow.style.size = { M.WIDTH - 30, 300 }

  local fluid_rows = Helpers.split_list_by_batch_size(
    state.fluid_options, 10
  )
  local fluid_idx = 1
  for _, row in ipairs(fluid_rows) do
    local fluid_h_stack = fluids_flow.add({
      type = "flow",
      direction = "horizontal",
    })
    for _, fluid in ipairs(row) do
      local fluid_proto = game.fluid_prototypes[fluid.name]
      local sprite_button = {
        type = "sprite-button",
        elem_type = "item",
        sprite = "fluid/" .. fluid.name,
        tooltip = {
          "in_ntp.fluid_sprite_btn_tooltip",
          fluid_proto.localised_name,
          fluid.minimum_temperature == nil and { "in_ntp.none" } or
          { "format-degrees-c", string.format("%.0f", fluid.minimum_temperature) },
          fluid.maximum_temperature == nil and { "in_ntp.none" } or
          { "format-degrees-c", string.format("%.0f", fluid.maximum_temperature) },
        },
        tags = { elem_id = FLUID_SPRITE_BUTTON_ID, fluid_idx = fluid_idx },
        toggled = fluid_idx == state.fluid_idx,
      }
      fluid_h_stack.add(sprite_button)
      fluid_idx = fluid_idx + 1
    end
  end

  -- temperature choices
  state.temp_options = {
    { label = "Choose Temp", value = nil },
  }
  local selected_fluid = state.fluid_options[state.fluid_idx]
  local fluid_proto = game.fluid_prototypes[selected_fluid.name]
  local available_temps = GlobalState.get_fluid_temps(selected_fluid.name)
  for _, temp in ipairs(available_temps) do
    local formatted_temp = string.format("%s", temp)
    table.insert(state.temp_options, {
      label = formatted_temp, value = temp,
    })
  end
  if state.temp == nil then
    if #state.temp_options >= 2 then
      state.temp = state.temp_options[2].value
    end
  end

  local temp_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  temp_flow.add({ type = "label", caption = "Temperature:" })
  local temp_input = temp_flow.add({
    type = "textfield",
    numeric = true,
    allow_decimal = true,
    allow_negative = true,
    tags = { elem_id = TEMP_INPUT_ID },
  })

  if state.temp ~= nil then
    temp_input.text = string.format("%s", state.temp)
  end
  temp_input.style.width = 100
  state.temp_input = temp_input

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

  state.submit_btn = main_flow.add({
    type = "button",
    caption = { "in_ntp.submit", fluid_proto.localised_name },
    tags = { elem_id = SUBMIT_BTN_ID },
    enabled = state.temp ~= nil,
  })
end

function M.on_close_window(state)
end

return M
