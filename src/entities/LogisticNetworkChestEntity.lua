local Helpers = require "src.Helpers"
local Priority = require "src.Priority"
local GlobalState = require "src.GlobalState"
local Constants = require "src.constants"

local M = {}

M.entity_name = "logistic-network-chest"

function M.on_create_entity(state)
  if state.config == nil then
    state.config = { requests = {} }
  end

  global.mod.network_chest_has_been_placed = true
end

function M.copy_config(entity_id)
  local info = GlobalState.get_entity_info(entity_id)
  local new_requests = {}
  for _, request in ipairs(info.config.requests) do
    table.insert(new_requests, {
      item = request.item,
    })
  end
  local new_config = {
    requests = new_requests,
  }
  return new_config
end

function M.on_update(info)
  if info.entity.to_be_deconstructed() then
    return GlobalState.get_default_update_period()
  end

  local needs_to_set_initial_capacity = false
  for _, request in ipairs(info.config.requests) do
    if request.capacity == nil then
      needs_to_set_initial_capacity = true
    end
  end
  if needs_to_set_initial_capacity then
    M.update_request_capacities(info)
  end

  local inv = info.entity.get_output_inventory()
  local contents = inv.get_contents()
  local total_slots = #inv
  local requests = info.config.requests

  -- update request capacities
  local capacity_changed = false
  for _, request in ipairs(requests) do
    local prev_at_limit = request.prev_at_limit
    local start_amount = contents[request.item] or 0
    local started_at_limit = start_amount == 0
    local stack_size = game.item_prototypes[request.item].stack_size

    -- update chest capacities
    if prev_at_limit and started_at_limit then
      local max_capacity = total_slots * stack_size
      request.target_capacity = math.min(
        max_capacity,
        math.ceil((1 + request.target_capacity) * 1.5)
      )
      capacity_changed = true
    end
  end
  if capacity_changed then
    M.update_request_capacities(info)
  end

  -- transfer items
  for _, request in ipairs(requests) do
    local start_amount = contents[request.item] or 0
    local final_amount = start_amount
    local to_transfer = request.capacity - start_amount
    if to_transfer > 0 then
      local withdrawn = GlobalState.withdraw_item2(
        request.item,
        to_transfer,
        Priority.DEFAULT
      )
      local shortage = to_transfer - withdrawn
      if shortage > 0 then
        GlobalState.register_item_shortage(
          request.item,
          info.entity,
          shortage
        )
      end
      if withdrawn > 0 then
        local actual_inserted = inv.insert({
          name = request.item,
          count = withdrawn,
        })

        local excess = withdrawn - actual_inserted
        if excess > 0 then
          GlobalState.deposit_item2(
            request.item,
            excess,
            Priority.ALWAYS_INSERT
          )
        end

        final_amount = start_amount + actual_inserted
      end

      request.prev_at_limit = final_amount >= request.capacity
    elseif to_transfer < 0 then
      -- deposit excess
      local withdrawn = inv.remove({ name = request.item, count = -to_transfer })
      GlobalState.deposit_item2(request.item, withdrawn, Priority.ALWAYS_INSERT)
    end

    -- clear this item so we know not to dump
    contents[request.item] = nil
  end

  -- dump remaining items
  for item, count in pairs(contents) do
    if count > 0 then
      GlobalState.deposit_item2(item, count, Priority.ALWAYS_INSERT)
      local removed = inv.remove({ name = item, count = count })
      assert(removed == count)
    end
  end

  return GlobalState.get_default_update_period()
end

function M.update_request_capacities(info)
  local requests = info.config.requests
  local inv = info.entity.get_output_inventory()
  local total_slots = #inv

  local desired_slots = {}
  for _, request in ipairs(requests) do
    local stack_size = game.item_prototypes[request.item].stack_size
    if request.target_capacity == nil then
      request.target_capacity = 1
    end
    local n_slots = math.ceil(request.target_capacity / stack_size)
    table.insert(desired_slots, n_slots)
  end

  local slots = Helpers.int_partition(
    desired_slots,
    total_slots - Constants.LOGISTIC_NETWORK_CHEST_N_DUMP_SLOTS
  )
  for idx, request_slots in ipairs(slots) do
    local request = requests[idx]
    local stack_size = game.item_prototypes[request.item].stack_size
    local max_capacity = request_slots * stack_size
    request.capacity = math.min(
      request.target_capacity,
      max_capacity
    )
  end
end

function M.on_remove_entity(event)
  GlobalState.put_chest_contents_in_network(event.entity)
end

function M.on_marked_for_deconstruction(event)
  GlobalState.put_chest_contents_in_network(event.entity)
end

return M
