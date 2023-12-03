local Heap = {}

function Heap.new()
  return {
    keys = {},
    values = {},
    size = 0,
  }
end

local function swap(heap, idx0, idx1)
  heap.keys[idx0], heap.keys[idx1] = heap.keys[idx1], heap.keys[idx0]
  heap.values[idx0], heap.values[idx1] = heap.values[idx1], heap.values[idx0]
end

local function heapify_down(heap, idx)
  while idx > 1 do
    local next_idx = math.floor((idx) / 2)
    if heap.keys[next_idx] > heap.keys[idx] then
      swap(heap, idx, next_idx)
    else
      break
    end

    idx = next_idx
  end
end

local function heapify_up(heap, idx)
  -- assert(heap.size == #heap.keys)
  while true do
    local next_idx0 = 2 * idx
    local next_idx1 = next_idx0 + 1
    if next_idx0 <= heap.size then
      if next_idx1 <= heap.size then
        if heap.keys[next_idx0] < heap.keys[next_idx1] then
          if heap.keys[next_idx0] < heap.keys[idx] then
            swap(heap, idx, next_idx0)
            idx = next_idx0
          else
            break
          end
        elseif heap.keys[next_idx1] < heap.keys[idx] then
          swap(heap, idx, next_idx1)
          idx = next_idx1
        else
          break
        end
      elseif heap.keys[next_idx0] < heap.keys[idx] then
        swap(heap, idx, next_idx0)
      else
        break
      end
    else
      break
    end
  end
end

function Heap.insert(heap, key, value)
  -- assert(heap.size == #heap.keys)
  -- assert(heap.size == #heap.values)
  table.insert(heap.keys, key)
  table.insert(heap.values, value)
  heap.size = heap.size + 1
  heapify_down(heap, heap.size)
  -- assert(heap.size == #heap.keys)
  -- assert(heap.size == #heap.values)
end

function Heap.peek(heap)
  if heap.size == 0 then
    return nil
  end

  return { key = heap.keys[1], value = heap.values[1] }
end

function Heap.pop(heap)
  -- assert(heap.size == #heap.keys)
  -- assert(heap.size == #heap.values)
  if heap.size == 0 then
    return
  end

  if heap.size >= 2 then
    swap(heap, 1, heap.size)
    table.remove(heap.keys)
    table.remove(heap.values)
    heap.size = heap.size - 1
    heapify_up(heap, 1)
  else
    table.remove(heap.keys)
    table.remove(heap.values)
    heap.size = heap.size - 1
  end

  -- assert(heap.size == #heap.keys)
  -- assert(heap.size == #heap.values)
end

function Heap.debug(heap)
  print("--------------------")
  for idx, key in pairs(heap.keys) do
    print(key, heap.values[idx])
  end
  print("------------------")
end

return Heap
