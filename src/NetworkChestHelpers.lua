local M = {}

function M.copy_request(request)
  return {
    type = request.type,
    item = request.item,
    priority = request.priority,
  }
end

return M
