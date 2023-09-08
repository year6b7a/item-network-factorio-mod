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
      name = "item-network-enable-player-logistics",
      setting_type = "runtime-per-user",
      default_value = true,
    },
    {
      type = "bool-setting",
      name = "item-network-enable-logistic-chest",
      setting_type = "runtime-global",
      default_value = true,
    },
    {
      type = "int-setting",
      name = "item-network-number-of-entities-per-tick",
      setting_type = "runtime-global",
      default_value = 20,
      minimum_value = 1,
    },
    {
      type = "bool-setting",
      name = "item-network-enable-performance-tab",
      setting_type = "runtime-per-user",
      default_value = false,
    },
  })
end

M.main()
