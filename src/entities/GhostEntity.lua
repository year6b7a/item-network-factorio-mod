local NetworkChestHelpers = require "src.NetworkChestHelpers"
local Priority = require "src.Priority"
local GlobalState = require "src.GlobalState"
local Helpers = require "src.Helpers"
local constants = require "src.constants"

local M = {}

M.entity_name = "entity-ghost"

function M.on_update(info)
  game.print("trying to revive entity")
  if M.revive_ghost(info.entity) then
    return "UNREGISTER_ENTITY"
  else
    return GlobalState.get_default_update_period()
  end
end

function M.revive_ghost(entity)
  local proto = entity.ghost_prototype
  if proto ~= nil then
    if proto.items_to_place_this ~= nil and #proto.items_to_place_this > 0 then
      local item = proto.items_to_place_this[1]
      local name = item.name
      local count = item.count
      if count == nil then
        count = 1
      end

      local withdrawn = GlobalState.withdraw_item2(name, count, Priority.HIGH)
      if withdrawn ~= count then
        GlobalState.deposit_item2(name, withdrawn, Priority.ALWAYS_INSERT)
        return false
      else
        -- place the ghost
        entity.revive()
        return true
      end
    end
  end

  return true
end

return M
