local Utils = require "src.Utils"
describe("split_list_by_batch_size", function()
  it("basic", function()
    assert.are.same(
      Utils.split_list_by_batch_size(
        { 0, 1, 2, 3, 4, 5, 6 },
        3
      ),
      {
        { 0, 1, 2 },
        { 3, 4, 5 },
        { 6 },
      }
    )

    assert.are.same(
      Utils.split_list_by_batch_size({}, 4),
      {}
    )

    assert.are.same(
      Utils.split_list_by_batch_size({ 1, 2, 3 }, 0),
      { { 1 }, { 2 }, { 3 } }
    )
  end)
end)
