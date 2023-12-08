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

function M.on_update(info)
  local defaultUpdate = GlobalState.get_default_update_period()

  if info.temp == nil or info.fluid == nil or info.type == nil then
    return defaultUpdate
  end



  return defaultUpdate
end

return M
