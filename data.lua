local constants = require "src.constants"
local Paths = require "src.Paths"
local Hotkeys = require "src.Hotkeys"

local M = {}

function M.main()
  M.add_network_chest()
  M.add_loader()
  M.add_network_tank()

  data:extend(Hotkeys.hotkeys)
end

function M.add_network_chest()
  local name = "network-chest"
  local override_item_name = "iron-chest"
  local overwrite_prototype = "container"

  local entity = table.deepcopy(data.raw[overwrite_prototype]
    [override_item_name])
  entity.name = name
  entity.picture = {
    filename = Paths.graphics .. "/entities/network-chest.png",
    size = 64,
    scale = 0.5,
  }
  entity.inventory_size = constants.NUM_INVENTORY_SLOTS
  entity.inventory_type = "with_filters_and_bar"
  entity.minable.result = name

  local item = table.deepcopy(data.raw["item"][override_item_name])
  item.name = name
  item.place_result = name
  item.icon = Paths.graphics .. "/items/network-chest.png"
  item.size = 64

  local recipe = {
    name = name,
    type = "recipe",
    enabled = true,
    energy_required = 0.5,
    ingredients = {},
    result = name,
    result_count = 1,
  }

  data:extend({ entity, item, recipe })
end

function M.add_loader()
  local name = "network-loader"

  local entity = {
    name = "network-loader",
    type = "loader-1x1",
    icon = Paths.graphics .. "/entities/express-loader.png",
    icon_size = 64,
    flags = { "placeable-neutral", "player-creation",
      "fast-replaceable-no-build-while-moving", },
    minable = {
      mining_time = 0.2,
      result = "network-loader",
    },
    max_health = 300,
    corpse = "small-remnants",
    collision_box = { { -0.4, -0.45 }, { 0.4, 0.45 } },
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    drawing_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
    animation_speed_coefficient = 32,
    belt_animation_set = data.raw["transport-belt"]["express-transport-belt"]
      .belt_animation_set,
    container_distance = 0.75,
    belt_length = 0.5,
    fast_replaceable_group = "transport-belt",
    filter_count = 1,
    -- https://wiki.factorio.com/Prototype/TransportBeltConnectable#speed
    -- equivalent to 2x blue belt speed
    speed = 0.1875,
    structure = {
      direction_in = {
        sheet = {
          filename = Paths.graphics .. "/entities/express-loader.png",
          priority = "extra-high",
          shift = { 0.15625, 0.0703125 },
          width = 106 * 2,
          height = 85 * 2,
          y = 85 * 2,
          scale = 0.25,
        },
      },
      direction_out = {
        sheet = {
          filename = Paths.graphics .. "/entities/express-loader.png",
          priority = "extra-high",
          shift = { 0.15625, 0.0703125 },
          width = 106 * 2,
          height = 85 * 2,
          scale = 0.25,
        },
      },
    },
  }

  local item = {
    name = name,
    type = "item",
    place_result = name,
    icon = Paths.graphics .. "/items/express-loader.png",
    icon_size = 64,
    stack_size = 50,
    subgroup = data.raw["item"]["iron-chest"].subgroup,
    order = data.raw["item"]["iron-chest"].order,
  }

  local recipe = {
    name = name,
    type = "recipe",
    enabled = true,
    energy_required = 0.5,
    ingredients = {},
    result = name,
    result_count = 1,
  }

  data:extend({ entity, item, recipe })
end

function M.add_network_tank()
  local name = "network-tank"
  local override_item_name = "storage-tank"
  local overwrite_prototype = "storage-tank"

  local entity = table.deepcopy(data.raw[overwrite_prototype]
    [override_item_name])
  entity.name = name
  entity.selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
  entity.collision_box = { { -0.45, -0.45 }, { 0.45, 0.45 } }
  entity.window_bounding_box = { { -0.2, -0.2 }, { 0.2, 0.2 } }
  entity.fluid_box = {
    base_area = constants.TANK_AREA,
    height = constants.TANK_HEIGHT,
    pipe_connections =
    {
      { position = { 0, 1 }, type = "input-output" },
    },
  }
  -- entity.picture = {
  --   filename = Paths.graphics .. "/entities/network-chest.png",
  --   size = 64,
  --   scale = 0.5,
  -- }
  entity.minable.result = name

  local item = table.deepcopy(data.raw["item"][override_item_name])
  item.name = name
  item.place_result = name
  -- item.icon = Paths.graphics .. "/items/network-chest.png"
  item.size = 64

  local recipe = {
    name = name,
    type = "recipe",
    enabled = true,
    energy_required = 0.5,
    ingredients = {},
    result = name,
    result_count = 1,
  }

  data:extend({ entity, item, recipe })
end

M.main()
