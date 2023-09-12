local constants = require "src.constants"
local Paths = require "src.Paths"
local Hotkeys = require "src.Hotkeys"

local M = {}

function M.main()
  M.add_network_chest()
  M.add_loader()
  M.add_network_tank()
  M.add_network_sensor()
  M.add_large_network_chest()

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
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
    window_bounding_box = { { -1, -0.5 }, { 1, 0.5 } },
    drawing_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    fluid_box = {
      base_area = constants.TANK_AREA,
      height = constants.TANK_HEIGHT,
      pipe_connections =
      {
        { position = { 0, 1 }, type = "input-output" },
      },
    },
    two_direction_only = false,
    pictures = {
      picture = {
        sheet = {
          filename = Paths.graphics .. "/entities/network-tank.png",
          size = 64,
          scale = 0.5,
        },
      },
      window_background = {
        filename = Paths.graphics .. "/empty-pixel.png",
        size = 1,
      },
      fluid_background = {
        filename = Paths.graphics .. "/entities/fluid-background.png",
        size = { 32, 32 },
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
    additional_pastable_entities = { "network-tank" },
    max_health = 200,
  }

  local item = table.deepcopy(data.raw["item"][override_item_name])
  item.name = name
  item.place_result = name
  item.icon = Paths.graphics .. "/items/network-tank.png"
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
  recipe.name = name
  recipe.result = name
  recipe.enabled = true

  data:extend({ entity, item, recipe })
end

function M.add_large_network_chest()
  local name = "large-network-chest"

  local reference_entity = data.raw["container"]["iron-chest"]

  local entity = {
    type = "container",
    name = name,
    icon = "__base__/graphics/icons/iron-chest.png",
    icon_size = 64,
    icon_mipmaps = 4,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.2, result = "large-network-chest" },
    max_health = 200,
    open_sound = {
      filename = "__base__/sound/metallic-chest-open.ogg",
      volume = 0.43,
    },
    close_sound = {
      filename = "__base__/sound/metallic-chest-close.ogg",
      volume = 0.43,
    },
    resistances =
    {
      {
        type = "fire",
        percent = 80,
      },
      {
        type = "impact",
        percent = 30,
      },
    },
    collision_box = { { -1.35, -1.35 }, { 1.35, 1.35 } },
    selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } },
    fast_replaceable_group = "container",
    inventory_size = 128,
    picture =
    {
      layers =
      {
        {
          filename = "__base__/graphics/entity/iron-chest/iron-chest.png",
          priority = "extra-high",
          width = 34,
          height = 38,
          shift = util.by_pixel(0, -0.5),
          hr_version =
          {
            filename = "__base__/graphics/entity/iron-chest/hr-iron-chest.png",
            priority = "extra-high",
            width = 66,
            height = 76,
            shift = util.by_pixel(-0.5, -0.5),
            scale = 0.5,
          },
        },
        {
          filename = "__base__/graphics/entity/iron-chest/iron-chest-shadow.png",
          priority = "extra-high",
          width = 56,
          height = 26,
          shift = util.by_pixel(10, 6.5),
          draw_as_shadow = true,
          hr_version =
          {
            filename =
            "__base__/graphics/entity/iron-chest/hr-iron-chest-shadow.png",
            priority = "extra-high",
            width = 110,
            height = 50,
            shift = util.by_pixel(10.5, 6),
            draw_as_shadow = true,
            scale = 0.5,
          },
        },
      },
    },
    circuit_wire_connection_point = reference_entity
      .circuit_wire_connection_point,
    circuit_connector_sprites = reference_entity.circuit_connector_sprites,
    circuit_wire_max_distance = reference_entity.circuit_wire_max_distance,
  }

  local item = {
    name = name,
    type = "item",
    place_result = name,
    icon = data.raw["item"]["iron-chest"].icon,
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

M.main()
