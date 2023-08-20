local GlobalState = require "src.GlobalState"

describe("get_queue_counts", function()
  it("basic", function()
    assert.are.same(
      GlobalState.get_queue_counts(100, 100, 15, 2),
      { active = 10, inactive = 5 }
    )
  end)

  it("no active", function()
    assert.are.same(
      GlobalState.get_queue_counts(0, 100, 15, 2),
      { active = 0, inactive = 15 }
    )
  end)

  it("no inactive", function()
    assert.are.same(
      GlobalState.get_queue_counts(100, 0, 15, 2),
      { active = 15, inactive = 0 }
    )
  end)

  it("no active or inactive", function()
    assert.are.same(
      GlobalState.get_queue_counts(0, 0, 15, 2),
      { active = 0, inactive = 0 })
  end)

  it("just a few active", function()
    assert.are.same(
      GlobalState.get_queue_counts(5, 0, 15, 2),
      { active = 5, inactive = 0 }
    )
  end)

  it("just a few inactive", function()
    assert.are.same(
      GlobalState.get_queue_counts(0, 7, 15, 2),
      { active = 0, inactive = 7 }
    )
  end)

  it("just a few active and inactive", function()
    assert.are.same(
      GlobalState.get_queue_counts(2, 9, 15, 2),
      { active = 2, inactive = 9 }
    )
    assert.are.same(
      GlobalState.get_queue_counts(9, 2, 15, 2),
      { active = 9, inactive = 2 }
    )
  end)

  it("include at least one active", function()
    assert.are.same(
      GlobalState.get_queue_counts(1, 999999, 15, 1),
      { active = 1, inactive = 14 }
    )
  end)

  it("include at least one inactive", function()
    assert.are.same(
      GlobalState.get_queue_counts(9999999, 1, 15, 1),
      { active = 14, inactive = 1 }
    )
  end)

  it("low n_entities", function()
    assert.are.same(
      GlobalState.get_queue_counts(20, 20, 1, 1),
      { active = 1, inactive = 1 }
    )
  end)

  it("different weight", function()
    assert.are.same(
      GlobalState.get_queue_counts(100, 100, 20, 3),
      { active = 15, inactive = 5 }
    )
    assert.are.same(
      GlobalState.get_queue_counts(14, 100, 20, 3),
      { active = 14, inactive = 6 }
    )
    assert.are.same(
      GlobalState.get_queue_counts(15, 100, 20, 3),
      { active = 15, inactive = 5 }
    )
    assert.are.same(
      GlobalState.get_queue_counts(100, 4, 20, 3),
      { active = 16, inactive = 4 }
    )
    assert.are.same(
      GlobalState.get_queue_counts(100, 5, 20, 3),
      { active = 15, inactive = 5 }
    )
  end)
end)
