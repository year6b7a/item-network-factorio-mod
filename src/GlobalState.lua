local Queue = require "src.Queue"

local M = {}

local setup_has_run = false

function M.setup()
  if setup_has_run then
    return
  end
  setup_has_run = true

  if global.mod == nil then
    global.mod = {
      rand = game.create_random_generator(),
      chests = {},
      scan_queue = Queue.new(),
      items = {},
    }
  end
  M.remove_old_ui()
  if global.mod.player_info == nil then
    global.mod.player_info = {}
  end
end

function M.remove_old_ui()
  if global.mod.network_chest_gui ~= nil then
    global.mod.network_chest_gui = nil
    for _, player in pairs(game.players) do
      local main_frame = player.gui.screen["network-chest-main-frame"]
      if main_frame ~= nil then
        game.print("deleting main frame")
        main_frame.destroy()
      end

      local main_frame = player.gui.screen["add-request"]
      if main_frame ~= nil then
        game.print("deleting main frame")
        main_frame.destroy()
      end
    end
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
  local info = M.get_chest_info(unit_number)
  if info == nil then
    return
  end
  global.mod.chests[unit_number].requests = requests
end

function M.get_item_count(item_name)
  return global.mod.items[item_name] or 0
end

function M.get_items()
  return global.mod.items
end

function M.set_item_count(item_name, count)
  if count <= 0 then
    global.mod.items[item_name] = nil
  else
    global.mod.items[item_name] = count
  end
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

function M.get_player_info(player_index)
  local info = global.mod.player_info[player_index]
  if info == nil then
    info = {}
    global.mod.player_info[player_index] = info
  end
  return info
end

function M.get_player_info_map()
  return global.mod.player_info
end

function M.get_ui_state(player_index)
  local info = M.get_player_info(player_index)
  if info.ui == nil then
    info.ui = {}
  end
  return info.ui
end

return M
