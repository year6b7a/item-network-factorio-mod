local Helpers = require "src.Helpers"
local GlobalState = require "src.GlobalState"
local M = {}

M.entity_name = "network-tank"

function M.on_create_entity(state)
  if state.config == nil then
    state.config = { type = "provide" }
  end
end

function M.copy_config(entity_id)
  local info = GlobalState.get_entity_info(entity_id)
  return Helpers.shallow_copy(info.config)
end

function M.on_remove_entity(event)
  GlobalState.put_tank_contents_in_network(event.entity)
end

function M.on_update(state)
  local defaultUpdate = 60 * 1

  local fluidbox = state.entity.fluidbox
  assert(#fluidbox == 1)

  if state.config.type == "request" then
    if state.config.fluid ~= nil and state.config.temp ~= nil then
      local capacity = fluidbox.get_capacity(1)
      local fluid = fluidbox[1]
      if fluid ~= nil then
        capacity = capacity - fluid.amount
      end
      if fluid == nil or (fluid.name == state.config.fluid and fluid.temperature == state.config.temp) then
        local withdrawn = GlobalState.withdraw_fluid(
          state.config.fluid,
          state.config.temp,
          capacity
        )
        if withdrawn > 0 then
          local inserted = state.entity.insert_fluid({
            name = state.config.fluid,
            temperature = state.config.temp,
            amount = withdrawn,
          })
          assert(inserted == withdrawn)
        end
      end
    end
  elseif state.config.type == "provide" then
    local fluid = fluidbox[1]
    if fluid ~= nil then
      local deposited = GlobalState.deposit_fluid(
        fluid.name,
        fluid.temperature,
        fluid.amount,
        not state.config.no_limit
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
