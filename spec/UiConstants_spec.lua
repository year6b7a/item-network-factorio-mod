local UiConstants = require "src.UiConstants"

describe("UiConstants", function()
  it("no duplicate keys", function()
    local values = {}
    local n_keys = 0
    for _, value in pairs(UiConstants) do
      values[value] = true
      n_keys = n_keys + 1
    end

    -- count the values
    local n_values = 0
    for _, _ in pairs(values) do
      n_values = n_values + 1
    end

    assert.truthy(n_keys == n_values)
  end)
end)
