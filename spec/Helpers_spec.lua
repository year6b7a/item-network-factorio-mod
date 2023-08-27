Helpers = require "src.Helpers"

describe("int_partition", function()
  it("return values when less than max", function()
    assert.are.same(
      Helpers.int_partition({ 1, 2, 3 }, 100),
      { 1, 2, 3 }
    )
  end)

  it("round values when greater than max", function()
    assert.are.same(
      Helpers.int_partition({ 100, 200, 300 }, 6),
      { 1, 2, 3 }
    )
  end)

  it("handle some zeros", function()
    assert.are.same(
      Helpers.int_partition({ 100, 0, 0 }, 7),
      { 7, 0, 0 }
    )
  end)

  it("handle some zeros with nonzero at end", function()
    assert.are.same(
      Helpers.int_partition({ 100, 0, 1 }, 7),
      { 6, 0, 1 }
    )
  end)

  it("make sure small numbers get at least one", function()
    assert.are.same(
      Helpers.int_partition({ 100, 0, 1, 0, 1 }, 4),
      { 2, 0, 1, 0, 1 }
    )
    assert.are.same(
      Helpers.int_partition({ 1, 0, 100, 0, 1 }, 4),
      { 1, 0, 2, 0, 1 }
    )
    assert.are.same(
      Helpers.int_partition({ 1, 0, 1, 0, 100 }, 4),
      { 1, 0, 1, 0, 2 }
    )
  end)

  it("return zeros when not enough space", function()
    assert.are.same(
      Helpers.int_partition({ 1, 2, 3, 4 }, 2),
      { 1, 1, 0, 0 }
    )
  end)

  it("real example", function()
    assert.are.same(
      Helpers.int_partition({ 240, 130, 110 }, 48),
      { 23, 13, 12 }
    )
  end)
end)
