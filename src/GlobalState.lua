local Priority = require "src.Priority"
local Heap = require "src.Heap"
local Timer = require "src.Timer"
local Queue = require "src.Queue"
local Helpers = require "src.Helpers"
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
  if global.mod.missing_items == nil then
    global.mod.missing_items = {} -- missing_items[item][unit_number] = { game.tick, count }
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

  if global.mod.sensors == nil then
    global.mod.sensors = {}
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

  if global.mod.active_scan_queue == nil then
    global.mod.active_scan_queue = Queue.new()
  end

  if not global.mod.has_run_fluid_temp_rounding_conversion then
    local new_fluids = {}
    for fluid, temp_map in pairs(global.mod.fluids) do
      local new_temp_map = {}
      new_fluids[fluid] = new_temp_map
      for temp, count in pairs(temp_map) do
        local new_temp = math.ceil(temp)
        local existing_count = new_temp_map[new_temp] or 0
        new_temp_map[new_temp] = existing_count + count
      end
    end
    global.mod.fluids = new_fluids
    global.mod.has_run_fluid_temp_rounding_conversion = true
  end

  -- always reset timers on load since they don't save state
  global.mod.timers = {}

  if global.mod.update_queue == nil then
    -- A priority queue sorted by update time
    -- that stores an entity id to update.
    global.mod.update_queue = Heap.new()

    -- A map from item name -> info about the item
    global.mod.items = {}

    -- A map from fluid name to
    --   a map from temp to info about the fluid x temp
    global.mod.fluids = {}

    -- A map from entity ID to info about the entity.
    global.mod.entities = {}
  end

  for _, info in pairs(global.mod.items) do
    if info.max_amount == nil then
      info.max_amount = info.amount
    end
  end
  for _, temp_map in pairs(global.mod.fluids) do
    for _, info in pairs(temp_map) do
      if info.max_amount == nil then
        info.max_amount = info.amount
      end
    end
  end
  for _, entity in pairs(global.mod.entities) do
    if entity.type == "network-chest" or entity.type == "medium-network-chest" or entity.type == "large-network-chest" then
      for _, request in ipairs(entity.config.requests) do
        if request.priority == nil then
          if request.type == "provide" and request.no_limit then
            request.priority = Priority.HIGH
          else
            request.priority = Priority.DEFAULT
          end
          request.no_limit = nil
        end
      end
    elseif entity.type == "network-tank" or entity.type == "medium-network-tank" or entity.type == "large-network-tank" then
      if entity.config.priority == nil then
        if entity.config.type == "provide" and entity.config.no_limit then
          entity.config.priority = Priority.HIGH
        else
          entity.config.priority = Priority.DEFAULT
        end
        entity.config.no_limit = nil
      end
    else
      error(entity.type)
    end
  end
end

function M.start_timer(name)
  local timer = global.mod.timers[name]
  if timer == nil then
    timer = Timer.new()
    global.mod.timers[name] = timer
  end
  Timer.start(timer)
end

function M.stop_timer(name)
  local timer = global.mod.timers[name]
  if timer ~= nil then
    Timer.stop(timer)
  end
end

local function sort_timers(left, right)
  return left.timer.count > right.timer.count
end

function M.get_timers()
  local result = {}
  for timer_name, timer in pairs(global.mod.timers) do
    table.insert(result, { name = timer_name, timer = timer })
  end
  table.sort(result, sort_timers)
  return result
end

-- store the missing item: mtab[item_name][unit_number] = { game.tick, count }
local function set_missing(miss_tbl, item_name, unit_number, count)
  local tt = miss_tbl[item_name]
  if tt == nil then
    tt = {}
    miss_tbl[item_name] = tt
  end
  tt[unit_number] = { tick = game.tick, count = count }
end

-- filter the missing table and return: missing[item] = count
local function get_missing_and_filter(miss_tbl)
  local deadline = game.tick - constants.MAX_MISSING_TICKS
  local missing = {}
  local to_del = {}
  for name, xx in pairs(miss_tbl) do
    for unit_number, ii in pairs(xx) do
      local tick = ii.tick
      local count = ii.count
      if tick < deadline then
        table.insert(to_del, { name = name, unit_number = unit_number })
      else
        missing[name] = (missing[name] or 0) + count
      end
    end
  end
  for _, del_info in ipairs(to_del) do
    local name = del_info.name
    local unit_number = del_info.unit_number
    miss_tbl[name][unit_number] = nil
    if next(miss_tbl[name]) == nil then
      miss_tbl[name] = nil
    end
  end
  return missing
end

-- mark an item as missing
function M.missing_item_set(item_name, unit_number, count)
  set_missing(global.mod.missing_items, item_name, unit_number, count)
end

-- drop any items that have not been missing for a while
-- returns the (read-only) table of missing items
function M.get_missing_items()
  return get_missing_and_filter(global.mod.missing_items)
end

-- create a string 'key' for a fluid@temp
function M.encode_fluid_key(fluid_name, temp)
  return string.format("%s@%d", fluid_name, math.floor(temp * 1000))
end

-- split the key back into the fluid and temp
function M.decode_fluid_key(key)
  local idx = string.find(key, "@")
  if idx ~= nil then
    return string.sub(key, 1, idx - 1), tonumber(string.sub(key, idx + 1)) / 1000
  end
  error("unreachable")
end

-- mark a fluid/temp combo as missing
function M.missing_fluid_set(name, temp, unit_number, count)
  local key = M.encode_fluid_key(name, temp)
  set_missing(global.mod.missing_fluid, key, unit_number, count)
end

-- drop any fluids that have not been missing for a while
-- returns the (read-only) table of missing items
function M.missing_fluid_filter()
  return get_missing_and_filter(global.mod.missing_fluid)
end

function M.remove_old_ui()
  if global.mod.network_chest_gui ~= nil then
    global.mod.network_chest_gui = nil
    for _, player in pairs(game.players) do
      local main_frame = player.gui.screen["network-chest-main-frame"]
      if main_frame ~= nil then
        main_frame.destroy()
      end

      main_frame = player.gui.screen["add-request"]
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

function M.sensor_add(entity)
  global.mod.sensors[entity.unit_number] = entity
end

function M.sensor_del(unit_number)
  global.mod.sensors[unit_number] = nil
end

function M.sensor_get_list()
  return global.mod.sensors
end

function M.get_updates_per_tick()
  return 20
end

function M.get_update_period()
  return math.ceil(global.mod.update_queue.size / M.get_updates_per_tick())
end

function M.get_default_update_period()
  return math.max(constants.MIN_UPDATE_TICKS, 8 * M.get_update_period())
end

function M.register_entity(entity_id, info)
  if global.mod.entities[entity_id] ~= nil then
    return
  end

  global.mod.entities[entity_id] = info
end

function M.unregister_entity(entity_id)
  global.mod.entities[entity_id] = nil
end

function M.register_chest_entity(entity, requests)
  if requests == nil then
    requests = {}
  end

  local info = {
    entity = entity,
    requests = requests,
  }

  M.register_entity(entity.unit_number, info)
  global.mod.network_chest_has_been_placed = true
end

function M.get_item_info(item)
  local info = global.mod.items[item]
  if info == nil then
    info = {
      amount = 0,
      deposit_limit = 1,
      max_amount = 0,
    }
    global.mod.items[item] = info
  end
  return info
end

function M.deposit_item2(item, amount, priority)
  local info = M.get_item_info(item)
  return M.deposit_material2(info, amount, priority)
end

function M.deposit_material2(info, amount, priority)
  assert(priority ~= nil)
  amount = math.floor(amount)
  amount = math.max(0, amount)
  if priority == Priority.DEFAULT then
    local max_amount = math.max(0, info.deposit_limit - info.amount)
    amount = math.min(amount, max_amount)
  elseif priority == Priority.LOW then
    local deposit_limit = math.floor(0.2 * info.deposit_limit)
    deposit_limit = math.max(1, deposit_limit)
    local max_amount = math.max(0, deposit_limit - info.amount)
    amount = math.min(amount, max_amount)
  end

  if amount == 0 then
    return 0
  end

  info.amount = info.amount + amount

  if info.amount >= info.deposit_limit then
    info.last_full_tick = game.tick
  end

  return amount
end

function M.withdraw_material2(info, amount, priority)
  assert(priority ~= nil)
  amount = math.floor(amount)
  amount = math.max(0, amount)
  local default_limit = math.floor(0.2 * info.deposit_limit)
  local max_amount = info.amount
  if priority == Priority.DEFAULT then
    max_amount = math.max(0, info.amount - default_limit)
  elseif priority == Priority.LOW then
    max_amount = math.max(0, info.amount - info.deposit_limit)
  end

  amount = math.min(amount, max_amount)

  if amount == 0 then
    return 0
  end

  info.amount = info.amount - amount

  if info.amount <= default_limit and info.last_full_tick ~= nil then
    if game.tick - info.last_full_tick < 60 * 10 then
      local next_limit = math.ceil(1.5 * (1 + info.deposit_limit))
      info.deposit_limit = next_limit
    end
    info.last_full_tick = nil
  end

  return amount
end

function M.withdraw_item2(item, amount, priority)
  local info = M.get_item_info(item)
  return M.withdraw_material2(info, amount, priority)
end

function M.get_fluid_info(fluid_name, fluid_temp)
  if global.mod.fluids[fluid_name] == nil then
    global.mod.fluids[fluid_name] = {}
  end
  if global.mod.fluids[fluid_name][fluid_temp] == nil then
    global.mod.fluids[fluid_name][fluid_temp] = {
      amount = 0,
      deposit_limit = 1,
      max_amount = 0,
    }
  end
  local info = global.mod.fluids[fluid_name][fluid_temp]
  return info
end

function M.deposit_fluid2(fluid_name, fluid_temp, amount, priority)
  local info = M.get_fluid_info(fluid_name, fluid_temp)
  return M.deposit_material2(info, amount, priority)
end

function M.withdraw_fluid2(fluid_name, fluid_temp, amount, priority)
  local info = M.get_fluid_info(fluid_name, fluid_temp)
  return M.withdraw_material2(info, amount, priority)
end

function M.get_fluid_temps(fluid_name)
  local function sort_fluids(left, right)
    return left.order < right.order
  end

  local temp_pairs = {}
  local temp_map = global.mod.fluids[fluid_name]
  if temp_map ~= nil then
    for temp, info in pairs(temp_map) do
      if info.max_amount > 0 then
        table.insert(temp_pairs, { temp = temp, order = -info.deposit_limit })
      end
    end
  end
  table.sort(temp_pairs, sort_fluids)

  local temps = {}
  for _, pair in ipairs(temp_pairs) do
    table.insert(temps, pair.temp)
  end

  return temps
end

function M.put_chest_contents_in_network(entity)
  local inv = entity.get_output_inventory()
  M.deposit_inv_contents(inv)
end

function M.deposit_inv_contents(inv)
  if inv ~= nil then
    local contents = inv.get_contents()
    for item, count in pairs(contents) do
      M.deposit_item2(item, count, Priority.HIGH)
    end
    inv.clear()
  end
end

function M.get_entity_info(entity_id)
  return global.mod.entities[entity_id]
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
    if fluid ~= nil and fluid.name ~= nil and fluid.temperature ~= nil and fluid.amount ~= nil then
      M.deposit_fluid2(
        fluid.name,
        fluid.temperature,
        fluid.amount,
        Priority.HIGH
      )
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

function M.copy_entity_config(source_id, dest_id)
  local source_config = global.mod.entities[source_id].config
  local dest_config = Helpers.deep_copy(source_config)
  global.mod.entities[dest_id].config = dest_config
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
  temp = math.ceil(temp)
  local fluid_temps = global.mod.fluids[fluid_name]
  if fluid_temps == nil then
    return 0
  end
  return fluid_temps[temp].amount or 0
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
  temp = math.ceil(temp)
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

function M.get_window_state(player_index, window_name)
  local info = M.get_player_info(player_index)
  if info.window_states == nil then
    info.window_states = {}
  end
  if info.window_states[window_name] == nil then
    info.window_states[window_name] = {}
  end
  return info.window_states[window_name]
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

function M.get_queue_counts(
  n_active,
  n_inactive,
  n_entities,
  active_weight
)
  local total_entities = n_active + n_inactive
  if total_entities < n_entities then
    return { active = n_active, inactive = n_inactive }
  end
  n_entities = math.min(n_entities, total_entities)
  n_entities = math.max(n_entities, 2)
  local n_active_update = math.floor(
    0.5 + n_entities * active_weight / (active_weight + 1)
  )
  n_active_update = math.min(n_active_update, n_active)
  local n_inactive_update = n_entities - n_active_update

  if n_active_update < 1 then
    n_active_update = math.min(1, n_active)
    n_inactive_update = math.max(1, n_entities - n_active_update)
  elseif n_inactive_update < 1 then
    n_inactive_update = math.min(1, n_inactive)
    n_active_update = math.max(1, n_entities - n_inactive_update)
  end

  if n_active_update > n_active then
    n_active_update = n_active
    n_inactive_update = n_entities - n_active
  elseif n_inactive_update > n_inactive then
    n_inactive_update = n_inactive
    n_active_update = n_entities - n_inactive
  end

  return { active = n_active_update, inactive = n_inactive_update }
end

function M.update_queue(update_entity)
  local MAX_ENTITIES_TO_UPDATE = settings.global
    ["item-network-number-of-entities-per-tick"]
    .value
  local updated_entities = {}

  local function inner_update_entity(unit_number)
    if updated_entities[unit_number] ~= nil then
      return M.UPDATE_STATUS.ALREADY_UPDATED
    end
    updated_entities[unit_number] = true

    return update_entity(unit_number)
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

-- translate a tile name to the item name ("stone-path" => "stone-brick")
function M.resolve_name(name)
  if game.item_prototypes[name] ~= nil or game.fluid_prototypes[name] ~= nil then
    return name
  end

  local prot = game.tile_prototypes[name]
  if prot ~= nil then
    local mp = prot.mineable_properties
    if mp.minable and #mp.products == 1 then
      return mp.products[1].name
    end
  end

  -- FIXME: figure out how to not hard-code this
  if name == "curved-rail" then
    return "rail", 4
  end
  if name == "straight-rail" then
    return "rail", 1
  end

  return nil
end

function M.get_entities_to_update_on_tick(tick)
  local result = {}
  while global.mod.update_queue.size > 0 and #result < 20 do
    table.insert(result, Heap.peek(global.mod.update_queue))
    Heap.pop(global.mod.update_queue)
  end
  return result
end

return M
