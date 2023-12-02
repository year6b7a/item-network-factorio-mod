local Heap = require("src.Heap")

describe("Heap", function()
  it("basic", function()
    local heap = Heap.new()
    assert.are.same(Heap.peek(heap), nil)

    Heap.insert(heap, 3, "3")
    Heap.insert(heap, 1, "1")
    Heap.insert(heap, 5, "5")
    Heap.insert(heap, 2, "2")
    Heap.insert(heap, 4, "4")
    assert.are.same(Heap.peek(heap), { key = 1, value = "1" })
    Heap.pop(heap)
    assert.are.same(Heap.peek(heap), { key = 2, value = "2" })
    Heap.pop(heap)
    assert.are.same(Heap.peek(heap), { key = 3, value = "3" })
    Heap.pop(heap)
    assert.are.same(Heap.peek(heap), { key = 4, value = "4" })
    Heap.pop(heap)
    assert.are.same(Heap.peek(heap), { key = 5, value = "5" })
    Heap.pop(heap)
    assert.are.same(Heap.peek(heap), nil)
  end)

  it("randomized", function()
    local function shuffle(list)
      for i = #list, 2, -1 do
        local j = math.random(1, i)
        list[i], list[j] = list[j], list[i]
      end
    end


    local N = 1000
    local values = {}
    for idx = 1, N do
      table.insert(values, idx)
    end
    shuffle(values)

    local heap = Heap.new()
    for _, value in pairs(values) do
      Heap.insert(heap, value, value)
    end

    for idx = 1, N do
      -- Heap.debug(heap)
      assert.are.same(Heap.peek(heap), { key = idx, value = idx })
      Heap.pop(heap)
    end
    assert.are.same(Heap.peek(heap), nil)
  end)

  it("duplicate values", function()
    local heap = Heap.new()
    Heap.insert(heap, 1, "1")
    Heap.insert(heap, 2, "2")
    Heap.insert(heap, 2, "2")
    Heap.insert(heap, 2, "2")
    Heap.insert(heap, 3, "3")

    assert.are.same(Heap.peek(heap), { key = 1, value = "1" })
    Heap.pop(heap)
    assert.are.same(Heap.peek(heap), { key = 2, value = "2" })
    Heap.pop(heap)
    assert.are.same(Heap.peek(heap), { key = 2, value = "2" })
    Heap.pop(heap)
    assert.are.same(Heap.peek(heap), { key = 2, value = "2" })
    Heap.pop(heap)
    assert.are.same(Heap.peek(heap), { key = 3, value = "3" })
    Heap.pop(heap)
  end)
end)
