local constants = require "src.constants"
local Paths = require "src.Paths"
local Hotkeys = require "src.Hotkeys"

local M = {}

local RECIPE_PREFIX = "";
local IRON_PLATE = "iron-plate"
local RECIPE_CATEGORY = nil

if mods["nullius"] ~= nil then
  RECIPE_PREFIX = "nullius-"
  IRON_PLATE = "nullius-iron-plate"
  RECIPE_CATEGORY = "medium-crafting"
end

function M.main()
  M.add_network_chests()
  M.add_loader()
  M.add_network_tanks()
  M.add_network_sensor()

  data:extend(Hotkeys.hotkeys)
end

local function inner_add_network_chest(name, size, order, n_slots)
  local override_item_name = "iron-chest"
  local overwrite_prototype = "container"

  local entity = table.deepcopy(data.raw[overwrite_prototype]
    [override_item_name])
  entity.name = name
  entity.picture = {
    filename = Paths.graphics .. "/entities/network-chest.png",
    size = 64,
    scale = size * 0.5,
  }
  entity.inventory_size = n_slots
  entity.inventory_type = "with_filters_and_bar"
  entity.minable.result = name
  local collision_size = size * 0.5 - 0.15
  entity.collision_box = {
    { -collision_size, -collision_size },
    { collision_size,  collision_size },
  }
  local selection_size = size * 0.5
  entity.selection_box = {
    { -selection_size, -selection_size },
    { selection_size,  selection_size },
  }
  local drawing_size = size * 0.5
  entity.drawing_box = {
    { -drawing_size, -drawing_size },
    { drawing_size,  drawing_size },
  }

  local item = table.deepcopy(data.raw["item"][override_item_name])
  item.name = name
  item.place_result = name
  item.icon = Paths.graphics .. "/items/" .. name .. ".png"
  item.size = 64
  item.order = item.order .. order

  local recipe = {
    name = RECIPE_PREFIX .. name,
    type = "recipe",
    enabled = true,
    category = RECIPE_CATEGORY,
    energy_required = 0.5,
    ingredients = {
      { type = "item", name = IRON_PLATE, amount = 5 },
    },
    result = name,
    result_count = 1,
  }

  data:extend({ entity, item, recipe })
end

function M.add_network_chests()
  inner_add_network_chest("network-chest", 1, "0", 48)
  inner_add_network_chest("medium-network-chest", 3, "1", 96)
  inner_add_network_chest("large-network-chest", 5, "2", 256)
end

function M.add_loader()
  local name = "network-loader"

  local entity = {
    name = "network-loader",
    type = "loader-1x1",
    icon = Paths.graphics .. "/entities/express-loader.png",
    icon_size = 64,
    flags = { "placeable-neutral", "player-creation",
      "fast-replaceable-no-build-while-moving" },
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
    fast_replaceable_group = "loader",
    filter_count = 1,
    -- https://wiki.factorio.com/Prototype/TransportBeltConnectable#speed
    -- 360 items / sec
    speed = 0.75,
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
    se_allow_in_space = true,
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
    name = RECIPE_PREFIX .. name,
    type = "recipe",
    enabled = true,
    category = RECIPE_CATEGORY,
    energy_required = 0.5,
    ingredients = {
      { type = "item", name = IRON_PLATE, amount = 5 },
    },
    result = name,
    result_count = 1,
  }

  data:extend({ entity, item, recipe })
end

function M.add_network_tanks()
  M.add_network_tank(
    "network-tank", 1, "0", 5,
    { { 0, 1 } }
  )
  M.add_network_tank(
    "medium-network-tank", 1, "1", 250,
    { { 0, 1 } }
  )
  M.add_network_tank(
    "large-network-tank", 1, "2", 1000,
    { { 0, 1 } }
  )
end

function M.add_network_tank(name, size, order, area, positions)
  local override_item_name = "storage-tank"

  local collision_size = size * 0.5 - 0.15
  local selection_size = size * 0.5
  local drawing_size = size * 0.5

  local pipe_connections = {}
  for _, pos in ipairs(positions) do
    table.insert(pipe_connections, { position = pos, type = "input-output" })
  end

  local entity = {
    name = name,
    type = "storage-tank",
    flags = {
      "placeable-neutral",
      "player-creation",
      "fast-replaceable-no-build-while-moving",
    },
    icon = Paths.graphics .. "/entities/network-tank.png",
    icon_size = 64,
    selection_box = {
      { -selection_size, -selection_size },
      { selection_size,  selection_size },
    },
    collision_box = {
      { -collision_size, -collision_size },
      { collision_size,  collision_size },
    },
    window_bounding_box = {
      { -0.5, -0.5 },
      { 0.5,  0.5 },
    },
    drawing_box = {
      { -drawing_size, -drawing_size },
      { drawing_size,  drawing_size },
    },
    fluid_box = {
      base_area = area,
      height = constants.TANK_HEIGHT,
      pipe_connections = pipe_connections,
    },
    two_direction_only = false,
    pictures = {
      picture = {
        sheet = {
          filename = Paths.graphics .. "/entities/network-tank.png",
          size = 64,
          scale = size * 0.5,
        },
      },
      window_background = {
        filename = Paths.graphics .. "/empty-pixel.png",
        size = 1,
      },
      fluid_background = {
        filename = Paths.graphics .. "/entities/fluid-background.png",
        size = { 32, 32 },
        scale = size * 0.7,
      },
      flow_sprite = {
        filename = Paths.graphics .. "/empty-pixel.png",
        size = 1,
      },
      gas_flow = {
        filename = Paths.graphics .. "/empty-pixel.png",
        size = 1,
      },
    },
    flow_length_in_ticks = 1,
    minable = {
      mining_time = 0.5,
      result = name,
    },
    se_allow_in_space = true,
    allow_copy_paste = true,
    max_health = 200,
  }

  local item = table.deepcopy(data.raw["item"][override_item_name])
  item.name = name
  item.place_result = name
  item.icon = Paths.graphics .. "/items/" .. name .. ".png"
  item.size = 64
  item.order = item.order .. order

  local recipe = {
    name = RECIPE_PREFIX .. name,
    type = "recipe",
    enabled = true,
    category = RECIPE_CATEGORY,
    energy_required = 0.5,
    ingredients = {
      { type = "item", name = IRON_PLATE, amount = 5 },
    },
    result = name,
    result_count = 1,
  }

  data:extend({ entity, item, recipe })
end

function M.add_network_sensor()
  local name = "network-sensor"
  local override_item_name = "constant-combinator"
  local override_prototype = "constant-combinator"

  local entity = table.deepcopy(data.raw[override_prototype][override_item_name])
  entity.name = name
  entity.minable.result = name
  -- Need enough to hold every item we might build
  -- We could scan in data-final-fixes to get a more accurate count, but that is ~1700 items.
  entity.item_slot_count = 1000

  local item = table.deepcopy(data.raw["item"][override_item_name])
  item.name = name
  item.place_result = name
  item.order = item.order .. "2"

  local recipe = table.deepcopy(data.raw["recipe"][override_item_name])
  recipe.name = RECIPE_PREFIX .. name
  recipe.result = name
  recipe.enabled = true
  recipe.category = RECIPE_CATEGORY

  data:extend({ entity, item, recipe })
end

M.main()
