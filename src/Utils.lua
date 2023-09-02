local M = {}

function M.split_list_by_batch_size(elements, batch_size)
  local batches = {}
  local batch = {}

  for _, elem in ipairs(elements) do
    if #batch > 0 and #batch >= batch_size then
      table.insert(batches, batch)
      batch = {}
    end
    table.insert(batch, elem)
  end

  if #batch > 0 then
    table.insert(batches, batch)
  end

  return batches
end

return M
