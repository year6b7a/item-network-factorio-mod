local M = {}

M.entity_name = "network-loader"
M.do_not_add_to_update_queue = true

function M.on_create_entity(state)
  if state.entity.loader_type == "output" and state.entity.get_filter(1) == nil then
    if state.config == nil then
      state.entity.set_filter(1, "deconstruction-planner")
    end
  end
end

function M.copy_config(entity_id)
  -- return an empty object just so it's possible to tell the different between
  -- a new loader and a pasted loader with no filter
  return {}
end

function M.on_paste_same_entity_settings(source, dest)
  if source.name == "network-loader" then
    if source.loader_type ~= dest.loader_type then
      dest.loader_type = source.loader_type
    end
  end
end

return M
