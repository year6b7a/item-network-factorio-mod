local M = {}

M.entity_name = "network-loader"
M.do_not_add_to_update_queue = true

function M.on_create_entity(state)
  if state.entity.loader_type == "output" and state.entity.get_filter(1) == nil then
    state.entity.set_filter(1, "deconstruction-planner")
  end
end

return M
