local M = {}

-- non-recursive comparison of the keys of two tables
function M.tables_have_same_keys(tab1, tab2)
  if tab1 == nil or tab2 == nil then
    return false
  end
  for k1, _ in pairs(tab1) do
    if tab2[k1] == nil then
      return false
    end
  end
  for k2, _ in pairs(tab2) do
    if tab1[k2] == nil then
      return false
    end
  end
  return true
end

return M
