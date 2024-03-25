local Priority = require "src.Priority"
local GlobalState = require "src.GlobalState"

local M = {}

M.entity_name = "item-request-proxy"

function M.on_update(info)
  if M.fulfill_requests(info.entity, info.item_requests) then
    return "UNREGISTER_ENTITY"
  else
    return GlobalState.get_default_update_period()
  end
end

function M.fulfill_requests(entity, item_requests)
  -- This function returns true of the request was fulfilled
  -- and false if there are missing items.

  assert(entity.name == "item-request-proxy")
  local target = entity.proxy_target
  local module_inv = target.get_module_inventory()
  if module_inv == nil then
    return true
  end

  local satisfied_requests = true
  GlobalState.deposit_inv_contents(module_inv)
  local new_requests = {}
  for item_name, item_count in pairs(item_requests) do
    local satisfied_request = false
    local withdrawn = GlobalState.withdraw_item2(
      item_name,
      item_count,
      Priority.HIGH
    )
    if withdrawn > 0 then
      local inserted = module_inv.insert({ name = item_name, count = withdrawn })
      local leftover = withdrawn - inserted
      if leftover > 0 then
        GlobalState.deposit_item2(
          item_name,
          leftover,
          Priority.ALWAYS_INSERT
        )
      end

      if inserted == item_count then
        satisfied_request = true
      end
    end

    local new_request_count = item_count - module_inv.get_item_count(item_name)
    if new_request_count > 0 then
      new_requests[item_name] = new_request_count
    end
    if not satisfied_request then
      satisfied_requests = false
    end
  end

  entity.item_requests = new_requests

  if module_inv.is_full() then
    return true
  end

  return satisfied_requests
end

return M
