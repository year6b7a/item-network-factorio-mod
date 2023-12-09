local MaxTracker = require "src.MaxTracker"


describe("MaxTracker", function()
  it("basic ascending", function()
    local tracker = MaxTracker.new(4)
    assert.are.same(MaxTracker.get_max(tracker), nil)

    MaxTracker.update(tracker, 10, 1)
    assert.are.same(MaxTracker.get_max(tracker), 10)

    MaxTracker.update(tracker, 20, 1)
    assert.are.same(MaxTracker.get_max(tracker), 20)

    MaxTracker.update(tracker, 30, 3)
    assert.are.same(MaxTracker.get_max(tracker), 30)

    MaxTracker.update(tracker, 40, 3)
    assert.are.same(MaxTracker.get_max(tracker), 40)

    MaxTracker.update(tracker, 50, 5)
    assert.are.same(MaxTracker.get_max(tracker), 50)

    MaxTracker.update(tracker, 60, 5)
    assert.are.same(MaxTracker.get_max(tracker), 60)
  end)

  it("basic descending", function()
    local tracker = MaxTracker.new(4)

    MaxTracker.update(tracker, 100, 0)
    assert.are.same(MaxTracker.get_max(tracker), 100)

    MaxTracker.update(tracker, 90, 3)
    assert.are.same(MaxTracker.get_max(tracker), 100)

    MaxTracker.update(tracker, 80, 5)
    assert.are.same(MaxTracker.get_max(tracker), 90)

    MaxTracker.update(tracker, 70, 7)
    assert.are.same(MaxTracker.get_max(tracker), 80)

    MaxTracker.update(tracker, 60, 9)
    assert.are.same(MaxTracker.get_max(tracker), 70)

    MaxTracker.update(tracker, 50, 11)
    assert.are.same(MaxTracker.get_max(tracker), 60)

    MaxTracker.update(tracker, 40, 13)
    assert.are.same(MaxTracker.get_max(tracker), 50)
  end)

  it("skip ahead", function()
    local tracker = MaxTracker.new(4)

    MaxTracker.update(tracker, 100, 0)
    MaxTracker.update(tracker, 90, 3)
    assert.are.same(MaxTracker.get_max(tracker), 100)

    MaxTracker.update(tracker, 70, 7)
    assert.are.same(MaxTracker.get_max(tracker), 70)

    MaxTracker.update(tracker, 40, 13)
    assert.are.same(MaxTracker.get_max(tracker), 40)
  end)
end)
