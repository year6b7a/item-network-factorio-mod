local M = {}

function M.new()
  return {
    idx_start = 1,
    idx_end = 1,
    size = 0,
    capacity = 1,
    data = {},
  }
end

function M.push(queue, value)
  if queue.size == queue.capacity then
    M.__grow_queue(queue)
  end
  assert(queue.size < queue.capacity)
  queue.data[queue.idx_end] = value
  queue.idx_end = (queue.idx_end) % queue.capacity + 1
  queue.size = queue.size + 1
end

function M.__grow_queue(queue)
  local new_cap = math.ceil(queue.capacity * 1.5)
  local new_data = {}
  for i = 1, queue.size do
    new_data[i] = queue.data[(queue.idx_start + i - 2) % queue.capacity + 1]
  end
  queue.capacity = new_cap
  queue.data = new_data
  queue.idx_start = 1
  queue.idx_end = queue.size % queue.capacity + 1
end

function M.__shrink_queue(queue)
  local new_cap = math.ceil(queue.capacity / 2)
  local new_data = {}
  for i = 1, queue.size do
    new_data[i] = queue.data[(queue.idx_start + i - 2) % queue.capacity + 1]
  end
  queue.capacity = new_cap
  queue.data = new_data
  queue.idx_start = 1
  queue.idx_end = queue.size % queue.capacity + 1
end

function M.pop(queue)
  if queue.size == 0 then
    return nil
  end
  if queue.size + queue.size < queue.capacity then
    M.__shrink_queue(queue)
  end
  local value = queue.data[queue.idx_start]
  queue.data[queue.idx_start] = 0
  queue.idx_start = (queue.idx_start) % queue.capacity + 1
  queue.size = queue.size - 1
  return value
end

function M.pop_random(queue, rand)
  if queue.size == 0 then
    return nil
  end
  local idx = (queue.idx_start + rand(queue.size) - 2) % queue.capacity + 1
  local temp = queue.data[idx]
  queue.data[idx] = queue.data[queue.idx_start]
  queue.data[queue.idx_start] = temp
  return M.pop(queue)
end

function M.get_front(queue)
  if queue.size == 0 then
    return nil
  end
  return queue.data[queue.idx_start]
end

return M
