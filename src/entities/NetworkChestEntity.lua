local Priority = require "src.Priority"
local GlobalState = require "src.GlobalState"
local Helpers = require "src.Helpers"
local constants = require "src.constants"

local M = {}

M.entity_name = "network-chest"

function M.on_create_entity(state)
  if state.config == nil then
    state.config = { requests = {}, has_been_updated = false }
  end

  global.mod.network_chest_has_been_placed = true
end

function M.copy_config(entity_id)
  local info = GlobalState.get_entity_info(entity_id)
  local new_requests = {}
  for _, request in ipairs(info.config.requests) do
    table.insert(new_requests, {
      type = request.type,
      item = request.item,
      priority = request.priority,
    })
  end
  local new_config = {
    requests = new_requests,
  }
  return new_config
end

function M.on_paste_settings(source, dest)
  if source.type == "assembling-machine" then
    local recipe = source.get_recipe()
    if recipe ~= nil then
      local dest_info = GlobalState.get_entity_info(dest.unit_number)
      local request_map = {}
      for _, request in ipairs(dest_info.config.requests) do
        request_map[request.item] = request
      end

      for _, ingredient in ipairs(recipe.ingredients) do
        if ingredient.type == "item" and request_map[ingredient.name] == nil then
          request_map[ingredient.name] = {
            item = ingredient.name,
            type = "request",
            priority = Priority.DEFAULT,
          }
        end
      end

      for _, product in ipairs(recipe.products) do
        if product.type == "item" then
          if request_map[product.name] == nil or request_map[product.name].type == "request" then
            request_map[product.name] = {
              item = product.name,
              type = "provide",
              priority = Priority.DEFAULT,
            }
          end
        end
      end

      local new_requests = {}
      for _, request in pairs(request_map) do
        table.insert(new_requests, request)
      end

      dest_info.config.requests = new_requests
      dest_info.config.has_been_updated = false
    end
  elseif source.name == "network-chest" or source.name == "medium-network-chest" or source.name == "large-network-chest" then
    local dest_info = GlobalState.get_entity_info(dest.unit_number)
    dest_info.config = M.copy_config(source.unit_number)
    dest_info.config.has_been_updated = false
  end
end

function M.on_remove_entity(event)
  GlobalState.put_chest_contents_in_network(event.entity)
end

function M.update_network_chest_capacity(info)
  -- game.print("updating network chest config")
  -- used to re-filter slots in a network chest when desired capacity changes.
  local inv = info.entity.get_output_inventory()
  local contents = inv.get_contents()
  local requests = info.config.requests

  inv.clear()

  local desired_slots = {}
  for _, request in ipairs(requests) do
    local stack_size = game.item_prototypes[request.item].stack_size
    if request.desired_capacity == nil then
      if request.type == "provide" then
        request.desired_capacity = stack_size
      else
        request.desired_capacity = 1
      end
    end
    local n_slots = math.ceil(request.desired_capacity / stack_size)
    table.insert(desired_slots, n_slots)
  end

  -- get real slot counts constrained by number of slots in inventory
  local slots = Helpers.int_partition(desired_slots, #inv)

  -- use filters to allocate space for items
  local slot_idx = 1
  for idx, request in ipairs(requests) do
    local n_slots = slots[idx]
    request.n_slots = n_slots
    local stack_size = game.item_prototypes[request.item].stack_size
    local real_capacity
    if request.type == "provide" then
      real_capacity = n_slots * stack_size
    elseif request.type == "request" then
      real_capacity = math.min(request.desired_capacity, n_slots * stack_size)
    else
      error("unreachable")
    end
    request.capacity = real_capacity
    for _ = 1, n_slots do
      inv.set_filter(slot_idx, request.item)
      slot_idx = slot_idx + 1
    end
  end

  -- set the bar to hide remaining space in container
  inv.set_bar(slot_idx)

  -- insert items back into container
  for _, request in ipairs(requests) do
    local prev_amount = contents[request.item] or 0
    local to_insert = math.min(prev_amount, request.capacity)
    if prev_amount > 0 then
      local inserted = inv.insert(
        { name = request.item, count = to_insert }
      )
      assert(inserted == to_insert)
      contents[request.item] = prev_amount - inserted
    end
  end

  -- put remaining items in shared storage
  for item, count in pairs(contents) do
    assert(count >= 0)
    if count > 0 then
      GlobalState.deposit_item2(item, count, Priority.ALWAYS_INSERT)
    end
  end
end

function M.on_update(info)
  if not info.config.has_been_updated then
    M.update_network_chest_capacity(info)
    info.config.has_been_updated = true
  end

  local inv = info.entity.get_output_inventory()
  local contents = inv.get_contents()
  local requests = info.config.requests
  local min_update_delay = constants.MIN_UPDATE_TICKS
  local max_update_delay = GlobalState.get_default_update_period()

  local next_delay = max_update_delay
  local ticks_since = nil
  if info.last_update_tick ~= nil then
    ticks_since = game.tick - info.last_update_tick
  end

  local capcacity_changed = false
  for _, request in ipairs(requests) do
    local prev_at_limit = request.prev_at_limit
    local prev_active = request.prev_active
    local start_amount = contents[request.item] or 0
    local started_at_limit
    local prev_delta = nil
    if request.type == "provide" then
      started_at_limit = start_amount >= request.capacity
      if request.prev_amount ~= nil then
        prev_delta = start_amount - request.prev_amount
      end
    elseif request.type == "request" then
      started_at_limit = start_amount == 0
      if request.prev_amount ~= nil then
        prev_delta = request.prev_amount - start_amount
      end
    else
      error("unreachable")
    end

    if prev_delta ~= nil then
      local max_rate = prev_delta / ticks_since
      if request.max_rate ~= nil then
        max_rate = math.max(max_rate, request.max_rate)
      end
      request.max_rate = max_rate
    end

    request.prev_active = false
    if prev_at_limit and started_at_limit then
      request.prev_active = true

      if prev_active then
        local next_capacity = math.ceil(
          1.5 * (1 + request.desired_capacity)
        )
        -- game.print(string.format(
        --   "Increasing capacity from %s to %s",
        --   request.desired_capacity,
        --   next_capacity
        -- ))
        request.desired_capacity = next_capacity
        capcacity_changed = true
      end
    end
  end

  if capcacity_changed then
    M.update_network_chest_capacity(info)
    contents = inv.get_contents()
  end

  for _, request in ipairs(requests) do
    local start_amount = contents[request.item] or 0

    local current_delta = 0
    local end_amount = start_amount
    local runway
    local ended_at_limit
    local started_at_limit
    if request.type == "provide" then
      started_at_limit = start_amount >= request.capacity
      if start_amount > 0 then
        local deposited = GlobalState.deposit_item2(
          request.item,
          start_amount,
          request.priority
        )
        if deposited > 0 then
          local actual_deposited = inv.remove(
            { name = request.item, count = deposited }
          )
          if deposited ~= actual_deposited then
            game.print(string.format(
              "Expected to deposit %d but deposited %d",
              deposited,
              actual_deposited
            ))
          end
          assert(deposited == actual_deposited)
          current_delta = deposited
          end_amount = start_amount - current_delta
        end
      end
      runway = request.capacity - end_amount
      ended_at_limit = end_amount == 0
    elseif request.type == "request" then
      started_at_limit = start_amount == 0
      local space_in_chest = math.max(0, request.capacity - start_amount)
      if space_in_chest > 0 then
        local withdrawn = GlobalState.withdraw_item2(
          request.item,
          space_in_chest,
          request.priority
        )
        local shortage = space_in_chest - withdrawn
        if shortage > 0 then
          GlobalState.missing_item_set(
            request.item,
            info.entity.unit_number,
            shortage
          )
        end
        if withdrawn > 0 then
          local actual_withdrawn = inv.insert({
            name = request.item,
            count = withdrawn,
          })
          if actual_withdrawn ~= withdrawn then
            game.print(string.format(
              "Expected to withdraw %d but withdrew %d",
              withdrawn,
              actual_withdrawn
            ))
            error("unreachable")
          end
          end_amount = start_amount + withdrawn
          current_delta = withdrawn
        end
      end
      runway = end_amount
      ended_at_limit = end_amount >= request.capacity
    else
      error("unreachable")
    end

    assert(end_amount >= 0)

    request.est_delay = nil
    if request.prev_active then
      request.est_delay = min_update_delay
    elseif runway > 0 and request.max_rate ~= nil and request.max_rate > 0 then
      local est_delay = runway * 0.8 / request.max_rate
      request.est_delay = est_delay
    elseif started_at_limit and ended_at_limit then
      request.est_delay = min_update_delay
    end

    if request.est_delay ~= nil then
      next_delay = math.min(next_delay, request.est_delay)
    end

    request.prev_amount = end_amount
    request.prev_at_limit = ended_at_limit
  end


  info.last_update_tick = game.tick

  next_delay = math.min(next_delay, max_update_delay)
  next_delay = math.max(next_delay, min_update_delay)

  if info.prev_delay ~= nil and next_delay > info.prev_delay then
    next_delay = (5 * info.prev_delay + next_delay) / 6
  end

  info.prev_delay = next_delay

  return next_delay
end

return M
