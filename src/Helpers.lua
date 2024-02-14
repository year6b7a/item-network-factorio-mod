local Helpers = {}

function Helpers.int_partition(values, max)
  local total = 0
  local nonzero_count = 0
  for _, value in ipairs(values) do
    total = total + value
    if value > 0 then
      nonzero_count = nonzero_count + 1
    end
  end

  if total <= max then
    return values
  end

  local remaining_max = max
  local remaining_total = total
  local remaining_nonzero_count = nonzero_count
  local new_values = {}
  for _, value in ipairs(values) do
    if remaining_total <= 0 then
      table.insert(new_values, 0)
    elseif value <= 0 then
      table.insert(new_values, 0)
    else
      remaining_nonzero_count = remaining_nonzero_count - 1
      local new_value = math.floor(0.5 +
        value * (remaining_max - remaining_nonzero_count) / remaining_total)
      new_value = math.max(1, new_value)
      new_value = math.min(new_value, remaining_max)
      table.insert(new_values, new_value)
      remaining_max = remaining_max - new_value
      remaining_total = remaining_total - value
    end
  end
  return new_values
end

function Helpers.split_list_by_batch_size(elements, batch_size)
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

function Helpers.shallow_copy(t)
  local t2 = {}
  for k, v in pairs(t) do
    t2[k] = v
  end
  return t2
end

function Helpers.deep_copy(datatable)
  local res = {}
  if type(datatable) == "table" then
    for k, v in pairs(datatable) do
      res[k] = Helpers.deep_copy(v)
    end
  else
    res = datatable
  end
  return res
end

function Helpers.table_len(table)
  local len = 0
  for _, _ in pairs(table) do
    len = len + 1
  end
  return len
end

return Helpers
