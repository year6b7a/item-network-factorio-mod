local Heap = require("src.QuadHeap")

function main()
  local N = 10000
  local values = {}
  for _ = 1, N do
    table.insert(values, 1000 + 60 * math.random())
  end

  local heap = Heap.new()
  for idx, value in pairs(values) do
    Heap.insert(heap, value, { idx = idx })
  end

  local t0 = os.clock()
  local total = 0
  for tick = 1, 1000 do
    local items = {}
    for _ = 1, 20 do
      local item = Heap.peek(heap).value
      Heap.pop(heap)
      total = total + item.idx
      table.insert(items, item)
    end

    for _, item in ipairs(items) do
      Heap.insert(heap, 60 * tick + 100 * 60 * math.random(), item)
    end
  end
  local t1 = os.clock()
  print(string.format("Took %s ms", 1000 * (t1 - t0)))
end

main()
