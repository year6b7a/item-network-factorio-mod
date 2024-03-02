local M = {}

function M.copy_request(request)
  return {
    type = request.type,
    item = request.item,
    priority = request.priority,
  }
end

function M.is_network_chest(name)
  return (
    name == "network-chest"
    or name == "medium-network-chest"
    or name == "large-network-chest"
  )
end

return M
