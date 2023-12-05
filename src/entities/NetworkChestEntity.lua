local GlobalState = require "src.GlobalState"
local Helpers = require "src.Helpers"
local constants = require "src.constants"

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
    local n_slots = math.ceil(request.desired_capacity / stack_size)
    table.insert(desired_slots, n_slots)
  end

  -- get real slot counts constrained by number of slots in inventory
  local slots = Helpers.int_partition(desired_slots, #inv)

  -- use filters to allocate space for items
  local slot_idx = 1
  for idx, request in ipairs(requests) do
    local n_slots = slots[idx]
    local stack_size = game.item_prototypes[request.item].stack_size
    local real_capacity
    if request.type == "provide" then
      real_capacity = n_slots * stack_size
    elseif request.type == "request" then
      real_capacity = math.min(request.desired_capacity, n_slots * stack_size)
    else
      error("unreachable")
    end
    request.n_slots = n_slots
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
      GlobalState.deposit_item(item, count)
    end
  end
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
    local start_amount = contents[request.item] or 0

    local started_at_limit
    local ended_at_limit
    local prev_delta
    local runway
    local end_amount = start_amount
    if request.type == "provide" then
      started_at_limit = start_amount >= request.capacity
      assert(start_amount <= request.capacity,
        string.format("current=%d, capacity=%d", start_amount, request
          .capacity))
      if request.prev_amount ~= nil then
        prev_delta = start_amount - request.prev_amount
      end
      if start_amount > 0 then
        local deposited = GlobalState.deposit_item_to_limit(
          request.item,
          start_amount
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
          end_amount = start_amount - deposited
        end
      end
      ended_at_limit = end_amount == 0
      runway = request.capacity - end_amount
    elseif request.type == "request" then
      started_at_limit = start_amount == 0
      if request.prev_amount ~= nil then
        prev_delta = request.prev_amount - start_amount
      end
      local available = GlobalState.get_item_available_to_withdraw(
        request.item
      )
      local space_in_chest = math.max(0, request.capacity - start_amount)
      local amount_to_withdraw = math.min(
        available,
        space_in_chest
      )
      if amount_to_withdraw > 0 then
        local withdrawn = inv.insert({
          name = request.item,
          count = amount_to_withdraw,
        })
        end_amount = start_amount + withdrawn
        GlobalState.withdraw_item(request.item, withdrawn)
      end
      ended_at_limit = end_amount >= request.capacity
      runway = end_amount
    else
      error("unreachable")
    end

    assert(end_amount >= 0)

    if prev_delta ~= nil then
      local max_rate = prev_delta / ticks_since
      if request.max_rate ~= nil then
        max_rate = math.max(max_rate, request.max_rate)
      end
      request.max_rate = max_rate

      if not request.initialized and (not started_at_limit or prev_delta == 0) then
        game.print(string.format(
          "Initialized request type=%s, start_amount=%s, end_amount=%s, limits=[%s, %s, %s] , prev_delta=%s, ticks_since=%s, capacity=%s, max_rate=%s",
          request.type,
          start_amount,
          end_amount,
          request.prev_at_limit,
          started_at_limit,
          ended_at_limit,
          prev_delta,
          ticks_since,
          request.capacity,
          max_rate
        ))
        request.initialized = true
      end
    end

    if request.prev_at_limit and started_at_limit then
      local next_capacity = math.ceil(1.5 *
        (1 + request.desired_capacity))
      -- game.print(string.format(
      --   "Increased desired capactity for item %s from %d to %d",
      --   request.item, request.desired_capacity, next_capacity
      -- ))
      game.print(string.format(
        "increasing capacity after delay=%s (est=%s) from %s -> %s",
        info.prev_delay or "?",
        request.est_delay or "?",
        request.desired_capacity,
        next_capacity
      ))
      request.desired_capacity = next_capacity
      capacity_changed = true
    end

    request.est_delay = nil
    if runway > 0 and request.max_rate ~= nil and request.max_rate > 0 then
      local stack_size = game.item_prototypes[request.item].stack_size
      local delay_5_stack = 5 * stack_size / request.max_rate
      local delay_80_percent = runway * 0.8 / request.max_rate
      local est_delay = math.min(delay_5_stack, delay_80_percent)
      request.est_delay = est_delay
      next_delay = math.min(next_delay, est_delay)
    end


    -- request.est_delay = nil
    -- if ticks_since ~= nil and request.prev_amount ~= nil then
    --   local stack_size = game.item_prototypes[request.item].stack_size
    --   local prev_delta
    --   local next_delta
    --   if request.type == "provide" then
    --     prev_delta = start_amount - request.prev_amount
    --     next_delta = request.capacity - current_amount
    --   elseif request.type == "request" then
    --     prev_delta = request.prev_amount - start_amount
    --     next_delta = current_amount
    --   else
    --     error("unreachable")
    --   end

    --   if prev_delta > 0 and next_delta > 0 then
    --     local max_rate = prev_delta / ticks_since
    --     if request.max_rate ~= nil then
    --       max_rate = math.max(max_rate, request.max_rate)
    --     end
    --     request.max_rate = max_rate

    --     local delay_5_stack = 5 * stack_size / max_rate
    --     local delay_80_percent = next_delta * 0.8 / max_rate
    --     local est_delay = math.min(delay_5_stack, delay_80_percent)
    --     request.est_delay = est_delay
    --     next_delay = math.min(next_delay, est_delay)
    --   end
    -- end

    if not request.initialized then
      next_delay = constants.MIN_UPDATE_TICKS
    end

    request.prev_amount = end_amount
    request.prev_at_limit = ended_at_limit
  end

  if capacity_changed then
    update_network_chest_capacity(info)
  end

  info.last_update_tick = game.tick
  info.prev_delay = next_delay

  return next_delay
end

return M
