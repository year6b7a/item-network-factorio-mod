local tables_have_same_keys = require("src.tables_have_same_keys")
  .tables_have_same_keys

describe("tables_have_same_keys", function()
  it("basic", function()
    assert.are.same(tables_have_same_keys({}, {}), true)
    assert.are.same(tables_have_same_keys(nil, {}), false)
    assert.are.same(tables_have_same_keys({}, nil), false)
    assert.are.same(tables_have_same_keys(nil, nil), false)
    assert.are.same(tables_have_same_keys(
      { a = 1 },
      { a = 1 }
    ), true)
    assert.are.same(tables_have_same_keys(
      { a = 1 },
      { b = 1 }
    ), false)
    assert.are.same(tables_have_same_keys(
      { a = 1, b = 1 },
      { a = 1, b = 1 }
    ), true)
    assert.are.same(tables_have_same_keys(
      { a = 1 },
      { a = 1, b = 1 }
    ), false)
    assert.are.same(tables_have_same_keys(
      { a = 1, b = 1 },
      { a = 1 }
    ), false)
  end)
end)
