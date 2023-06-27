local M = {}

function M.main()
  data:extend({
    {
      type = "int-setting",
      name = "item-network-stack-size-on-assembler-paste",
      default_value = 5,
      minimum_value = 1,
      setting_type = "runtime-global",
    },
    {
      type = "bool-setting",
      name = "item-network-enable-logistic-trash",
      setting_type = "runtime-per-user",
      default_value = true,
    },
  })
end

M.main()
