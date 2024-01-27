local Priority = require "src.Priority"
local M = {}

M.options = {
  { label = "Low",     value = Priority.LOW },
  { label = "Default", value = Priority.DEFAULT },
  { label = "High",    value = Priority.HIGH },
}

function M.add_elem(flow, value, elem_id)
  if value == nil then
    value = Priority.DEFAULT
  end

  local dropdown_items = {}
  local selected_idx = 1
  for idx, option in ipairs(M.options) do
    table.insert(dropdown_items, option.label)
    if option.value == value then
      selected_idx = idx
    end
  end

  elem = flow.add({
    type = "drop-down",
    items = dropdown_items,
    selected_index = selected_idx,
    tags = { elem_id = elem_id },
  })

  return elem
end

return M
