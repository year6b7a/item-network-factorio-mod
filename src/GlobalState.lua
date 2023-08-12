local Queue = require "src.Queue"
local tables_have_same_keys = require("src.tables_have_same_keys")
  .tables_have_same_keys
local constants = require "src.constants"

local M = {}

local setup_has_run = false

function M.setup()
  if setup_has_run then
    return
  end
  setup_has_run = true

  M.inner_setup()
end

function M.inner_setup()
  if global.mod == nil then
    global.mod = {
      rand = game.create_random_generator(),
      chests = {},
      scan_queue = Queue.new(),
      items = {},
    }
  end
  M.remove_old_ui()
  if global.mod.player_info == nil then
    global.mod.player_info = {}
  end

  if global.mod.network_chest_has_been_placed == nil then
    global.mod.network_chest_has_been_placed = global.mod.scan_queue.size > 0
  end

  if global.mod.fluids == nil then
    global.mod.fluids = {}
  end
  if global.mod.missing_item == nil then
    global.mod.missing_item = {} -- missing_item[item][unit_number] = { game.tick, count }
  end
  if global.mod.missing_fluid == nil then
    global.mod.missing_fluid = {} -- missing_fluid[key][unit_number] = { game.tick, count }
  end
  if global.mod.tanks == nil then
    global.mod.tanks = {}
  end

  if global.mod.vehicles == nil then
    global.mod.vehicles = {} -- vehicles[unit_number] = entity
    M.vehicle_scan_surfaces()
  end

  if global.mod.logistic == nil then
    global.mod.logistic = {} -- key=unit_number, val=entity
  end
  if global.mod.logistic_names == nil then
    global.mod.logistic_names = {} -- key=item name, val=logistic_mode from prototype
  end
  local logistic_names = M.logistic_scan_prototypes()
  if not tables_have_same_keys(logistic_names, global.mod.logistic_names) then
    global.mod.logistic_names = logistic_names
    global.mod.logistic = {}
    M.logistic_scan_surfaces()
  end

  if global.mod.alert_trans == nil then
    global.mod.alert_trans = {} -- alert_trans[unit_number] = game.tick
  end

  if not global.mod.has_run_fluid_temp_conversion then
    local new_fluids = {}
    for fluid, count in pairs(global.mod.fluids) do
      local default_temp = game.fluid_prototypes[fluid].default_temperature
      new_fluids[fluid] = {}
      new_fluids[fluid][default_temp] = count
    end
    global.mod.fluids = new_fluids
    local n_tanks = 0
    for _, entity in pairs(global.mod.tanks) do
      n_tanks = n_tanks + 1
      if entity.config ~= nil then
        entity.config.temperature =
          game.fluid_prototypes[entity.config.fluid].default_temperature
      end
    end
    if n_tanks > 0 then
      game.print(
        "Migrated Item Network fluids to include temperatures. Warning: If you provide a fluid at a non-default temperature (like steam), you will have to update every requester tank to use the new fluid temperature.")
    end
    global.mod.has_run_fluid_temp_conversion = true
  end
end

-- store the missing item: mtab[item_name][unit_number] = { game.tick, count }
local function missing_set(mtab, item_name, unit_number, count)
  local tt = mtab[item_name]
  if tt == nil then
    tt = {}
    mtab[item_name] = tt
  end
  tt[unit_number] = { game.tick, count }
end

-- filter the missing table and return: missing[item] = count
local function missing_filter(tab)
  local deadline = game.tick - constants.MAX_MISSING_TICKS
  local missing = {}
  local to_del = {}
  for name, xx in pairs(tab) do
    for unit_number, ii in pairs(xx) do
      local tick = ii[1]
      local count = ii[2]
      if tick < deadline then
        table.insert(to_del, { name, unit_number })
      else
        missing[name] = (missing[name] or 0) + count
      end
    end
  end
  for _, ii in ipairs(to_del) do
    local name = ii[1]
    local unum = ii[2]
    tab[name][unum] = nil
    if next(tab[name]) == nil then
      tab[name] = nil
    end
  end
  return missing
end

-- mark an item as missing
function M.missing_item_set(item_name, unit_number, count)
  missing_set(global.mod.missing_item, item_name, unit_number, count)
end

-- drop any items that have not been missing for a while
-- returns the (read-only) table of missing items
function M.missing_item_filter()
  return missing_filter(global.mod.missing_item)
end

-- create a string 'key' for a fluid@temp
function M.fluid_temp_key_encode(fluid_name, temp)
  return string.format("%s@%d", fluid_name, math.floor(temp * 1000))
end

-- split the key back into the fluid and temp
function M.fluid_temp_key_decode(key)
  local idx = string.find(key, "@")
  if idx ~= nil then
    return string.sub(key, 1, idx - 1), tonumber(string.sub(key, idx + 1)) / 1000
  end
  return nil, nil
end

-- mark a fluid/temp combo as missing
function M.missing_fluid_set(name, temp, unit_number, count)
  local key = M.fluid_temp_key_encode(name, temp)
  missing_set(global.mod.missing_fluid, key, unit_number, count)
end

-- drop any fluids that have not been missing for a while
-- returns the (read-only) table of missing items
function M.missing_fluid_filter()
  return missing_filter(global.mod.missing_fluid)
end

function M.remove_old_ui()
  if global.mod.network_chest_gui ~= nil then
    global.mod.network_chest_gui = nil
    for _, player in pairs(game.players) do
      local main_frame = player.gui.screen["network-chest-main-frame"]
      if main_frame ~= nil then
        main_frame.destroy()
      end

      local main_frame = player.gui.screen["add-request"]
      if main_frame ~= nil then
        main_frame.destroy()
      end
    end
  end
end

-- this tracks that we already transferred an item for the request
function M.alert_transfer_set(unit_number)
  global.mod.alert_trans[unit_number] = game.tick
end

-- get whether we have already transferred for this alert
-- the item won't necessarily go where we want it
function M.alert_transfer_get(unit_number)
  return global.mod.alert_trans[unit_number] ~= nil
end

-- throw out stale entries, allowing another transfer
function M.alert_transfer_cleanup()
  local deadline = game.tick - constants.ALERT_TRANSFER_TICKS
  local to_del = {}
  for unum, tick in pairs(global.mod.alert_trans) do
    if tick < deadline then
      table.insert(to_del, unum)
    end
  end
  for _, unum in ipairs(to_del) do
    global.mod.alert_trans[unum] = nil
  end
end

function M.rand_hex(len)
  local chars = {}
  for _ = 1, len do
    table.insert(chars, string.format("%x", math.floor(global.mod.rand() * 16)))
  end
  return table.concat(chars, "")
end

function M.shuffle(list)
  for i = #list, 2, -1 do
    local j = global.mod.rand(i)
    list[i], list[j] = list[j], list[i]
  end
end

-- get a table of all logistic item names that we should supply
-- called once at each startup to see if the chest list changed
function M.logistic_scan_prototypes()
  local info = {} -- key=name, val=logistic_mode
  -- find all with type="logistic-container" and (logistic_mode="requester" or logistic_mode="buffer")
  for name, prot in pairs(game.get_filtered_entity_prototypes { {
    filter = "type",
    type = "logistic-container",
  } }) do
    if prot.logistic_mode == "requester" or prot.logistic_mode == "buffer" then
      info[name] = prot.logistic_mode
    end
  end
  return info
end

function M.is_logistic_entity(item_name)
  return global.mod.logistic_names[item_name] ~= nil
end

-- called once at startup if the logistc entity prototype list changed
function M.logistic_scan_surfaces()
  local name_filter = {}
  for name, _ in pairs(global.mod.logistic_names) do
    table.insert(name_filter, name)
  end
  for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered { name = name_filter }
    for _, ent in ipairs(entities) do
      M.logistic_add_entity(ent)
    end
  end
end

function M.get_logistic_entity(unit_number)
  return global.mod.logistic[unit_number]
end

function M.logistic_add_entity(entity)
  if global.mod.logistic[entity.unit_number] == nil then
    global.mod.logistic[entity.unit_number] = entity
    Queue.push(global.mod.scan_queue, entity.unit_number)
  end
end

function M.logistic_del(unit_number)
  global.mod.logistic[unit_number] = nil
end

function M.is_vehicle_entity(name)
  return name == "spidertron"
end

function M.vehicle_scan_surfaces()
  for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered { name = "spidertron" }
    for _, entity in ipairs(entities) do
      M.vehicle_add_entity(entity)
    end
  end
end

function M.get_vehicle_entity(unit_number)
  return global.mod.vehicles[unit_number]
end

-- add a vehicle, assume the caller knows what he is doing
function M.vehicle_add_entity(entity)
  if global.mod.vehicles[entity.unit_number] == nil then
    global.mod.vehicles[entity.unit_number] = entity
    Queue.push(global.mod.scan_queue, entity.unit_number)
  end
end

function M.vehicle_del(unit_number)
  global.mod.vehicles[unit_number] = nil
end

function M.register_chest_entity(entity, requests)
  if requests == nil then
    requests = {}
  end

  if global.mod.chests[entity.unit_number] ~= nil then
    return
  end

  Queue.push(global.mod.scan_queue, entity.unit_number)
  global.mod.chests[entity.unit_number] = {
    entity = entity,
    requests = requests,
  }

  global.mod.network_chest_has_been_placed = true
end

function M.delete_chest_entity(unit_number)
  global.mod.chests[unit_number] = nil
end

function M.put_chest_contents_in_network(entity)
  local inv = entity.get_output_inventory()

  if inv ~= nil then
    local contents = inv.get_contents()
    for item, count in pairs(contents) do
      M.increment_item_count(item, count)
    end
    inv.clear()
  end
end

function M.register_tank_entity(entity, config)
  if global.mod.tanks[entity.unit_number] ~= nil then
    return
  end

  Queue.push(global.mod.scan_queue, entity.unit_number)
  global.mod.tanks[entity.unit_number] = {
    entity = entity,
    config = config,
  }
end

function M.delete_tank_entity(unit_number)
  global.mod.tanks[unit_number] = nil
end

function M.put_tank_contents_in_network(entity)
  local fluidbox = entity.fluidbox
  for idx = 1, #fluidbox do
    local fluid = fluidbox[idx]
    if fluid ~= nil then
      M.increment_fluid_count(fluid.name, fluid.temperature, fluid.amount)
    end
  end
  entity.clear_fluid_inside()
end

function M.get_chest_info(unit_number)
  return global.mod.chests[unit_number]
end

function M.get_tank_info(unit_number)
  return global.mod.tanks[unit_number]
end

function M.copy_chest_requests(source_unit_number, dest_unit_number)
  global.mod.chests[dest_unit_number].requests =
    global.mod.chests[source_unit_number].requests
end

function M.copy_tank_config(source_unit_number, dest_unit_number)
  global.mod.tanks[dest_unit_number].config =
    global.mod.tanks[source_unit_number].config
end

function M.set_chest_requests(unit_number, requests)
  local info = M.get_chest_info(unit_number)
  if info == nil then
    return
  end
  global.mod.chests[unit_number].requests = requests
end

function M.get_item_count(item_name)
  return global.mod.items[item_name] or 0
end

function M.get_fluid_count(fluid_name, temp)
  local fluid_temps = global.mod.fluids[fluid_name]
  if fluid_temps == nil then
    return 0
  end
  return fluid_temps[temp] or 0
end

function M.get_items()
  return global.mod.items
end

function M.get_fluids()
  return global.mod.fluids
end

function M.set_item_count(item_name, count)
  if count <= 0 then
    global.mod.items[item_name] = nil
  else
    global.mod.items[item_name] = count
  end
end

function M.set_fluid_count(fluid_name, temp, count)
  if count <= 0 then
    global.mod.fluids[fluid_name][temp] = nil
  else
    local fluid_temps = global.mod.fluids[fluid_name]
    if fluid_temps == nil then
      fluid_temps = {}
      global.mod.fluids[fluid_name] = fluid_temps
    end
    fluid_temps[temp] = count
  end
end

function M.increment_fluid_count(fluid_name, temp, delta)
  local count = M.get_fluid_count(fluid_name, temp)
  M.set_fluid_count(fluid_name, temp, count + delta)
end

function M.increment_item_count(item_name, delta)
  local count = M.get_item_count(item_name)
  global.mod.items[item_name] = count + delta
end

function M.get_scan_queue_size()
  return global.mod.scan_queue.size
end

function M.scan_queue_pop()
  return Queue.pop_random(global.mod.scan_queue, global.mod.rand)
end

function M.scan_queue_push(unit_number)
  Queue.push(global.mod.scan_queue, unit_number)
end

function M.get_player_info(player_index)
  local info = global.mod.player_info[player_index]
  if info == nil then
    info = {}
    global.mod.player_info[player_index] = info
  end
  return info
end

function M.get_player_info_map()
  return global.mod.player_info
end

function M.get_ui_state(player_index)
  local info = M.get_player_info(player_index)
  if info.ui == nil then
    info.ui = {}
  end
  return info.ui
end

M.UPDATE_STATUS = {
  INVALID = 0,
  UPDATED = 1,
  NOT_UPDATED = 2,
  ALREADY_UPDATED = 3,
}

function M.update_queue(update_entity)
  local MAX_ENTITIES_TO_UPDATE = 20
  local updated_entities = {}

  local function inner_update_entity(unit_number)
    if updated_entities[unit_number] ~= nil then
      return M.UPDATE_STATUS.ALREADY_UPDATED
    end
    updated_entities[unit_number] = true

    status = update_entity(unit_number)
    return status
  end

  for _ = 1, MAX_ENTITIES_TO_UPDATE do
    local unit_number = Queue.pop(global.mod.scan_queue)
    if unit_number == nil then
      break
    end

    local status = inner_update_entity(unit_number)
    if status == M.UPDATE_STATUS.NOT_UPDATED or status == M.UPDATE_STATUS.UPDATED or status == M.UPDATE_STATUS.ALREADY_UPDATED then
      Queue.push(global.mod.scan_queue, unit_number)
    end
  end

  -- finally, swap a random entity to the front of the queue to introduce randomness in update order.
  Queue.swap_random_to_front(global.mod.scan_queue, global.mod.rand)
end

return M
