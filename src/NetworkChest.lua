local GlobalState = require "src.GlobalState"
local NetworkChestGui = require "src.NetworkChestGui"
local UiHandlers = require "src.UiHandlers"
local NetworkViewUi = require "src.NetworkViewUi"
local UiConstants = require "src.UiConstants"
local NetworkTankGui = require "src.NetworkTankGui"
local constants = require "src.constants"

local M = {}


function M.on_create(event, entity)
  local requests = {}

  if event.tags ~= nil then
    local requests_tag = event.tags.requests
    if requests_tag ~= nil then
      requests = requests_tag
    end
  end

  GlobalState.register_chest_entity(entity, requests)
end

local function generic_create_handler(event)
  local entity = event.created_entity
  if entity == nil then
    entity = event.entity
  end
  if entity.name == "network-chest" then
    M.on_create(event, entity)
  elseif entity.name == "network-tank" then
    GlobalState.register_tank_entity(entity)
  end
end

function M.on_built_entity(event)
  generic_create_handler(event)
end

function M.script_raised_built(event)
  generic_create_handler(event)
end

function M.on_entity_cloned(event)
  if event.source.name == "network-chest" and event.destination.name == "network-chest" then
    GlobalState.register_chest_entity(event.destination)
    local source_info = GlobalState.get_chest_info(event.source.unit_number)
    local dest_info = GlobalState.get_chest_info(event.destination.unit_number)
    if source_info ~= nil and dest_info ~= nil then
      dest_info.requests = source_info.requests
    end
  end
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
  elseif entity.name == "network-tank" then
    GlobalState.delete_tank_entity(entity.unit_number)
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

-- copied from https://discord.com/channels/139677590393716737/306402592265732098/1112775784411705384
-- on the factorio discord
-- thanks raiguard :)
local function get_blueprint(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local bp = player.blueprint_to_setup
  if bp and bp.valid_for_read then
    return bp
  end

  bp = player.cursor_stack
  if not bp or not bp.valid_for_read then
    return nil
  end

  if bp.type == "blueprint-book" then
    local item_inventory = bp.get_inventory(defines.inventory.item_main)
    if item_inventory then
      bp = item_inventory[bp.active_index]
    else
      return
    end
  end

  return bp
end

function M.on_player_setup_blueprint(event)
  local blueprint = get_blueprint(event)
  if blueprint == nil then
    return
  end

  local entities = blueprint.get_blueprint_entities()
  if entities == nil then
    return
  end

  for _, entity in ipairs(entities) do
    if entity.name == "network-chest" then
      local real_entity = event.surface.find_entity(
        "network-chest",
        entity.position
      )
      if real_entity ~= nil then
        local chest_info = GlobalState.get_chest_info(real_entity.unit_number)
        if chest_info ~= nil then
          blueprint.set_blueprint_entity_tag(
            entity.entity_number,
            "requests",
            chest_info.requests
          )
        end
      end
    end
  end
end

function M.on_entity_settings_pasted(event)
  local source = event.source
  local dest = event.destination
  if dest.name == "network-chest" then
    if source.name == "network-chest" then
      GlobalState.copy_chest_requests(source.unit_number, dest.unit_number)
    else
      local recipe = source.get_recipe()
      if recipe ~= nil then
        local requests = {}
        local buffer_size = settings.global
          ["item-network-stack-size-on-assembler-paste"].value
        for _, ingredient in ipairs(recipe.ingredients) do
          if ingredient.type == "item" then
            local stack_size = game.item_prototypes[ingredient.name].stack_size
            local buffer = math.min(buffer_size, stack_size)
            table.insert(requests, {
              type = "take",
              item = ingredient.name,
              buffer = buffer,
              limit = 0,
            })
          end
        end
        GlobalState.set_chest_requests(dest.unit_number, requests)
      end
    end
  end
end

function M.onDelete(entity)
  GlobalState.delete_chest_entity(entity.unit_number)
  if global.mod.network_chest_gui ~= nil and global.mod.network_chest_gui.entity.unit_number == entity.unit_number then
    global.mod.network_chest_gui.frame.destroy()
    global.mod.network_chest_gui = nil
  end
end

function M.updatePlayers()
  if not global.mod.network_chest_has_been_placed then
    return
  end

  for _, player in pairs(game.players) do
    local enable_trash = settings.get_player_settings(player.index)
      ["item-network-enable-player-logistics"].value

    if enable_trash then
      -- put all trash into network
      local trash_inv = player.get_inventory(defines.inventory.character_trash)
      if trash_inv ~= nil then
        for name, count in pairs(trash_inv.get_contents()) do
          GlobalState.increment_item_count(name, count)
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
              local available_in_network = GlobalState.get_item_count(param.name)
              local current_amount = main_contents[param.name] or 0
              local delta = math.min(available_in_network,
                math.max(0, param.min - current_amount))
              if delta > 0 then
                local n_transfered = main_inv.insert({
                  name = param.name,
                  count = delta,
                })
                GlobalState.set_item_count(
                  param.name,
                  available_in_network - n_transfered
                )
              end
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
    local network_count = GlobalState.get_item_count(request.item)
    if request.type == "take" then
      local n_take = math.max(0, request.buffer - current_count)
      local n_give = math.max(0, network_count - request.limit)
      local n_transfer = math.min(n_take, n_give)
      if n_transfer > 0 then
        contents[request.item] = current_count + n_transfer
        GlobalState.set_item_count(request.item, network_count - n_transfer)
      end
    else
      local n_give = current_count
      local n_take = math.max(0, request.limit - network_count)
      local n_transfer = math.min(n_take, n_give)
      if n_transfer > 0 then
        contents[request.item] = current_count - n_transfer
        GlobalState.set_item_count(request.item, network_count + n_transfer)
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
      GlobalState.increment_item_count(item, count)
    end
  end
end

function M.onTick()
  GlobalState.setup()
  M.update_network()
end

function M.update_network()
  local scanned_units = {}
  for _ = 1, math.min(20, GlobalState.get_scan_queue_size()) do
    local unit_number = GlobalState.scan_queue_pop()
    if unit_number == nil then
      break
    end
    local info = GlobalState.get_chest_info(unit_number)
    if info == nil then
      M.update_tank_queue(unit_number, scanned_units)
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
    GlobalState.scan_queue_push(unit_number)
    ::continue::
  end
end

local function update_tank(info)
  local fluid = info.config.fluid
  local type = info.config.type
  local limit = info.config.limit
  local buffer = info.config.buffer
  local contents = info.entity.get_fluid_contents()
  local other_count = 0
  for fluid0, count in pairs(contents) do
    if fluid0 ~= fluid then
      other_count = other_count + count
    end
  end
  limit = math.min(limit, constants.MAX_TANK_SIZE - other_count)

  local current_count = contents[fluid] or 0
  local network_count = GlobalState.get_fluid_count(fluid)
  -- game.print(string.format(
  --   "updating tank %d, total_contents=%d, fluid=%s, type=%s, current_count=%d, network_count=%d",
  --   info.entity.unit_number,
  --   other_count,
  --   fluid,
  --   type,
  --   current_count,
  --   network_count
  -- ))
  if type == "take" then
    local n_take = math.max(0, buffer - current_count)
    local n_give = math.max(0, network_count - limit)
    local n_transfer = math.min(n_take, n_give)
    if n_transfer > 0 then
      game.print(string.format("taking %d", n_transfer))
      info.entity.insert_fluid({ name = fluid, amount = n_transfer })
      GlobalState.set_fluid_count(fluid, network_count - n_transfer)
    end
  else
    local n_give = current_count
    local n_take = math.max(0, limit - network_count)
    local n_transfer = math.min(n_take, n_give)
    if n_transfer > 0 then
      game.print(string.format("giving %d", n_transfer))
      info.entity.remove_fluid({ name = fluid, amount = n_transfer })
      GlobalState.set_fluid_count(fluid, network_count + n_transfer)
    end
  end
end

function M.update_tank_queue(unit_number, scanned_units)
  local info = GlobalState.get_tank_info(unit_number)
  if info == nil then
    return
  end
  local entity = info.entity
  if not entity.valid then
    return
  end

  if info.config ~= nil and not entity.to_be_deconstructed() then
    if scanned_units[unit_number] == nil then
      scanned_units[unit_number] = true
      update_tank(info)
    end
  end

  GlobalState.scan_queue_push(unit_number)
end

-------------------------------------------
-- GUI Section
-------------------------------------------

function M.on_gui_click(event)
  UiHandlers.handle_generic_gui_event(event, "on_gui_click")
end

function M.on_gui_text_changed(event)
  UiHandlers.handle_generic_gui_event(event, "on_gui_text_changed")
end

function M.on_gui_checked_state_changed(event)
  UiHandlers.handle_generic_gui_event(event, "on_gui_checked_state_changed")
end

function M.on_gui_elem_changed(event)
  UiHandlers.handle_generic_gui_event(event, "on_gui_elem_changed")
end

function M.on_gui_confirmed(event)
  UiHandlers.handle_generic_gui_event(event, "on_gui_confirmed")
end

function M.add_take_btn_enabled()
  local takes = GlobalState.get_chest_info(global.mod.network_chest_gui.entity
    .unit_number).takes
  return #takes == 0 or M.is_request_valid(takes[#takes])
end

function M.add_give_btn_enabled()
  local gives = GlobalState.get_chest_info(global.mod.network_chest_gui.entity
    .unit_number).gives
  return #gives == 0 or M.is_request_valid(gives[#gives])
end

function M.on_gui_opened(event)
  if event.gui_type == defines.gui_type.entity and event.entity.name == "network-chest" then
    local entity = event.entity
    assert(GlobalState.get_chest_info(entity.unit_number) ~= nil)

    local player = game.get_player(event.player_index)
    if player == nil then
      return
    end

    NetworkChestGui.on_gui_opened(player, entity)
  elseif event.gui_type == defines.gui_type.entity and event.entity.name == "network-tank" then
    local entity = event.entity
    assert(GlobalState.get_tank_info(entity.unit_number) ~= nil)

    local player = game.get_player(event.player_index)
    if player == nil then
      return
    end

    NetworkTankGui.on_gui_opened(player, entity)
  end
end

function M.on_gui_closed(event)
  local frame = event.element
  if frame ~= nil and frame.name == UiConstants.NV_FRAME then
    NetworkViewUi.on_gui_closed(event)
  elseif frame ~= nil and frame.name == UiConstants.NT_MAIN_FRAME then
    NetworkTankGui.on_gui_closed(event)
  else
    NetworkChestGui.on_gui_closed(event)
  end
end

function M.in_confirm_dialog(event)
  NetworkChestGui.in_confirm_dialog(event)
end

function M.in_cancel_dialog(event)
  NetworkChestGui.in_cancel_dialog(event)
end

function M.in_open_network_view(event)
  NetworkViewUi.open_main_frame(event.player_index)
end

function M.on_every_5_seconds(event)
  NetworkViewUi.on_every_5_seconds(event)
end

return M
