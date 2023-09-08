local Timer = require "src.Timer"
local NetworkLoaderUi = require "src.NetworkLoaderUi"
local GlobalState = require "src.GlobalState"
local NetworkChestGui = require "src.NetworkChestGui"
local UiHandlers = require "src.UiHandlers"
local NetworkViewUi = require "src.NetworkViewUi"
local UiConstants = require "src.UiConstants"
local NetworkTankGui = require "src.NetworkTankGui"
local Helpers = require "src.Helpers"

local M = {}

function M.on_init()
  GlobalState.setup()
end

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
    local config = nil
    if event.tags ~= nil then
      local config_tag = event.tags.config
      if config_tag ~= nil then
        config = config_tag
      end
    end
    GlobalState.register_tank_entity(entity, config)
  elseif GlobalState.is_logistic_entity(entity.name) then
    GlobalState.logistic_add_entity(entity)
  elseif GlobalState.is_vehicle_entity(entity.name) then
    GlobalState.vehicle_add_entity(entity)
  elseif entity.name == "network-sensor" then
    GlobalState.sensor_add(entity)
  end
end

function M.on_built_entity(event)
  generic_create_handler(event)
end

function M.script_raised_built(event)
  generic_create_handler(event)
end

function M.on_entity_cloned(event)
  if event.source.name ~= event.destination.name then
    return
  end
  local name = event.source.name
  if name == "network-chest" then
    GlobalState.register_chest_entity(event.destination)
    local source_info = GlobalState.get_chest_info(event.source.unit_number)
    local dest_info = GlobalState.get_chest_info(event.destination.unit_number)
    if source_info ~= nil and dest_info ~= nil then
      dest_info.requests = source_info.requests
    end
  elseif name == "network-tank" then
    GlobalState.register_tank_entity(event.source)
    GlobalState.register_tank_entity(event.destination)
    GlobalState.copy_tank_config(
      event.source.unit_number,
      event.destination.unit_number
    )
  elseif GlobalState.is_logistic_entity(name) then
    GlobalState.logistic_add_entity(event.destination)
  elseif GlobalState.is_vehicle_entity(name) then
    GlobalState.vehicle_add_entity(event.destination)
  elseif name == "network-sensor" then
    GlobalState.sensor_add(event.destination)
  end
end

function M.on_robot_built_entity(event)
  generic_create_handler(event)
end

function M.script_raised_revive(event)
  generic_create_handler(event)
end

function M.generic_destroy_handler(event, opts)
  if opts == nil then
    opts = {}
  end

  local entity = event.entity
  if entity.unit_number == nil then
    return
  end
  if entity.name == "network-chest" then
    GlobalState.put_chest_contents_in_network(entity)
    if not opts.do_not_delete_entity then
      GlobalState.delete_chest_entity(entity.unit_number)
    end
    if global.mod.network_chest_gui ~= nil and global.mod.network_chest_gui.entity.unit_number == entity.unit_number then
      global.mod.network_chest_gui.frame.destroy()
      global.mod.network_chest_gui = nil
    end
  elseif entity.name == "network-tank" then
    GlobalState.put_tank_contents_in_network(entity)
    if not opts.do_not_delete_entity then
      GlobalState.delete_tank_entity(entity.unit_number)
    end
  elseif GlobalState.is_logistic_entity(entity.name) then
    GlobalState.logistic_del(entity.unit_number)
  elseif GlobalState.is_vehicle_entity(entity.name) then
    GlobalState.vehicle_del(entity.unit_number)
  elseif entity.name == "network-sensor" then
    GlobalState.sensor_del(entity.unit_number)
  end
end

function M.on_player_mined_entity(event)
  M.generic_destroy_handler(event)
end

function M.on_pre_player_mined_item(event)
  M.generic_destroy_handler(event)
end

function M.on_robot_mined_entity(event)
  M.generic_destroy_handler(event)
end

function M.script_raised_destroy(event)
  M.generic_destroy_handler(event)
end

function M.on_entity_died(event)
  M.generic_destroy_handler(event, { do_not_delete_entity = true })
end

function M.on_marked_for_deconstruction(event)
  if event.entity.name == "network-chest" then
    GlobalState.put_chest_contents_in_network(event.entity)
  elseif event.entity.name == "network-tank" then
    GlobalState.put_tank_contents_in_network(event.entity)
  end
end

function M.on_post_entity_died(event)
  if event.unit_number ~= nil then
    GlobalState.logistic_del(event.unit_number)

    local original_entity = GlobalState.get_chest_info(event.unit_number)
    if original_entity ~= nil then
      if event.ghost ~= nil then
        event.ghost.tags = { requests = original_entity.requests }
      end
      GlobalState.delete_chest_entity(event.unit_number)
    else
      -- it might be a tank
      local tank_info = GlobalState.get_tank_info(event.unit_number)
      if tank_info ~= nil then
        GlobalState.delete_tank_entity(event.unit_number)
        if event.ghost ~= nil then
          event.ghost.tags = { config = tank_info.config }
        end
      end
    end
  end
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
    elseif entity.name == "network-tank" then
      local real_entity = event.surface.find_entity(
        "network-tank",
        entity.position
      )
      if real_entity ~= nil then
        local tank_info = GlobalState.get_tank_info(real_entity.unit_number)
        if tank_info ~= nil and tank_info.config ~= nil then
          blueprint.set_blueprint_entity_tag(
            entity.entity_number,
            "config",
            tank_info.config
          )
        end
      end
    end
  end
end

function M.on_entity_settings_pasted(event)
end

function M.on_pre_entity_settings_pasted(event)
  local source = event.source
  local dest = event.destination
  if dest.name == "network-chest" then
    if source.name == "network-chest" then
      GlobalState.copy_chest_requests(source.unit_number, dest.unit_number)
    elseif source.type == "assembling-machine" then
      local recipe = source.get_recipe()
      if recipe ~= nil then
        local chest_info = GlobalState.get_chest_info(dest.unit_number)
        if chest_info ~= nil then
          local requests = {}
          local current_items = {}
          local buffer_size = settings.global
            ["item-network-stack-size-on-assembler-paste"].value

          -- copy existing requests
          for _, request in ipairs(chest_info.requests) do
            table.insert(requests, request)
            current_items[request.item] = true
          end

          -- add in recipe requests
          for _, product in ipairs(recipe.products) do
            if product.type == "item" and current_items[product.name] == nil then
              current_items[product.name] = true
              local stack_size = game.item_prototypes[product.name].stack_size
              local buffer = math.min(buffer_size, stack_size)
              table.insert(requests, {
                type = "give",
                item = product.name,
                buffer = buffer,
                limit = buffer,
              })
            end
          end

          GlobalState.set_chest_requests(dest.unit_number, requests)
        end
      end
    end
  elseif dest.name == "network-tank" then
    if source.name == "network-tank" then
      GlobalState.copy_tank_config(source.unit_number, dest.unit_number)
    end
  elseif source.name == "network-chest" and dest.type == "assembling-machine" then
    local recipe = dest.get_recipe()
    if recipe ~= nil then
      local chest_info = GlobalState.get_chest_info(source.unit_number)
      if chest_info ~= nil then
        local requests = {}
        local current_items = {}
        local buffer_size = settings.global
          ["item-network-stack-size-on-assembler-paste"].value

        -- copy existing requests
        for _, request in ipairs(chest_info.requests) do
          table.insert(requests, request)
          current_items[request.item] = true
        end

        -- add in recipe ingredients
        for _, ingredient in ipairs(recipe.ingredients) do
          if ingredient.type == "item" and current_items[ingredient.name] == nil then
            current_items[ingredient.name] = true
            local stack_size = game.item_prototypes[ingredient.name]
              .stack_size
            local buffer = math.min(buffer_size, stack_size)
            table.insert(requests, {
              type = "take",
              item = ingredient.name,
              buffer = buffer,
              limit = 0,
            })
          end
        end

        GlobalState.set_chest_requests(source.unit_number, requests)
      end
    end
  end
end

function M.trash_to_network(trash_inv)
  if trash_inv ~= nil then
    for name, count in pairs(trash_inv.get_contents()) do
      GlobalState.increment_item_count(name, count)
    end
    trash_inv.clear()
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
      M.trash_to_network(player.get_inventory(defines.inventory.character_trash))

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

function M.update_vehicle(entity, inv_trash, inv_trunk)
  local status = GlobalState.UPDATE_STATUS.NOT_UPDATED

  -- move trash to the item network
  M.trash_to_network(inv_trash)

  -- fulfill reqeusts
  if inv_trunk == nil or entity.request_slot_count < 1 then
    return status
  end

  local contents = inv_trunk.get_contents()
  for slot = 1, entity.request_slot_count do
    local req = entity.get_request_slot(slot)
    if req ~= nil then
      local current_count = contents[req.name] or 0
      local network_count = GlobalState.get_item_count(req.name)
      local n_wanted = math.max(0, req.count - current_count)
      local n_transfer = math.min(network_count, n_wanted)
      if n_transfer > 0 then
        local n_inserted = inv_trunk.insert { name = req.name, count = n_transfer }
        if n_inserted > 0 then
          GlobalState.set_item_count(req.name, network_count - n_inserted)
          status = GlobalState.UPDATE_STATUS.UPDATED
        end
      end
      if n_transfer < n_wanted then
        GlobalState.missing_item_set(req.name, entity.unit_number,
          n_wanted - n_transfer)
      end
    end
  end
  return status
end

function M.vehicle_update_entity(entity)
  -- only 1 logistic vehicle right now
  if entity.name ~= "spidertron" then
    return GlobalState.UPDATE_STATUS.INVALID
  end

  local status = GlobalState.UPDATE_STATUS.NOT_UPDATED
  if entity.vehicle_logistic_requests_enabled then
    GlobalState.start_timer("update_vehicle")
    status = M.update_vehicle(entity,
      entity.get_inventory(defines.inventory.spider_trash),
      entity.get_inventory(defines.inventory.spider_trunk))
    GlobalState.stop_timer("update_vehicle")
  end
  return status
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
  local status = GlobalState.UPDATE_STATUS.NOT_UPDATED

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
        status = GlobalState.UPDATE_STATUS.UPDATED
        contents[request.item] = current_count + n_transfer
        GlobalState.set_item_count(request.item, network_count - n_transfer)
      end
      -- missing if the number we wanted to take was more than available
      if n_take > n_give then
        GlobalState.missing_item_set(request.item, info.entity.unit_number,
          n_take - n_give)
      end
    else
      local n_transfer
      if request.no_limit then
        n_transfer = current_count
      else
        n_transfer = math.min(
          current_count,
          math.max(0, request.limit - network_count)
        )
      end
      if n_transfer > 0 then
        status = GlobalState.UPDATE_STATUS.UPDATED
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

  -- round n_slots if they exceed total
  local current_slots = {}
  for _, request in ipairs(requests) do
    table.insert(current_slots, request.n_slots)
  end
  local new_slots = Helpers.int_partition(current_slots, #inv)
  for idx, request in ipairs(requests) do
    request.n_slots = new_slots[idx]
  end


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

  return status
end

local function update_tank(info)
  local status = GlobalState.UPDATE_STATUS.NOT_UPDATED
  local type = info.config.type
  local limit = info.config.limit
  local no_limit = info.config.no_limit or false
  local buffer = info.config.buffer
  local fluid = info.config.fluid
  local temp = info.config.temperature

  if type == "give" then
    local fluidbox = info.entity.fluidbox
    for idx = 1, #fluidbox do
      local fluid_instance = fluidbox[idx]
      if fluid_instance ~= nil then
        local current_count = GlobalState.get_fluid_count(
          fluid_instance.name,
          fluid_instance.temperature
        )
        local n_give = math.max(0, fluid_instance.amount)
        local n_take
        if no_limit then
          n_take = fluid_instance.amount
        else
          n_take = math.max(0, limit - current_count)
        end
        local n_transfer = math.floor(math.min(n_give, n_take))
        if n_transfer > 0 then
          status = GlobalState.UPDATE_STATUS.UPDATED
          GlobalState.increment_fluid_count(fluid_instance.name,
            fluid_instance.temperature, n_transfer)
          local removed = info.entity.remove_fluid({
            name = fluid_instance.name,
            temperature = fluid_instance.temperature,
            amount = n_transfer,
          })
          assert(removed == n_transfer)
        end
      end
    end
  else
    local fluidbox = info.entity.fluidbox
    local tank_fluid = nil
    local tank_temp = nil
    local tank_count = 0
    local n_fluid_boxes = 0
    for idx = 1, #fluidbox do
      local fluid_instance = fluidbox[idx]
      if fluid_instance ~= nil then
        n_fluid_boxes = n_fluid_boxes + 1
        tank_fluid = fluid_instance.name
        tank_temp = fluid_instance.temperature
        tank_count = fluid_instance.amount
      end
    end

    if n_fluid_boxes == 0 or (n_fluid_boxes == 1 and tank_fluid == fluid and tank_temp == temp) then
      local network_count = GlobalState.get_fluid_count(
        fluid,
        temp
      )
      local n_give = math.max(0, network_count - limit)
      local n_take = math.max(0, buffer - tank_count)
      local n_transfer = math.floor(math.min(n_give, n_take))
      if n_transfer > 0 then
        status = GlobalState.UPDATE_STATUS.UPDATED
        GlobalState.increment_fluid_count(fluid, temp, -n_transfer)
        local added = info.entity.insert_fluid({
          name = fluid,
          amount = n_transfer,
          temperature = temp,
        })
        assert(added == n_transfer)
      end
      if n_take > n_give then
        GlobalState.missing_fluid_set(fluid, temp, info.entity.unit_number,
          n_take - n_give)
      end
    end
  end

  return status
end

local function update_chest_entity(unit_number, info)
  local entity = info.entity
  if not entity.valid then
    return GlobalState.UPDATE_STATUS.INVALID
  end

  if entity.to_be_deconstructed() then
    return GlobalState.UPDATE_STATUS.NOT_UPDATED
  end

  GlobalState.start_timer("update_network_chest")
  result = update_network_chest(info)
  GlobalState.stop_timer("update_network_chest")
  return result
end

local function update_tank_entity(unit_number, info)
  local entity = info.entity
  if not entity.valid then
    return GlobalState.UPDATE_STATUS.INVALID
  end

  if info.config == nil or entity.to_be_deconstructed() then
    return GlobalState.UPDATE_STATUS.NOT_UPDATED
  end

  GlobalState.start_timer("update_tank")
  result = update_tank(info)
  GlobalState.stop_timer("update_tank")
end

local function update_entity(unit_number)
  local info
  info = GlobalState.get_chest_info(unit_number)
  if info ~= nil then
    return update_chest_entity(unit_number, info)
  end

  info = GlobalState.get_tank_info(unit_number)
  if info ~= nil then
    return update_tank_entity(unit_number, info)
  end

  local entity = GlobalState.get_logistic_entity(unit_number)
  if entity ~= nil then
    return M.logistic_update_entity(entity)
  end

  entity = GlobalState.get_vehicle_entity(unit_number)
  if entity ~= nil then
    return M.vehicle_update_entity(entity)
  end

  return GlobalState.UPDATE_STATUS.INVALID
end

function M.update_queue()
  GlobalState.update_queue(update_entity)
end

function M.logistic_update_entity(entity)
  if not settings.global["item-network-enable-logistic-chest"].value then
    return GlobalState.UPDATE_STATUS.NOT_UPDATED
  end

  GlobalState.start_timer("logistic_update_entity")

  -- sanity check
  if not entity.valid then
    return GlobalState.UPDATE_STATUS.INVALID
  end

  -- don't add stuff to a doomed chest
  if entity.to_be_deconstructed() then
    return GlobalState.UPDATE_STATUS.NOT_UPDATED
  end

  local status = GlobalState.UPDATE_STATUS.NOT_UPDATED

  -- need a request to do anything
  if entity.request_slot_count > 0 then
    local inv = entity.get_output_inventory()
    local contents = inv.get_contents()

    for slot = 1, entity.request_slot_count do
      local req = entity.get_request_slot(slot)
      if req ~= nil then
        local current_count = contents[req.name] or 0
        local network_count = GlobalState.get_item_count(req.name)
        local n_wanted = math.max(0, req.count - current_count)
        local n_transfer = math.min(network_count, n_wanted)
        if n_transfer > 0 then
          local n_inserted = inv.insert { name = req.name, count = n_transfer }
          if n_inserted > 0 then
            GlobalState.set_item_count(req.name, network_count - n_inserted)
            status = GlobalState.UPDATE_STATUS.UPDATED
          end
        end
        if n_transfer < n_wanted then
          GlobalState.missing_item_set(req.name, entity.unit_number,
            n_wanted - n_transfer)
        end
      end
    end
  end

  GlobalState.stop_timer("logistic_update_entity")

  return status
end

function M.onTick()
  GlobalState.start_timer("GlobalState.setup")
  GlobalState.setup()
  GlobalState.stop_timer("GlobalState.setup")

  GlobalState.start_timer("update_queue")
  M.update_queue()
  GlobalState.stop_timer("update_queue")
end

function M.onTick_60()
  GlobalState.start_timer("updatePlayers")
  M.updatePlayers()
  GlobalState.stop_timer("updatePlayers")

  GlobalState.start_timer("check_alerts")
  M.check_alerts()
  GlobalState.stop_timer("check_alerts")
end

function M.handle_missing_material(entity, missing_name, item_count)
  item_count = item_count or 1
  -- a cliff doesn't have a unit_number, so fake one based on the position
  local key = entity.unit_number
  if key == nil then
    key = string.format("%s,%s", entity.position.x, entity.position.y)
  end

  -- did we already transfer something for this ghost/upgrade?
  if GlobalState.alert_transfer_get(key) == true then
    return
  end

  -- make sure it is something we can handle
  local name, count = GlobalState.resolve_name(missing_name)
  if name == nil then
    return
  end
  count = count or item_count

  -- do we have an item to send?
  local network_count = GlobalState.get_item_count(name)
  if network_count < count then
    GlobalState.missing_item_set(name, key, count)
    return
  end

  -- Find a construction network with a construction robot that covers this position
  local nets = entity.surface.find_logistic_networks_by_construction_area(
    entity.position, "player")
  for _, net in ipairs(nets) do
    if net.all_construction_robots > 0 then
      local n_inserted = net.insert({ name = name, count = count })
      if n_inserted > 0 then
        GlobalState.increment_item_count(name, -n_inserted)
        GlobalState.alert_transfer_set(key)
        return
      end
    end
  end
end

function M.check_alerts()
  GlobalState.alert_transfer_cleanup()

  if not settings.global["item-network-enable-logistic-chest"].value then
    return
  end

  -- process all the alerts for all players
  for _, player in pairs(game.players) do
    local alerts = player.get_alerts {
      type = defines.alert_type.no_material_for_construction }
    for _, xxx in pairs(alerts) do
      for _, alert_array in pairs(xxx) do
        for _, alert in ipairs(alert_array) do
          if alert.target ~= nil then
            local entity = alert.target
            -- we only care about ghosts and items that are set to upgrade
            if entity.name == "entity-ghost" or entity.name == "tile-ghost" then
              M.handle_missing_material(entity, entity.ghost_name)
            elseif entity.name == "cliff" then
              M.handle_missing_material(entity, "cliff-explosives")
            elseif entity.name == "item-request-proxy" then
              for k, v in pairs(entity.item_requests) do
                M.handle_missing_material(entity, k, v)
              end
            else
              local tent = entity.get_upgrade_target()
              if tent ~= nil then
                M.handle_missing_material(entity, tent.name)
              end
            end
          end
        end
      end
    end
  end

  -- send repair packs
  for _, player in pairs(game.players) do
    local alerts = player.get_alerts {
      type = defines.alert_type.not_enough_repair_packs }
    for _, xxx in pairs(alerts) do
      for _, alert_array in pairs(xxx) do
        for _, alert in ipairs(alert_array) do
          if alert.target ~= nil then
            M.handle_missing_material(alert.target, "repair-pack")
          end
        end
      end
    end
  end
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

function M.on_gui_selected_tab_changed(event)
  UiHandlers.handle_generic_gui_event(event, "on_gui_selected_tab_changed")
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
  elseif event.gui_type == defines.gui_type.entity and event.entity.name == "network-loader" then
    local entity = event.entity
    local player = game.get_player(event.player_index)
    if player == nil then
      return
    end

    NetworkLoaderUi.on_gui_opened(player, entity)
  end
end

function M.on_gui_closed(event)
  local frame = event.element
  if frame ~= nil and frame.name == UiConstants.NV_FRAME then
    NetworkViewUi.on_gui_closed(event)
  elseif frame ~= nil and frame.name == UiConstants.NT_MAIN_FRAME then
    NetworkTankGui.on_gui_closed(event)
  elseif frame ~= nil and (frame.name == UiConstants.MAIN_FRAME_NAME or frame.name == UiConstants.MODAL_FRAME_NAME) then
    NetworkChestGui.on_gui_closed(event)
  elseif frame ~= nil and frame.name == UiConstants.NL_MAIN_FRAME then
    NetworkLoaderUi.on_gui_closed(event)
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

-- want a consistent sort order (sort by signal.type and then signal.name)
local function compare_params(left, right)
  if left.signal.type ~= right.signal.type then
    return left.signal.type < right.signal.type
  end
  return left.signal.name < right.signal.name
end

function M.get_parameters()
  local params = {}
  for item, count in pairs(GlobalState.get_items()) do
    table.insert(params, {
      signal = { type = "item", name = item },
      count = count,
    })
  end
  -- have to set the index after sorting
  table.sort(params, compare_params)
  for index, param in ipairs(params) do
    param.index = index
  end
  return params
end

function M.service_sensors()
  local params
  -- all sensors get the same parameters
  for _, entity in pairs(GlobalState.sensor_get_list()) do
    GlobalState.start_timer("sensor_update")
    if entity.valid then
      local cb = entity.get_control_behavior()
      if cb ~= nil then
        if params == nil then
          params = M.get_parameters()
        end
        cb.parameters = params
      end
    end
    GlobalState.stop_timer("sensor_update")
  end
end

return M
