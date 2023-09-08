local Queue = require "src.Queue"
local NetworkChest = require "src.NetworkChest"
local GlobalState = require "src.GlobalState"
local constants = require "src.constants"

describe("NetworkChest", function()
  it("import works correctly", function()
    assert.truthy(NetworkChest ~= nil)
  end)
end)

local function create_mock_chest(opts)
  if opts.valid == nil then
    opts.valid = true
  end

  local inv_size = constants.NUM_INVENTORY_SLOTS
  local bar = inv_size
  local slots = {}
  for _ = 1, inv_size do
    table.insert(slots, {})
  end

  local output_inventory = {
    get_contents = function()
      local contents = {}
      for _, slot in ipairs(slots) do
        if slot.name ~= nil then
          local count = contents[slot.name] or 0
          contents[slot.name] = count + slot.count
        end
      end
      return contents
    end,
    clear = function()
      for _, slot in ipairs(slots) do
        slot.name = nil
        slot.count = nil
      end
    end,
    set_filter = function(slot_idx, item)
      assert(1 <= slot_idx and slot_idx <= inv_size)
      slots[slot_idx].filter = item
    end,
    set_bar = function(bar_idx)
      bar = bar_idx
    end,
    insert = function(item_stack)
      local stack_size = game.item_prototypes[item_stack.name].stack_size
      for slot_idx = 1, bar do
        local slot = slots[slot_idx]
        if slot.name == item_stack.name and slot.count < stack_size then
          local final_count = math.min(stack_size, slot.count + item_stack.count)
          local n_inserted = final_count - slot.count
          slot.count = final_count
          return n_inserted
        end
      end
      return 0
    end,
  }

  local entity = {
    unit_number = opts.unit_number,
    valid = opts.valid,
    to_be_deconstructed = function()
      return false
    end,
    get_output_inventory = function()
      return output_inventory
    end,
  }
  return entity
end

local function create_mock_profiler()
  return {
    restart = function() end,
    stop = function() end,
  }
end


describe("update_network", function()
  local function get_filtered_entity_prototypes()
    return {
      ["logistic-requester-chest"] = { logistic_mode = "requester" },
      ["logistic-buffer-chest"] = { logistic_mode = "buffer" },
      ["logistic-provider-chest"] = { logistic_mode = "provider" },
    }
  end

  local function create_random_generator()
    return function(max)
      return max
    end
  end

  local settings = {
    global = {
      ["item-network-number-of-entities-per-tick"] = { value = 20 },
    },
  }

  it("empty queue", function()
    _G.global = {}
    _G.game = {
      create_random_generator = create_random_generator,
      print = function() end,
      get_filtered_entity_prototypes = get_filtered_entity_prototypes,
      surfaces = {},
      create_profiler = create_mock_profiler,
    }
    _G.settings = settings
    GlobalState.inner_setup()

    assert.are.same(global.mod.scan_queue.size, 0)

    NetworkChest.update_queue()
  end)

  it("single entity", function()
    _G.global = {}
    _G.game = {
      create_random_generator = create_random_generator,
      print = function() end,
      get_filtered_entity_prototypes = get_filtered_entity_prototypes,
      surfaces = {},
      create_profiler = create_mock_profiler,
    }
    _G.settings = settings
    GlobalState.inner_setup()

    NetworkChest.on_create({}, create_mock_chest({ unit_number = 100 }))

    assert.are.same(global.mod.scan_queue.size, 1)
    NetworkChest.update_queue()
    assert.are.same(global.mod.scan_queue.size, 1)
  end)
end)
