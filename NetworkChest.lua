local Queue = require "Queue"
local Constants = require "constants"

local M = {}


function M.setupGlobals()
  if global.mod == nil then
    global.mod = {
      rand = game.create_random_generator(),
      chests = {},
      scan_queue = Queue.new(),
      items = {},
    }
  end
end

function M.rand_hex(len)
  local chars = {}
  for _ = 1, len do
    table.insert(chars, string.format("%x", math.floor(global.mod.rand() * 16)))
  end
  return table.concat(chars, "")
end

function M.on_create(event, entity)
  if global.mod.chests[entity.unit_number] ~= nil then
    return
  end
  local prev_unit_number = nil
  if event.tags ~= nil then
    prev_unit_number = event.tags.unit_number
  end

  local requests = {}
  if prev_unit_number ~= nil then
    local prev_info = global.mod.chests[prev_unit_number]
    if prev_info ~= nil then
      requests = prev_info.requests
    end
  end

  Queue.push(global.mod.scan_queue, entity.unit_number)
  global.mod.chests[entity.unit_number] = {
    entity = entity,
    requests = requests,
  }
end

local function generic_create_handler(event)
  local entity = event.created_entity
  if entity == nil then
    entity = event.entity
  end
  if entity.name == "network-chest" then
    M.on_create(event, entity)
  end
end

function M.on_built_entity(event)
  generic_create_handler(event)
end

function M.script_raised_built(event)
  generic_create_handler(event)
end

function M.on_entity_cloned(event)
  generic_create_handler(event)
end

function M.on_robot_built_entity(event)
  generic_create_handler(event)
end

function M.script_raised_revive(event)
  generic_create_handler(event)
end

local function generic_destroy_handler(event)
  local entity = event.entity
  if entity.name == "network-chest" then
    M.onDelete(entity)
  end
end

function M.on_player_mined_entity(event)
  generic_destroy_handler(event)
end

function M.on_robot_mined_entity(event)
  generic_destroy_handler(event)
end

function M.script_raised_destroy(event)
  generic_destroy_handler(event)
end

function M.on_entity_died(event)
  generic_destroy_handler(event)
end

function M.on_player_setup_blueprint(event)
  local player = game.players[event.player_index]
  local mapping = event.mapping.get()

  local blueprint = player.blueprint_to_setup
  if blueprint.valid_for_read == false then
    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read and cursor.name == "blueprint" then
      blueprint = cursor
    end
  end

  for unit_number, entity in pairs(mapping) do
    if entity.name == "network-chest" then
      blueprint.set_blueprint_entity_tag(
        unit_number,
        "unit_number",
        entity.unit_number
      )
    end
  end
end

function M.on_entity_settings_pasted(event)
  local source = event.source
  local dest = event.destination
  if dest.name == "network-chest" then
    if source.name == "network-chest" then
      global.mod.chests[dest.unit_number].requests =
        global.mod.chests[source.unit_number].requests
    else
      local recipe = source.get_recipe()
      if recipe ~= nil then
        local requests = {}
        for _, ingredient in ipairs(recipe.ingredients) do
          if ingredient.type == "item" then
            local stack_size = game.item_prototypes[ingredient.name].stack_size
            local buffer = math.min(5, stack_size)
            table.insert(requests, {
              type = "take",
              item = ingredient.name,
              buffer = buffer,
              limit = 0,
            })
          end
        end
        global.mod.chests[dest.unit_number].requests = requests
      end
    end
  end
end

function M.onDelete(entity)
  global.mod.chests[entity.unit_number] = nil
  if global.mod.network_chest_gui ~= nil and global.mod.network_chest_gui.entity.unit_number == entity.unit_number then
    global.mod.network_chest_gui.frame.destroy()
    global.mod.network_chest_gui = nil
  end
end

function M.updatePlayers()
  local network_items = global.mod.items
  for _, player in pairs(game.players) do
    -- put all trash into network
    local trash_inv = player.get_inventory(defines.inventory.character_trash)
    if trash_inv ~= nil then
      for name, count in pairs(trash_inv.get_contents()) do
        local current = network_items[name] or 0
        network_items[name] = current + count
      end
      trash_inv.clear()
    end

    -- get contents of player inventory
    local main_inv = player.get_inventory(defines.inventory.character_main)
    if main_inv ~= nil then
      local character = player.character
      if character ~= nil and character.character_personal_logistic_requests_enabled then
        local main_contents = main_inv.get_contents()
        local cursor_stack = player.cursor_stack
        if cursor_stack ~= nil and cursor_stack.valid_for_read then
          main_contents[cursor_stack.name] =
            (main_contents[cursor_stack.name] or 0) + cursor_stack.count
        end

        -- scan logistic slots and transfer to character
        for logistic_idx = 1, character.request_slot_count do
          local param = player.get_personal_logistic_slot(logistic_idx)
          if param ~= nil and param.name ~= nil then
            local available_in_network = network_items[param.name] or 0
            local current_amount = main_contents[param.name] or 0
            local delta = math.min(available_in_network,
              math.max(0, param.min - current_amount))
            if delta > 0 then
              local n_transfered = main_inv.insert({
                name = param.name,
                count = delta,
              })
              network_items[param.name] = available_in_network - n_transfered
            end
          end
        end
      end
    end
  end
end

function M.is_request_valid(request)
  return request.item ~= nil and request.buffer_size ~= nil and
    request.limit ~= nil
end

local function request_list_sort(left, right)
  if left.sort_count == right.sort_count then
    return left.item < right.item
  end
  return left.sort_count < right.sort_count
end


local function update_network_chest(info)
  local net_items = global.mod.items
  local inv = info.entity.get_output_inventory()
  local contents = inv.get_contents()

  -- reset inventory
  inv.clear()
  inv.set_bar()
  for idx = 1, #inv do
    inv.set_filter(idx, nil)
  end

  -- make transfers with network
  for _, request in ipairs(info.requests) do
    local current_count = contents[request.item] or 0
    local network_count = net_items[request.item] or 0
    if request.type == "take" then
      local n_take = math.max(0, request.buffer - current_count)
      local n_give = math.max(0, network_count - request.limit)
      local n_transfer = math.min(n_take, n_give)
      if n_transfer > 0 then
        contents[request.item] = current_count + n_transfer
        net_items[request.item] = network_count - n_transfer
      end
    else
      local n_give = current_count
      local n_take = math.max(0, request.limit - network_count)
      local n_transfer = math.min(n_take, n_give)
      if n_transfer > 0 then
        contents[request.item] = current_count - n_transfer
        net_items[request.item] = network_count + n_transfer
      end
    end
  end

  -- get new sorted requests
  local requests = {}
  for _, request in ipairs(info.requests) do
    local stack_size = game.item_prototypes[request.item].stack_size
    local n_slots = math.ceil(request.buffer / stack_size)
    local n_max = n_slots * stack_size
    local old_count = contents[request.item] or 0
    local new_count = math.min(n_max, old_count)
    contents[request.item] = old_count - new_count
    table.insert(requests, {
      item = request.item,
      sort_count = new_count - request.buffer,
      buffer = request.buffer,
      stack_size = stack_size,
      count = new_count,
      n_slots = n_slots,
    })
  end
  table.sort(requests, request_list_sort)


  -- flatten sorted requests into slots
  local slot_idx = 1
  local bar_idx = 1
  for _, request in ipairs(requests) do
    local count = request.count
    for _ = 1, request.n_slots do
      inv.set_filter(slot_idx, request.item)
      if count > 0 then
        local count_for_current_slot = math.min(count, request.stack_size)
        count = count - count_for_current_slot
        local inserted = inv.insert({
          name = request.item,
          count = count_for_current_slot,
        })
        assert(inserted == count_for_current_slot)
      end
      if request.count < request.buffer then
        bar_idx = bar_idx + 1
      end
      slot_idx = slot_idx + 1
    end
  end
  inv.set_bar(bar_idx)

  -- put additional items into network
  for item, count in pairs(contents) do
    assert(count >= 0)
    if count > 0 then
      local net_count = net_items[item] or 0
      net_items[item] = net_count + count
    end
  end
end

function M.shuffle(list)
  for i = #list, 2, -1 do
    local j = global.mod.rand(i)
    list[i], list[j] = list[j], list[i]
  end
end

function M.onTick()
  M.setupGlobals()
  local scanned_units = {}
  for _ = 1, math.min(20, global.mod.scan_queue.size) do
    local unit_number = Queue.pop_random(global.mod.scan_queue, global.mod.rand)
    if unit_number == nil then
      break
    end
    local info = global.mod.chests[unit_number]
    if info == nil then
      goto continue
    end
    local entity = info.entity
    if not entity.valid then
      goto continue
    end
    if entity.to_be_deconstructed() then
      goto continue
    end
    if scanned_units[unit_number] == nil then
      scanned_units[unit_number] = true
      update_network_chest(info)
    end
    Queue.push(global.mod.scan_queue, unit_number)
    ::continue::
  end
end

-------------------------------------------
-- GUI Section
-------------------------------------------

local NetworkChestGui = {}

NetworkChestGui.event_handlers = {
  {
    name = "add_request",
    event = "on_gui_click",
    handler = function(event, element)
      local player = game.get_player(event.player_index)
      if player == nil then
        return
      end

      NetworkChestGui.open_request_modal(player)
    end,
  },
  {
    name = "choose_take_btn",
    event = "on_gui_checked_state_changed",
    handler = function(event, element)
      local gui = global.mod.network_chest_gui
      local mg = gui.add_request_modal
      mg.request_type = "take"
      mg.choose_give_btn.state = false
      NetworkChestGui.nrm_set_default_buffer_and_limit()
    end,
  },
  {
    name = "choose_give_btn",
    event = "on_gui_checked_state_changed",
    handler = function(event, element)
      local gui = global.mod.network_chest_gui
      local mg = gui.add_request_modal
      mg.request_type = "give"
      mg.choose_take_btn.state = false
      NetworkChestGui.nrm_set_default_buffer_and_limit()
    end,
  },
  {
    name = "new_request_item_picker",
    event = "on_gui_elem_changed",
    handler = function(event, element)
      local gui = global.mod.network_chest_gui
      local mg = gui.add_request_modal
      local item = element.elem_value
      mg.item = item

      NetworkChestGui.nrm_set_default_buffer_and_limit()
    end,
  },
  {
    name = "buffer_size_input",
    event = "on_gui_text_changed",
    handler = function(event, element)
      local gui = global.mod.network_chest_gui
      local mg = gui.add_request_modal
      mg.buffer = tonumber(element.text)
    end,
  },
  {
    name = "limit_input",
    event = "on_gui_text_changed",
    handler = function(event, element)
      local gui = global.mod.network_chest_gui
      local mg = gui.add_request_modal
      mg.limit = tonumber(element.text)
    end,
  },
  {
    name = "set_preset_count",
    event = "on_gui_click",
    handler = function(event, element)
      local gui = global.mod.network_chest_gui
      local mg = gui.add_request_modal
      local count = element.tags.count
      if mg.request_type == "take" then
        NetworkChestGui.nrm_set_buffer(count)
        NetworkChestGui.nrm_set_limit(0)
      else
        NetworkChestGui.nrm_set_buffer(count)
        NetworkChestGui.nrm_set_limit(count)
      end
    end,
  },
  {
    name = "make_new_request_btn",
    event = "on_gui_click",
    handler = function(event, element)
      local gui = global.mod.network_chest_gui
      local mg = gui.add_request_modal
      local request_type = mg.request_type
      local item = mg.item
      local buffer = mg.buffer
      local limit = mg.limit

      if request_type == nil or item == nil or buffer == nil or limit == nil then
        return
      end

      if buffer <= 0 or limit < 0 then
        return
      end

      -- make sure item request does not already exist
      for _, request in ipairs(gui.requests) do
        if (
            element.tags.type == "add"
            or element.tags.type == "edit" and request.id ~= element.tags.request_id
          ) and request.item == item then
          return
        end
      end

      -- make sure request size does not exceed chest size
      local used_slots = 0
      for _, request in ipairs(gui.requests) do
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

      if element.tags.type == "add" then
        local request = {
          id = M.rand_hex(16),
          type = request_type,
          item = item,
          buffer = buffer,
          limit = limit,
        }
        table.insert(gui.requests, request)
        NetworkChestGui.add_request_element(request, gui.requests_scroll)
      elseif element.tags.type == "edit" then
        local request = NetworkChestGui.get_request_by_id(
          element.tags.request_id
        )
        if request ~= nil then
          request.type = request_type
          request.item = item
          request.buffer = buffer
          request.limit = limit
        end
        local request_elem = gui.requests_scroll[element.tags.request_id]
        NetworkChestGui.update_request_element(request, request_elem)
      end
      local player = game.get_player(event.player_index)
      player.opened = gui.frame
    end,
  },
  {
    name = "cancel_network_chest",
    event = "on_gui_click",
    handler = function(event, element)
      local gui = global.mod.network_chest_gui
      gui.do_not_save = true
      NetworkChestGui.close(event, gui.frame)
    end,
  },
  {
    name = "save_network_chest",
    event = "on_gui_click",
    handler = function(event, element)
      local gui = global.mod.network_chest_gui
      NetworkChestGui.close(event, gui.frame)
    end,
  },
  {
    name = "remove_request",
    event = "on_gui_click",
    handler = function(event, element)
      local gui = global.mod.network_chest_gui
      local request_id = element.tags.request_id
      assert(request_id ~= nil)
      for idx, request in ipairs(gui.requests) do
        if request.id == request_id then
          table.remove(gui.requests, idx)
          gui.requests_scroll[request_id].destroy()
          return
        end
      end
      assert(false)
    end,
  },
  {
    name = "edit_request",
    event = "on_gui_click",
    handler = function(event, element)
      local request_id = element.tags.request_id
      assert(request_id ~= nil)

      local player = game.get_player(event.player_index)
      if player == nil then
        return
      end
      NetworkChestGui.open_request_modal(player, "edit", request_id)
    end,
  },
}

function NetworkChestGui.get_request_by_id(request_id)
  if request_id == nil then
    return nil
  end

  local gui = global.mod.network_chest_gui
  for _, request in ipairs(gui.requests) do
    if request.id == request_id then
      return request
    end
  end

  return nil
end

function NetworkChestGui.open_request_modal(player, type, request_id)
  if type == nil then
    type = "add"
  end

  local default_is_take = true
  local default_item = nil
  local default_buffer = nil
  local default_limit = nil

  local request = NetworkChestGui.get_request_by_id(request_id)
  if request ~= nil then
    default_is_take = request.type == "take"
    default_item = request.item
    default_buffer = request.buffer
    default_limit = request.limit
  end

  local gui = global.mod.network_chest_gui
  if gui.add_request_modal ~= nil then
    gui.add_request_modal.frame.destroy()
    gui.add_request_modal = nil
  end

  local width = 400
  local height = 300

  local frame = player.gui.screen.add({
    type = "frame",
    caption = type == "add" and "Add Request" or "Edit Request",
    name = "add-request",
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
    tags = { event = "choose_take_btn" },
  })
  type_flow.add({ type = "label", caption = "Take" })
  local choose_give_btn = type_flow.add({
    type = "radiobutton",
    state = not default_is_take,
    tags = { event = "choose_give_btn" },
  })
  type_flow.add({ type = "label", caption = "Give" })

  local item_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  item_flow.add({ type = "label", caption = "Item:" })
  local item_picker = item_flow.add({
    type = "choose-elem-button",
    elem_type = "item",
    elem_value = default_item,
    tags = { event = "new_request_item_picker" },
  })
  item_picker.elem_value = default_item

  local preset_count_flow = main_flow.add({
    type = "flow",
    direction = "horizontal",
  })
  local presets = {
    { count = 1 },
    { count = 10 },
    { count = 50 },
    { count = 200 },
    { count = 1000 },
  }
  for _, preset in ipairs(presets) do
    local btn_1 = preset_count_flow.add({
      type = "button",
      caption = string.format("%d", preset.count),
      tags = { event = "set_preset_count", count = preset.count },
    })
    btn_1.style.width = 60
  end

  local buffer_flow = main_flow.add({ type = "flow", direction = "horizontal" })
  buffer_flow.add({ type = "label", caption = "Buffer:" })
  local buffer_size_input = buffer_flow.add({
    type = "textfield",
    numeric = true,
    allow_decimal = false,
    allow_negative = false,
    tags = { event = "buffer_size_input" },
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
    tags = { event = "limit_input" },
  })
  if default_limit ~= nil then
    limit_input.text = string.format("%s", default_limit)
  end
  limit_input.style.width = 50

  main_flow.add({
    type = "button",
    caption = type == "add" and "Add Request" or "Confirm Changes",
    tags = { event = "make_new_request_btn", type = type, request_id = request_id },
  })

  frame.style.size = { width, height }
  frame.auto_center = true

  local modal_gui = {
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
  }
  assert(gui.add_request_modal == nil)
  gui.add_request_modal = modal_gui
  player.opened = frame
end

function NetworkChestGui.nrm_set_default_buffer_and_limit()
  local gui = global.mod.network_chest_gui
  local mg = gui.add_request_modal
  if mg.disable_set_defaults_on_change then
    return
  end
  local item = mg.item
  local request_type = mg.request_type
  if item ~= nil and request_type ~= nil then
    local stack_size = game.item_prototypes[item].stack_size
    local buffer = math.min(50, stack_size)
    local limit
    if request_type == "take" then
      limit = 0
    else
      limit = math.min(50, stack_size)
    end
    NetworkChestGui.nrm_set_buffer(buffer)
    NetworkChestGui.nrm_set_limit(limit)
  end
end

function NetworkChestGui.nrm_set_buffer(buffer)
  local mg = global.mod.network_chest_gui.add_request_modal
  mg.buffer = buffer
  mg.buffer_size_input.text = string.format("%d", buffer)
end

function NetworkChestGui.nrm_set_limit(limit)
  local mg = global.mod.network_chest_gui.add_request_modal
  mg.limit = limit
  mg.limit_input.text = string.format("%d", limit)
end

NetworkChestGui.handler_map = {}
for _, handler in ipairs(NetworkChestGui.event_handlers) do
  local name_map = NetworkChestGui.handler_map[handler.event]
  if name_map == nil then
    NetworkChestGui.handler_map[handler.event] = {}
    name_map = NetworkChestGui.handler_map[handler.event]
  end
  assert(name_map[handler.name] == nil)
  name_map[handler.name] = handler
end
function NetworkChestGui.handle_generic_gui_event(event, event_type)
  local element = event.element
  if element == nil then
    return
  end
  local name = element.tags.event
  if name == nil then
    return
  end
  local name_map = NetworkChestGui.handler_map[event_type]
  if name_map == nil then
    return
  end
  local handler = name_map[name]
  if handler == nil then
    return
  end
  handler.handler(event, element)
end

function NetworkChestGui.new(player, chest_entity)
  local width = 600
  local height = 500

  local chest_requests = global.mod.chests[chest_entity.unit_number].requests

  local requests = {}
  for _, request in ipairs(chest_requests) do
    table.insert(requests, {
      type = request.type,
      id = M.rand_hex(16),
      item = request.item,
      buffer = request.buffer,
      limit = request.limit,
    })
  end

  -- close existing frames if they exist
  local prev_gui = global.mod.network_chest_gui
  if prev_gui ~= nil then
    local modal_gui = prev_gui.add_request_modal
    if modal_gui ~= nil then
      modal_gui.frame.destroy()
    end
    prev_gui.frame.destroy()
    global.mod.network_chest_gui = nil
  end

  local frame = player.gui.screen.add({
    type = "frame",
    caption = "Configure Network Chest",
    name = "network-chest-main-frame",
  })
  player.opened = frame
  frame.style.size = { width, height }
  frame.auto_center = true

  local requests_flow = frame.add({ type = "flow", direction = "vertical" })
  local requests_header_flow = requests_flow.add({
    type = "flow",
    direction = "horizontal",
  })
  requests_header_flow.add({ type = "label", caption = "Network Requests" })
  local add_request_btn = requests_header_flow.add({
    type = "button",
    caption = "+",
    tags = { event = "add_request" },
  })
  add_request_btn.style.width = 40
  local requests_scroll = requests_flow.add({
    type = "scroll-pane",
    direction = "vertical",
    vertical_scroll_policy = "always",
  })
  requests_scroll.style.size = { width = width - 30, height = height - 120 }
  for _, request in ipairs(requests) do
    NetworkChestGui.add_request_element(request, requests_scroll)
  end
  local end_button_flow = requests_flow.add({
    type = "flow",
    direction = "horizontal",
  })
  end_button_flow.add({
    type = "button",
    caption = "Save",
    tags = { event = "save_network_chest" },
  })
  end_button_flow.add({
    type = "button",
    caption = "Cancel",
    tags = { event = "cancel_network_chest" },
  })

  local gui = {
    chest_entity = chest_entity,
    requests = requests,
    requests_scroll = requests_scroll,
    frame = frame,
  }

  return gui
end

function NetworkChestGui.add_request_element(request, parent)
  local flow = parent.add({
    type = "flow",
    direction = "horizontal",
    name = request.id,
  })

  local choose_item_button = flow.add({
    name = "item-selection",
    type = "choose-elem-button",
    elem_type = "item",
  })
  choose_item_button.locked = true

  flow.add({
    name = "label",
    type = "label",
  })

  local edit_btn = flow.add({
    type = "button",
    caption = "Edit",
    tags = { event = "edit_request", request_id = request.id },
  })
  edit_btn.style.width = 60

  local remove_btn = flow.add({
    type = "button",
    caption = "x",
    tags = { event = "remove_request", request_id = request.id },
  })
  remove_btn.style.width = 40

  NetworkChestGui.update_request_element(request, flow)
end

function NetworkChestGui.update_request_element(request, element)
  element["item-selection"].elem_value = request.item

  local label
  if request.type == "take" then
    label = string.format("Take when network has more than %d and buffer %d.",
      request.limit,
      request.buffer)
  else
    label = string.format("Give when network has less than %d and buffer %d.",
      request.limit,
      request.buffer)
  end
  element["label"].caption = label
end

function M.on_gui_click(event)
  NetworkChestGui.handle_generic_gui_event(event, "on_gui_click")
end

function M.on_gui_text_changed(event)
  NetworkChestGui.handle_generic_gui_event(event, "on_gui_text_changed")
end

function M.on_gui_checked_state_changed(event)
  NetworkChestGui.handle_generic_gui_event(event, "on_gui_checked_state_changed")
end

function M.on_gui_elem_changed(event)
  NetworkChestGui.handle_generic_gui_event(event, "on_gui_elem_changed")
end

function M.add_take_btn_enabled()
  local takes = global.mod.chests
    [global.mod.network_chest_gui.entity.unit_number].takes
  return #takes == 0 or M.is_request_valid(takes[#takes])
end

function M.add_give_btn_enabled()
  local gives = global.mod.chests
    [global.mod.network_chest_gui.entity.unit_number].gives
  return #gives == 0 or M.is_request_valid(gives[#gives])
end

function M.add_take_element(take, parent)
  local flow = parent.add({
    type = "flow",
    direction = "horizontal",
    name = take.id,
  })

  flow.add({
    type = "choose-elem-button",
    elem_type = "item",
    item = take.item,
    name = "take_item",
    tags = { take_id = take.id },
  })

  local buffer_size_input = flow.add({
    type = "textfield",
    text = take.buffer_size,
    numeric = true,
    allow_decimal = false,
    allow_negative = false,
    name = "take_buffer_size",
    tags = { take_id = take.id },
  })
  buffer_size_input.style.width = 50

  local limit_input = flow.add({
    type = "textfield",
    text = take.limit,
    numeric = true,
    allow_decimal = false,
    allow_negative = false,
    name = "take_limit",
    tags = { take_id = take.id },
  })
  limit_input.style.width = 50

  local remove_btn = flow.add({
    type = "button",
    caption = "x",
    name = "remove_take",
    tags = { take_id = take.id },
  })
  remove_btn.style.width = 40
end

function M.add_give_element(give, parent)
  local flow = parent.add({
    type = "flow",
    direction = "horizontal",
    name = give.id,
  })

  flow.add({
    type = "choose-elem-button",
    elem_type = "item",
    item = give.item,
    name = "give_item",
    tags = { give_id = give.id },
  })

  local buffer_size_input = flow.add({
    type = "textfield",
    text = give.buffer_size,
    numeric = true,
    allow_decimal = false,
    allow_negative = false,
    name = "give_buffer_size",
    tags = { give_id = give.id },
  })
  buffer_size_input.style.width = 50

  local limit_input = flow.add({
    type = "textfield",
    text = give.limit,
    numeric = true,
    allow_decimal = false,
    allow_negative = false,
    name = "give_limit",
    tags = { give_id = give.id },
  })
  limit_input.style.width = 50

  local remove_btn = flow.add({
    type = "button",
    caption = "x",
    name = "remove_give",
    tage = { give_id = give.id },
  })
  remove_btn.style.width = 40
end

function M.on_gui_opened(event)
  if event.gui_type == defines.gui_type.entity and event.entity.name == "network-chest" then
    local entity = event.entity
    assert(global.mod.chests[entity.unit_number] ~= nil)

    local player = game.get_player(event.player_index)
    if player == nil then
      return
    end

    local gui = NetworkChestGui.new(player, entity)
    assert(global.mod.network_chest_gui == nil)
    global.mod.network_chest_gui = gui
  end
end

function NetworkChestGui.close(event, element)
  if element.name == "network-chest-main-frame" then
    local gui = global.mod.network_chest_gui
    local add_request_modal = gui.add_request_modal;
    if add_request_modal == nil then
      if not gui.do_not_save then
        local gui = global.mod.network_chest_gui

        local requests = {}
        for _, request in ipairs(gui.requests) do
          table.insert(requests,
            {
              id = request.id,
              type = request.type,
              item = request.item,
              buffer = request.buffer,
              limit = request.limit,
            })
        end
        global.mod.chests[gui.chest_entity.unit_number].requests = requests
      end
      gui.frame.destroy()
      global.mod.network_chest_gui = nil
    end
  elseif element.name == "add-request" then
    local gui = global.mod.network_chest_gui
    local add_request_modal = gui.add_request_modal;
    add_request_modal.frame.destroy()
    local player = game.get_player(event.player_index)
    player.opened = gui.frame
    gui.add_request_modal = nil
  end
end

function M.on_gui_closed(event)
  if event.element ~= nil then
    NetworkChestGui.close(event, event.element)
  end
end

return M
