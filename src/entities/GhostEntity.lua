local NetworkChestHelpers = require "src.NetworkChestHelpers"
local Priority = require "src.Priority"
local GlobalState = require "src.GlobalState"
local Helpers = require "src.Helpers"
local constants = require "src.constants"
local ItemRequestProxyEntity = require "src.entities.ItemRequestProxyEntity"

local M = {}

M.entity_name = "entity-ghost"

function M.on_update(info)
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
        local collided_items, revived_entity, request_proxy = entity.revive({
          raise_revive = true,
          return_item_request_proxy = true,
        })
        if request_proxy ~= nil then
          local item_requests = {}
          for item_name, item_count in pairs(request_proxy.item_requests) do
            if item_count > 0 then
              item_requests[item_name] = item_count
            end
          end
          if not ItemRequestProxyEntity.fulfill_requests(request_proxy, item_requests) then
            -- add item request proxy to queue
            GlobalState.register_and_enqueue_entity(request_proxy, {
              item_requests = item_requests,
            })
          end
        end
        return true
      end
    end
  end

  return true
end

return M
