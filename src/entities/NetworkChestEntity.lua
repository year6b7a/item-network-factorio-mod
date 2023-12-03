local GlobalState = require "src.GlobalState"
local Helpers = require "src.Helpers"

local M = {}

M.entity_name = "network-chest"

function M.on_create_entity(state)
  if state.config == nil then
    state.config = { requests = {}, has_been_updated = false }
  end
end

function M.copy_config(entity_id)
  local info = GlobalState.get_entity_info(entity_id)
  local new_requests = {}
  for _, request in ipairs(info.config.requests) do
    table.insert(new_requests, { type = request.type, item = request.item })
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
      local new_requests = {}
      local tracked_items = {}
      for _, request in ipairs(dest_info.config.requests) do
        table.insert(new_requests, request)
        tracked_items[request.item] = true
      end

      for _, ingredient in ipairs(recipe.ingredients) do
        if ingredient.type == "item" and tracked_items[ingredient.name] == nil then
          tracked_items[ingredient.name] = true
          table.insert(new_requests, {
            item = ingredient.name,
            type = "request",
          })
        end
      end

      for _, product in ipairs(recipe.products) do
        if product.type == "item" and tracked_items[product.name] == nil then
          tracked_items[product.name] = true
          table.insert(new_requests, {
            item = product.name,
            type = "provide",
          })
        end
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

local function update_network_chest_capacity(info)
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
    request.n_slots = math.ceil(request.desired_capacity / stack_size)
    table.insert(desired_slots, request.n_slots)
  end

  -- get real slot counts constrained by number of slots in inventory
  local slots = Helpers.int_partition(desired_slots, #inv)

  -- use filters to allocate space for items
  local slot_idx = 1
  for idx, request in ipairs(requests) do
    local n_slots = slots[idx]
    local stack_size = game.item_prototypes[request.item].stack_size
    local real_capacity = n_slots * stack_size
    request.capacity = math.min(request.desired_capacity, real_capacity)
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
    if prev_amount > 0 then
      local inserted = inv.insert(
        { name = request.item, count = prev_amount }
      )
      contents[request.item] = prev_amount - inserted
    end
  end

  -- put remaining items in shared storage
  for item, count in pairs(contents) do
    assert(count >= 0)
    if count > 0 then
      GlobalState.deposit_material(item, count)
    end
  end
end

local function get_estimated_delay(
  ticks_since,
  request,
  current_amount,
  delay
)
  if ticks_since == nil then
    return delay
  end

  local prev_amount = request.prev_amount
  if prev_amount == nil then
    return delay
  end

  local delta
  if request.type == "provide" then
    delta = current_amount - prev_amount
  elseif request.type == "request" then
    delta = prev_amount - current_amount
  else
    error("unreachable")
  end

  if delta <= 0 then
    return delay
  end

  local est_delay = 0.8 * ticks_since / delta * request.capacity
  assert(est_delay > 0)
  return math.min(delay, est_delay)
end

function M.on_update(info)
  local inv = info.entity.get_output_inventory()
  local contents = inv.get_contents()
  local requests = info.config.requests

  local next_delay = GlobalState.get_default_update_period()
  local ticks_since = nil
  if info.last_update_tick ~= nil then
    ticks_since = game.tick - info.last_update_tick
  end

  if not info.config.has_been_updated then
    update_network_chest_capacity(info)
    info.config.has_been_updated = true
  end

  local capacity_changed = false
  for _, request in ipairs(requests) do
    local current_amount = contents[request.item] or 0
    if request.type == "provide" then
      local started_full = current_amount >= request.capacity
      if current_amount > 0 then
        local deposited = GlobalState.deposit_material_to_limit(
          request.item,
          current_amount
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
          current_amount = current_amount - deposited
          if current_amount == 0 and started_full then
            local next_capacity = math.ceil(1.5 *
              (1 + request.desired_capacity))
            -- game.print(string.format(
            --   "Increased desired capactity for item %s from %d to %d",
            --   request.item, request.desired_capacity, next_capacity
            -- ))
            request.desired_capacity = next_capacity
            capacity_changed = true
          end
        end
      end
    elseif request.type == "request" then
      local started_empty = current_amount == 0
      local available = GlobalState.get_material_available_to_withdraw(
        request.item
      )
      local space_in_chest = math.max(0, request.capacity - current_amount)
      local amount_to_withdraw = math.min(
        available,
        space_in_chest
      )
      if amount_to_withdraw > 0 then
        local withdrawn = inv.insert({
          name = request.item,
          count = amount_to_withdraw,
        })
        current_amount = current_amount + withdrawn
        GlobalState.withdraw_material(request.item, withdrawn)
        if started_empty and current_amount == request.capacity then
          local next_capacity = math.ceil(1.5 *
            (1 + request.desired_capacity))
          -- game.print(string.format(
          --   "Increased desired capactity for item %s from %d to %d",
          --   request.item, request.desired_capacity, next_capacity
          -- ))
          request.desired_capacity = next_capacity
          capacity_changed = true
        end
      end
    else
      error("unreachable")
    end

    next_delay = get_estimated_delay(
      ticks_since,
      request,
      current_amount,
      next_delay
    )
  end

  if capacity_changed then
    update_network_chest_capacity(info)
  end

  info.last_update_tick = game.tick
  info.prev_delay = next_delay

  return next_delay
end

return M
