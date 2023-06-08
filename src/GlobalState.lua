local Queue = require "src.Queue"

local M = {}

function M.setup()
  if global.mod == nil then
    global.mod = {
      rand = game.create_random_generator(),
      chests = {},
      scan_queue = Queue.new(),
      items = {},
    }
  end
end

function M.rand_hex(len)
  local chars = {}
  for _ = 1, len do
    table.insert(chars, string.format("%x", math.floor(global.mod.rand() * 16)))
  end
  return table.concat(chars, "")
end

function M.shuffle(list)
  for i = #list, 2, -1 do
    local j = global.mod.rand(i)
    list[i], list[j] = list[j], list[i]
  end
end

function M.register_chest_entity(entity, requests)
  if requests == nil then
    requests = {}
  end

  if global.mod.chests[entity.unit_number] ~= nil then
    return
  end

  Queue.push(global.mod.scan_queue, entity.unit_number)
  global.mod.chests[entity.unit_number] = {
    entity = entity,
    requests = requests,
  }
end

function M.delete_chest_entity(unit_number)
  global.mod.chests[unit_number] = nil
end

function M.get_chest_info(unit_number)
  return global.mod.chests[unit_number]
end

function M.copy_chest_requests(source_unit_number, dest_unit_number)
  global.mod.chests[dest_unit_number].requests =
    global.mod.chests[source_unit_number].requests
end

function M.set_chest_requests(unit_number, requests)
  global.mod.chests[unit_number].requests = requests
end

function M.get_item_count(item_name)
  return global.mod.items[item_name] or 0
end

function M.set_item_count(item_name, count)
  global.mod.items[item_name] = count
end

function M.increment_item_count(item_name, delta)
  local count = M.get_item_count(item_name)
  global.mod.items[item_name] = count + delta
end

function M.get_scan_queue_size()
  return global.mod.scan_queue.size
end

function M.scan_queue_pop()
  return Queue.pop_random(global.mod.scan_queue, global.mod.rand)
end

function M.scan_queue_push(unit_number)
  Queue.push(global.mod.scan_queue, unit_number)
end

return M
