local GlobalState = require "src.GlobalState"
local UiConstants = require "src.UiConstants"
local Constants = require "src.constants"

local M = {}

function M.on_gui_opened(player, entity)
  local ui = GlobalState.get_ui_state(player.index)

  -- delete previous frames if exist
  M.reset(player, ui)

  local tank_info = GlobalState.get_tank_info(entity.unit_number)
  if tank_info == nil then
    return
  end

  local default_is_take = true
  local default_item = nil
  local default_buffer = nil
  local default_limit = nil

  if tank_info.config ~= nil then
    default_is_take = tank_info.config.type
    default_item = tank_info.config.item
    default_buffer = tank_info.config.buffer
    default_limit = tank_info.config.limit
  end

  local width = 600
  local height = 500

  local frame = player.gui.screen.add({
    type = "frame",
    caption = "Configure Network Tank",
    name = UiConstants.NT_MAIN_FRAME,
  })
  player.opened = frame
  frame.style.size = { width, height }
  frame.auto_center = true

  local main_flow = frame.add({ type = "flow", direction = "vertical" })

  local type_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  type_flow.add({ type = "label", caption = "Type:" })
  local choose_take_btn = type_flow.add({
    type = "radiobutton",
    state = default_is_take,
    tags = { event = UiConstants.NT_CHOOSE_TAKE_BTN },
  })
  type_flow.add({ type = "label", caption = "Provide" })
  local choose_give_btn = type_flow.add({
    type = "radiobutton",
    state = not default_is_take,
    tags = { event = UiConstants.NT_CHOOSE_GIVE_BTN },
  })
  type_flow.add({ type = "label", caption = "Request" })

  local item_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  item_flow.add({ type = "label", caption = "Item:" })
  local item_picker = item_flow.add({
    type = "choose-elem-button",
    elem_type = "item",
    elem_value = default_item,
    tags = { event = UiConstants.NT_ITEM_PICKER },
  })
  item_picker.elem_value = default_item

  local buffer_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  buffer_flow.add({ type = "label", caption = "Buffer:" })
  local buffer_size_input = buffer_flow.add({
    type = "textfield",
    numeric = true,
    allow_decimal = false,
    allow_negative = false,
    tags = { event = UiConstants.NT_BUFFER_FIELD },
  })
  if default_buffer ~= nil then
    buffer_size_input.text = string.format("%s", default_buffer)
  end
  buffer_size_input.style.width = 50

  local limit_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  limit_flow.add({ type = "label", caption = "Limit:" })
  local limit_input = limit_flow.add({
    type = "textfield",
    numeric = true,
    allow_decimal = false,
    allow_negative = false,
    tags = { event = UiConstants.NT_LIMIT_FIELD },
  })
  if default_limit ~= nil then
    limit_input.text = string.format("%s", default_limit)
  end
  limit_input.style.width = 50

  local save_cancel_flow = main_flow.add({
    type = "flow",
    direction = "horizontal",
  })
  save_cancel_flow.add({
    type = "button",
    caption = "Save",
    tags = {
      event = UiConstants.NT_CONFIRM_EVENT,
    },
  })
  save_cancel_flow.add({
    type = "button",
    caption = "Cancel",
    tags = {
      event = UiConstants.NT_CANCEL_EVENT,
    },
  })

  game.print("setting network tank")
  ui.network_tank = {
    frame = frame,
    unit_number = entity.unit_number,
    choose_take_btn = choose_take_btn,
    choose_give_btn = choose_give_btn,
    buffer_size_input = buffer_size_input,
    limit_input = limit_input,
    type = default_is_take and "take" or "give",
    item = default_item,
    buffer = default_buffer,
    limit = default_limit,
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
  M.destroy_frame(player, UiConstants.NT_MAIN_FRAME)
  ui.network_tank = nil
end

function M.destroy_frame(player, frame_name)
  local frame = player.gui.screen[frame_name]
  if frame ~= nil then
    frame.destroy()
  end
end

function M.set_default_buffer_and_limit(player_index)
  local ui = GlobalState.get_ui_state(player_index)
  local nt_ui = ui.network_tank

  local item = nt_ui.item
  local type = nt_ui.type
  if item ~= nil and type ~= nil then
    local limit
    if type == "take" then
      limit = 0
    else
      limit = Constants.MAX_TANK_SIZE
    end
    M.set_buffer(Constants.MAX_TANK_SIZE, nt_ui)
    M.set_limit(limit, nt_ui)
  end
end

function M.set_buffer(buffer, nt_ui)
  nt_ui.buffer = buffer
  nt_ui.buffer_size_input.text = string.format("%d", buffer)
end

function M.set_limit(limit, nt_ui)
  nt_ui.limit = limit
  nt_ui.limit_input.text = string.format("%d", limit)
end

function M.try_to_confirm(player_index)
  local ui = GlobalState.get_ui_state(player_index)
  local nt_ui = ui.network_tank

  local type = nt_ui.type
  local item = nt_ui.item
  local buffer = nt_ui.buffer
  local limit = nt_ui.limit

  if type == nil or item == nil or buffer == nil or limit == nil then
    return
  end

  if buffer <= 0 or limit < 0 then
    return
  end

  if buffer > Constants.MAX_TANK_SIZE then
    return
  end

  local info = GlobalState.get_tank_info(nt_ui.unit_number)
  if info == nil then
    return
  end

  info.config = {
    type = type,
    item = item,
    buffer = buffer,
    limit = limit,
  }

  M.reset(game.get_player(player_index), ui)
end

return M
