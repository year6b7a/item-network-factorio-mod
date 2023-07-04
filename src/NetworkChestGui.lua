local GlobalState = require "src.GlobalState"
local UiConstants = require "src.UiConstants"
local Constants = require "src.constants"

local M = {}

function M.on_gui_opened(player, chest_entity)
  local ui = GlobalState.get_ui_state(player.index)

  -- delete previous frames if exist
  M.reset(player, ui)

  local chest_info = GlobalState.get_chest_info(chest_entity.unit_number)
  if chest_info == nil then
    return
  end
  local chest_requests = chest_info.requests
  local requests = M.get_ui_requests_from_chest_requests(chest_requests)

  local width = 600
  local height = 500

  local frame = player.gui.screen.add({
    type = "frame",
    caption = "Configure Network Chest",
    name = UiConstants.MAIN_FRAME_NAME,
  })
  player.opened = frame
  frame.style.size = { width, height }
  frame.auto_center = true

  local requests_flow = frame.add({ type = "flow", direction = "vertical" })
  local requests_header_flow = requests_flow.add({
    type = "flow",
    direction = "horizontal",
  })
  requests_header_flow.add({
    type = "button",
    caption = "Add Item",
    tags = { event = UiConstants.ADD_ITEM_BTN_NAME },
  })
  -- add_request_btn.style.width = 40
  local requests_scroll = requests_flow.add({
    type = "scroll-pane",
    direction = "vertical",
    vertical_scroll_policy = "always",
  })
  requests_scroll.style.size = { width = width - 30, height = height - 120 }
  for _, request in ipairs(requests) do
    M.add_request_element(request, requests_scroll)
  end
  local end_button_flow = requests_flow.add({
    type = "flow",
    direction = "horizontal",
  })
  end_button_flow.add({
    type = "button",
    caption = "Save",
    tags = { event = UiConstants.SAVE_NETWORK_CHEST_BTN_NAME },
  })
  end_button_flow.add({
    type = "button",
    caption = "Cancel",
    tags = { event = UiConstants.CANCEL_NETWORK_CHEST_BTN_NAME },
  })

  ui.network_chest = {
    chest_entity = chest_entity,
    requests = requests,
    requests_scroll = requests_scroll,
    frame = frame,
  }
end

function M.add_request_element(request, parent)
  local flow = parent.add({
    type = "flow",
    direction = "horizontal",
    name = request.id,
  })

  flow.add({ name = UiConstants.BEFORE_ITEM_NAME, type = "label" })

  local choose_item_button = flow.add({
    name = UiConstants.CHOOSE_ITEM_NAME,
    type = "choose-elem-button",
    elem_type = "item",
  })
  choose_item_button.locked = true

  flow.add({ name = UiConstants.AFTER_ITEM_NAME, type = "label" })

  local edit_btn = flow.add({
    type = "button",
    caption = "Edit",
    tags = { event = UiConstants.EDIT_REQUEST_BTN, request_id = request.id },
  })
  edit_btn.style.width = 60

  local remove_btn = flow.add({
    type = "button",
    caption = "x",
    tags = { event = UiConstants.REMOVE_REQUEST_BTN, request_id = request.id },
  })
  remove_btn.style.width = 40

  M.update_request_element(request, flow)
end

function M.update_request_element(request, element)
  element[UiConstants.CHOOSE_ITEM_NAME].elem_value = request.item

  local before_item_label
  local after_item_label
  if request.type == "take" then
    before_item_label = "Request"
    after_item_label = string.format(
      "when network has more than %d and buffer %d.",
      request.limit,
      request.buffer
    )
  else
    before_item_label = "Provide"
    after_item_label = string.format(
      "when network has less than %d and buffer %d.",
      request.limit,
      request.buffer
    )
  end
  element[UiConstants.BEFORE_ITEM_NAME].caption = before_item_label
  element[UiConstants.AFTER_ITEM_NAME].caption = after_item_label
end

function M.get_ui_requests_from_chest_requests(chest_requests)
  local requests = {}
  for _, request in ipairs(chest_requests) do
    table.insert(requests, {
      type = request.type,
      id = GlobalState.rand_hex(16),
      item = request.item,
      buffer = request.buffer,
      limit = request.limit,
    })
  end
  return requests
end

function M.reset(player, ui)
  M.destroy_frame(player, UiConstants.MODAL_FRAME_NAME)
  M.destroy_frame(player, UiConstants.MAIN_FRAME_NAME)
  ui.network_chest = nil
end

function M.destroy_frame(player, frame_name)
  local frame = player.gui.screen[frame_name]
  if frame ~= nil then
    frame.destroy()
  end
end

function M.on_gui_closed(event)
  local ui = GlobalState.get_ui_state(event.player_index)
  local close_type = ui.close_type
  ui.close_type = nil


  local element = event.element
  if element == nil then
    return
  end

  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end

  if close_type == nil then
    M.reset(player, ui)
  elseif element.name == UiConstants.MAIN_FRAME_NAME then
    -- make sure that the modal wasn't just opened
    if ui.network_chest.modal == nil then
      M.close_main_frame(player, true)
    end
  elseif element.name == UiConstants.MODAL_FRAME_NAME then
    M.close_modal(player)
  end
end

function M.close_main_frame(player, save_requests)
  local ui = GlobalState.get_ui_state(player.index)
  if save_requests then
    local requests = {}
    for _, request in ipairs(ui.network_chest.requests) do
      table.insert(requests,
        {
          id = request.id,
          type = request.type,
          item = request.item,
          buffer = request.buffer,
          limit = request.limit,
        })
    end
    GlobalState.set_chest_requests(
      ui.network_chest.chest_entity.unit_number,
      requests
    )
  end

  if ui.network_chest.modal ~= nil then
    ui.network_chest.modal.frame.destroy()
  end
  ui.network_chest.frame.destroy()
  ui.network_chest = nil
end

function M.close_modal(player)
  local ui = GlobalState.get_ui_state(player.index)
  if ui.network_chest == nil then
    return
  end
  local modal = ui.network_chest.modal
  if modal == nil then
    return
  end
  modal.frame.destroy()
  ui.network_chest.modal = nil
  player.opened = ui.network_chest.frame
end

function M.get_request_by_id(player, request_id)
  if request_id == nil then
    return nil
  end

  local ui = GlobalState.get_ui_state(player.index).network_chest

  for _, request in ipairs(ui.requests) do
    if request.id == request_id then
      return request
    end
  end

  return nil
end

function M.open_modal(player, type, request_id)
  local default_is_take = true
  local default_item = nil
  local default_buffer = nil
  local default_limit = nil

  local request = M.get_request_by_id(player, request_id)
  if request ~= nil then
    default_is_take = request.type == "take"
    default_item = request.item
    default_buffer = request.buffer
    default_limit = request.limit
  end

  local ui = GlobalState.get_ui_state(player.index)
  if ui.network_chest.modal ~= nil then
    M.close_modal(player)
  end

  local width = 400
  local height = 300

  local frame = player.gui.screen.add({
    type = "frame",
    caption = type == "add" and "Add Item" or "Edit Item",
    name = UiConstants.MODAL_FRAME_NAME,
  })

  local main_flow = frame.add({
    type = "flow",
    direction = "vertical",
  })

  local type_flow = main_flow.add({
    type = "flow",
    direction = "horizontal",
  })
  type_flow.add({ type = "label", caption = "Type:" })
  local choose_take_btn = type_flow.add({
    type = "radiobutton",
    state = default_is_take,
    tags = { event = UiConstants.MODAL_CHOOSE_TAKE_BTN_NAME },
  })
  type_flow.add({ type = "label", caption = "Request" })
  local choose_give_btn = type_flow.add({
    type = "radiobutton",
    state = not default_is_take,
    tags = { event = UiConstants.MODAL_CHOOSE_GIVE_BTN_NAME },
  })
  type_flow.add({ type = "label", caption = "Provide" })

  local item_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  item_flow.add({ type = "label", caption = "Item:" })
  local item_picker = item_flow.add({
    type = "choose-elem-button",
    elem_type = "item",
    elem_value = default_item,
    tags = { event = UiConstants.MODAL_ITEM_PICKER },
  })
  item_picker.elem_value = default_item

  local buffer_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  buffer_flow.add({ type = "label", caption = "Buffer:" })
  local buffer_size_input = buffer_flow.add({
    type = "textfield",
    numeric = true,
    allow_decimal = false,
    allow_negative = false,
    tags = { event = UiConstants.MODAL_BUFFER_FIELD },
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
    tags = { event = UiConstants.MODAL_LIMIT_FIELD },
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
      event = UiConstants.MODAL_CONFIRM_BTN_NAME,
      type = type,
      request_id = request_id,
    },
  })
  save_cancel_flow.add({
    type = "button",
    caption = "Cancel",
    tags = {
      event = UiConstants.MODAL_CANCEL_BTN_NAME,
      type = type,
      request_id = request_id,
    },
  })

  frame.style.size = { width, height }
  frame.auto_center = true

  local modal = {
    frame = frame,
    choose_take_btn = choose_take_btn,
    choose_give_btn = choose_give_btn,
    buffer_size_input = buffer_size_input,
    limit_input = limit_input,
    request_type = default_is_take and "take" or "give",
    item = default_item,
    buffer = default_buffer,
    limit = default_limit,
    disable_set_defaults_on_change = type == "edit",
    modal_type = type,
    request_id = request_id, -- only defined for edit events
  }

  -- the order is is important since setting player.opened = frame
  -- will trigger a "on_gui_closed" event that needs to be ignored.
  ui.network_chest.modal = modal
  ui.close_type = "open modal"
  player.opened = frame
end

function M.in_confirm_dialog(event)
  local ui = GlobalState.get_ui_state(event.player_index)
  ui.close_type = "confirm"
end

function M.in_cancel_dialog(event)
  local ui = GlobalState.get_ui_state(event.player_index)
  ui.close_type = "cancel"
end

local Modal = {}

function Modal.set_default_buffer_and_limit(player_index)
  local ui = GlobalState.get_ui_state(player_index)
  local modal = ui.network_chest.modal

  if not modal.disable_set_defaults_on_change then
    Modal.set_default_buffer(player_index)
    Modal.set_default_limit(player_index)
  end
end

function Modal.set_default_buffer(player_index)
  local ui = GlobalState.get_ui_state(player_index)
  local modal = ui.network_chest.modal
  local item = modal.item
  local request_type = modal.request_type
  if item ~= nil and request_type ~= nil then
    local stack_size = game.item_prototypes[item].stack_size
    local buffer = math.min(50, stack_size)
    Modal.set_buffer(buffer, modal)
  end
end

function Modal.set_default_limit(player_index)
  local ui = GlobalState.get_ui_state(player_index)
  local modal = ui.network_chest.modal
  local item = modal.item
  local request_type = modal.request_type
  if item ~= nil and request_type ~= nil then
    local stack_size = game.item_prototypes[item].stack_size
    local limit
    if request_type == "take" then
      limit = 0
    else
      limit = math.min(50, stack_size)
    end
    Modal.set_limit(limit, modal)
  end
end

function Modal.set_buffer(buffer, modal)
  modal.buffer = buffer
  modal.buffer_size_input.text = string.format("%d", buffer)
end

function Modal.set_limit(limit, modal)
  modal.limit = limit
  modal.limit_input.text = string.format("%d", limit)
end

function Modal.try_to_confirm(player_index)
  local player = game.get_player(player_index)
  local ui = GlobalState.get_ui_state(player_index)
  local chest_ui = ui.network_chest
  local modal = chest_ui.modal

  local modal_type = modal.modal_type
  local request_id = modal.request_id
  local request_type = modal.request_type
  local item = modal.item
  local buffer = modal.buffer
  local limit = modal.limit

  if request_type == nil or item == nil or buffer == nil or limit == nil then
    return
  end

  if buffer <= 0 or limit < 0 then
    return
  end

  -- make sure item request does not already exist
  for _, request in ipairs(chest_ui.requests) do
    if (
        modal_type == "add"
        or modal_type == "edit" and request.id ~= request_id
      ) and request.item == item then
      return
    end
  end

  -- make sure request size does not exceed chest size
  local used_slots = 0
  for _, request in ipairs(chest_ui.requests) do
    local stack_size = game.item_prototypes[request.item].stack_size
    local slots = math.ceil(request.buffer / stack_size)
    used_slots = used_slots + slots
  end
  assert(used_slots <= Constants.NUM_INVENTORY_SLOTS)
  local new_inv_slots = math.ceil(buffer /
    game.item_prototypes[item].stack_size)
  if used_slots + new_inv_slots > Constants.NUM_INVENTORY_SLOTS then
    return
  end

  if modal_type == "add" then
    local request = {
      id = GlobalState.rand_hex(16),
      type = request_type,
      item = item,
      buffer = buffer,
      limit = limit,
    }
    table.insert(chest_ui.requests, request)
    M.add_request_element(request, chest_ui.requests_scroll)
  elseif modal_type == "edit" then
    local request = M.get_request_by_id(player,
      request_id
    )
    if request ~= nil then
      request.type = request_type
      request.item = item
      request.buffer = buffer
      request.limit = limit
    end
    local request_elem = chest_ui.requests_scroll[request_id]
    M.update_request_element(request, request_elem)
  end
  ui.close_type = "confirm_request"
  player.opened = chest_ui.frame
end

M.Modal = Modal

return M
