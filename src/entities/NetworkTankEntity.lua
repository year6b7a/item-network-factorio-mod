local GlobalState = require "src.GlobalState"
local NetworkTankPasteWindow = require "src.windows.NetworkTankPasteWindow"
local Priority = require "src.Priority"
local M = {}

M.entity_name = "network-tank"

function M.on_create_entity(state)
  if state.config == nil then
    state.config = { type = "provide" }
  end
end

function M.copy_config(entity_id)
  local info = GlobalState.get_entity_info(entity_id)
  return {
    type = info.config.type,
    fluid = info.config.fluid,
    temp = info.config.temp,
    priority = info.config.priority,
  }
end

function M.on_paste_settings(source, dest, player)
  if source.type == "assembling-machine" then
    local recipe = source.get_recipe()
    if recipe ~= nil then
      local requested_fluids = {}

      for _, ingredient in ipairs(recipe.ingredients) do
        if ingredient.type == "fluid" then
          table.insert(requested_fluids, {
            name = ingredient.name,
            minimum_temperature = ingredient.minimum_temperature,
            maximum_temperature = ingredient.maximum_temperature,
          })
        end
      end

      if #requested_fluids > 0 then
        NetworkTankPasteWindow.open_window(player, dest, requested_fluids)
      end
    end
  elseif source.name == "network-tank" or source.name == "medium-network-tank" or source.name == "large-network-tank" then
    local dest_info = GlobalState.get_entity_info(dest.unit_number)
    dest_info.config = M.copy_config(source.unit_number)
    dest_info.config.has_been_updated = false
  end
end

function M.on_remove_entity(event)
  GlobalState.put_tank_contents_in_network(event.entity)
end

function M.on_update(state)
  local defaultUpdate = GlobalState.get_default_update_period()

  local fluidbox = state.entity.fluidbox
  assert(#fluidbox == 1)

  if state.config.type == "request" then
    if state.config.fluid ~= nil and state.config.temp ~= nil then
      local fluid = fluidbox[1]
      if fluid == nil or (fluid.name == state.config.fluid and fluid.temperature == state.config.temp) then
        local max_capacity = fluidbox.get_capacity(1)
        local capacity = 100
        if state.config.capacity ~= nil then
          capacity = state.config.capacity
        end

        local current_amount = 0
        if fluid ~= nil then
          current_amount = fluid.amount
        end

        if state.config.prev_at_limit and current_amount < 100 then
          -- increase capacity
          if capacity < max_capacity then
            -- game.print("Increasing capacity from " ..
            --   capacity .. " to " .. capacity * 1.5)
            capacity = math.floor(capacity * 1.5)
            state.config.capacity = capacity
          end
        end

        state.config.prev_at_limit = false

        capacity = math.min(capacity, max_capacity)

        local desired_amount = math.max(0, capacity - current_amount)
        if desired_amount > 0 then
          local withdrawn = GlobalState.withdraw_fluid2(
            state.config.fluid,
            state.config.temp,
            desired_amount,
            state.config.priority
          )
          if withdrawn > 0 then
            local inserted = state.entity.insert_fluid({
              name = state.config.fluid,
              temperature = state.config.temp,
              amount = withdrawn,
            })
            assert(inserted == withdrawn)
            if current_amount + withdrawn + 10 > capacity then
              state.config.prev_at_limit = true
            end
          end
        end
      end
    end
  elseif state.config.type == "provide" then
    local fluid = fluidbox[1]
    if fluid ~= nil then
      local deposited = GlobalState.deposit_fluid2(
        fluid.name,
        fluid.temperature,
        fluid.amount,
        state.config.priority == nil and Priority.DEFAULT or
        state.config.priority
      )
      if deposited > 0 then
        local result_amount = fluid.amount - deposited
        assert(result_amount >= 0)
        if result_amount == 0 then
          fluidbox[1] = nil
        else
          fluid.amount = fluid.amount - deposited
          fluidbox[1] = fluid
        end
      end
    end
  else
    error("unreachable")
  end

  return defaultUpdate
end

return M
