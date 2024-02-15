local LogisticNetworkChestWindow = require "src.windows.LogisticNetworkChestWindow"
local LogisticNetworkChestEntity = require "src.entities.LogisticNetworkChestEntity"
local NetworkLoaderEntity = require "src.entities.NetworkLoaderEntity"
local NetworkTankPasteWindow = require "src.windows.NetworkTankPasteWindow"
local LargeNetworkTankWindow = require "src.windows.LargeNetworkTankWindow"
local MediumNetworkTankWindow = require "src.windows.MediumNetworkTankWindow"
local LargeNetworkTankEntity = require "src.entities.LargeNetworkTankEntity"
local MediumNetworkTankEntity = require "src.entities.MediumNetworkTankEntity"
local UpdatePlayerLogistics = require "src.UpdatePlayerLogistics"
local constants = require "src.constants"
local NetworkTankEntity = require "src.entities.NetworkTankEntity"
local NetworkTankWindow = require "src.windows.NetworkTankWindow"
local NetworkViewWindow = require "src.windows.NetworkViewWindow"
local NetworkLoaderWindow = require "src.windows.NetworkLoaderWindow"
local LargeNetworkChestEntity = require "src.entities.LargeNetworkChestEntity"
local LargeNetworkChestWindow = require "src.windows.LargeNetworkChestWindow"
local MediumNetworkChestEntity = require "src.entities.MediumNetworkChestEntity"
local MediumNetworkChestWindow = require "src.windows.MediumNetworkChestWindow"
local Heap = require "src.Heap"
local NetworkChestWindow = require "src.windows.NetworkChestWindow"
local GlobalState = require "src.GlobalState"
local NetworkChestEntity = require "src.entities.NetworkChestEntity"

local M = {}

local WINDOWS = {
  NetworkChestWindow,
  MediumNetworkChestWindow,
  LargeNetworkChestWindow,
  LogisticNetworkChestWindow,
  NetworkLoaderWindow,
  NetworkViewWindow,
  NetworkTankWindow,
  MediumNetworkTankWindow,
  LargeNetworkTankWindow,
  NetworkTankPasteWindow,
}

local ENTITIES = {
  NetworkChestEntity,
  MediumNetworkChestEntity,
  LargeNetworkChestEntity,
  LogisticNetworkChestEntity,
  NetworkTankEntity,
  MediumNetworkTankEntity,
  LargeNetworkTankEntity,
  NetworkLoaderEntity,
}

local entity_name_to_window_map = {}
for _, window in ipairs(WINDOWS) do
  if window.entity_name ~= nil then
    entity_name_to_window_map[window.entity_name] = window
  end
end

local window_name_to_window_map = {}
for _, window in ipairs(WINDOWS) do
  window_name_to_window_map[window.window_name] = window
end

local elem_handler_map = {}
for _, window in ipairs(WINDOWS) do
  local handler_map = {}
  for _, elem_handler in ipairs(window.elem_handlers) do
    if handler_map[elem_handler.event] == nil then
      handler_map[elem_handler.event] = {}
    end
    handler_map[elem_handler.event][elem_handler.elem_id] = elem_handler
  end
  elem_handler_map[window.window_name] = handler_map
end

local entity_name_to_entity_map = {}
for _, entity in ipairs(ENTITIES) do
  entity_name_to_entity_map[entity.entity_name] = entity
end

local function close_current_window(player, player_state)
  if player_state.window == nil then
    return
  end

  local window = window_name_to_window_map[player_state.window.name]
  if window.close_window ~= nil then
    window.close_window()
  end
  player_state.window.frame.destroy()
  player_state.window = nil
end

local function open_window(window, player, entity)
  local player_state = GlobalState.get_player_info(player.index)
  close_current_window(player, player_state)

  local window_state = {
    name = window.window_name,
    entity = entity,
  }
  player_state.window = window_state
  local frame = window.on_open_window(window_state, player, entity)
  frame.name = window.window_name
  window_state.frame = frame
  player.opened = frame
end

function M.on_gui_opened(event)
  -- if true then return end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end

  if event.gui_type == defines.gui_type.entity then
    local entity_name = event.entity.name
    local window = entity_name_to_window_map[entity_name]
    if window ~= nil then
      open_window(window, player, event.entity)
    end
  end
end

function M.on_gui_closed(event)
  local frame = event.element
  if frame == nil then
    return
  end

  local window = window_name_to_window_map[frame.name]
  if window ~= nil then
    local player_state = GlobalState.get_player_info(event.player_index)
    window.on_close_window(player_state.window)
    frame.destroy()
    player_state.window = nil
  end
end

local function handle_generic_gui_event(event, event_name)
  local elem_id = nil
  if event.element ~= nil and event.element.tags ~= nil then
    elem_id = event.element.tags.elem_id
  end
  if elem_id == nil then
    return
  end

  local player_state = GlobalState.get_player_info(event.player_index)
  if player_state.window == nil then
    return
  end
  local window_name = player_state.window.name

  if elem_handler_map[window_name] == nil then
    return
  end
  if elem_handler_map[window_name][event_name] == nil then
    return
  end
  if elem_handler_map[window_name][event_name][elem_id] == nil then
    return
  end

  local state = GlobalState.get_player_info(event.player_index).window
  elem_handler_map[window_name][event_name][elem_id].handler(event, state)
end

function M.on_gui_click(event)
  handle_generic_gui_event(event, "on_gui_click")
end

function M.on_gui_text_changed(event)
  handle_generic_gui_event(event, "on_gui_text_changed")
end

function M.on_gui_checked_state_changed(event)
  handle_generic_gui_event(event, "on_gui_checked_state_changed")
end

function M.on_gui_elem_changed(event)
  handle_generic_gui_event(event, "on_gui_elem_changed")
end

function M.on_gui_confirmed(event)
  handle_generic_gui_event(event, "on_gui_confirmed")
end

function M.on_gui_selected_tab_changed(event)
  handle_generic_gui_event(event, "on_gui_selected_tab_changed")
end

function M.on_gui_selection_state_changed(event)
  handle_generic_gui_event(event, "on_gui_selection_state_changed")
end

local function generic_on_create_entity(event)
  local entity = event.created_entity
  if entity == nil then
    entity = event.entity
  end

  local entity_def = entity_name_to_entity_map[entity.name]
  if entity_def ~= nil then
    local state = {
      type = entity.name,
      entity = entity,
    }

    -- restore settings from blueprint
    if event.tags ~= nil and event.tags.config ~= nil then
      state.config = event.tags.config
    end

    entity_def.on_create_entity(state)

    if not entity_def.do_not_add_to_update_queue then
      GlobalState.register_entity(entity.unit_number, state)
      Heap.insert(
        global.mod.update_queue,
        game.tick + constants.MIN_UPDATE_TICKS,
        entity.unit_number
      )
    end
  end
end

function M.on_built_entity(event)
  generic_on_create_entity(event)
end

function M.script_raised_built(event)
  generic_on_create_entity(event)
end

function M.on_entity_cloned(event)
  generic_on_create_entity(event)
end

function M.on_robot_built_entity(event)
  generic_on_create_entity(event)
end

function M.script_raised_revive(event)
  generic_on_create_entity(event)
end

local function generic_on_remove_entity(event)
  local entity = event.created_entity
  if entity == nil then
    entity = event.entity
  end

  local entity_def = entity_name_to_entity_map[entity.name]
  if entity_def ~= nil and entity_def.on_remove_entity ~= nil then
    entity_def.on_remove_entity(event)
  end
  if entity.unit_number ~= nil then
    GlobalState.unregister_entity(entity.unit_number)
  end
end

function M.on_pre_player_mined_item(event)
  generic_on_remove_entity(event)
end

function M.on_robot_mined_entity(event)
  generic_on_remove_entity(event)
end

function M.script_raised_destroy(event)
  generic_on_remove_entity(event)
end

function M.on_entity_died(event)
  generic_on_remove_entity(event)
end

function M.on_marked_for_deconstruction(event)
  local name = event.entity.name
  if entity_name_to_entity_map[name] ~= nil then
    local entity_def = entity_name_to_entity_map[name]
    if entity_def.on_marked_for_deconstruction ~= nil then
      entity_def.on_marked_for_deconstruction(event)
    end
  end
end

function M.on_post_entity_died(event)
end

function M.on_entity_settings_pasted(event)
end

function M.on_pre_entity_settings_pasted(event)
  local source = event.source
  local dest = event.destination
  if source.name == dest.name then
    local entity = entity_name_to_entity_map[source.name]
    if entity ~= nil and entity.copy_config ~= nil then
      local dest_info = GlobalState.get_entity_info(dest.unit_number)
      dest_info.config = entity.copy_config(source.unit_number)
    end
  else
    local dest_entity = entity_name_to_entity_map[dest.name]
    local player = game.get_player(event.player_index)
    if dest_entity ~= nil and player ~= nil and dest_entity.on_paste_settings ~= nil then
      dest_entity.on_paste_settings(source, dest, player)
    end
  end
end

-- copied from https://discord.com/channels/139677590393716737/306402592265732098/1112775784411705384
-- on the factorio discord
-- thanks raiguard :)
local function get_blueprint(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local bp = player.blueprint_to_setup
  if bp and bp.valid_for_read then
    return bp
  end

  bp = player.cursor_stack
  if not bp or not bp.valid_for_read then
    return nil
  end

  if bp.type == "blueprint-book" then
    local item_inventory = bp.get_inventory(defines.inventory.item_main)
    if item_inventory then
      bp = item_inventory[bp.active_index]
    else
      return
    end
  end

  return bp
end

function M.on_player_setup_blueprint(event)
  local blueprint = get_blueprint(event)
  if blueprint == nil then
    return
  end

  local entities = blueprint.get_blueprint_entities()
  if entities == nil then
    return
  end

  for _, entity in ipairs(entities) do
    local entity_def = entity_name_to_entity_map[entity.name]
    if entity_def ~= nil and entity_def.copy_config ~= nil then
      local real_entity = event.surface.find_entity(
        entity.name,
        entity.position
      )
      if real_entity ~= nil then
        local config = entity_def.copy_config(real_entity.unit_number)
        blueprint.set_blueprint_entity_tag(
          entity.entity_number,
          "config",
          config
        )
      end
    end
  end
end

function M.on_tick()
  -- called every tick
  GlobalState.setup()
  GlobalState.start_timer("On Tick")
  GlobalState.start_timer("Get Entities From Queue")
  local entities_to_update = {}
  while #entities_to_update < 20 do
    local top = Heap.peek(global.mod.update_queue)
    if top == nil or top.key >= game.tick then
      -- if top == nil then
      break
    end
    Heap.pop(global.mod.update_queue)
    table.insert(entities_to_update, top.value)
  end
  GlobalState.stop_timer("Get Entities From Queue")

  for _, entity_id in ipairs(entities_to_update) do
    local entity_info = GlobalState.get_entity_info(entity_id)
    if entity_info ~= nil then
      local entity_name = entity_info.type
      local entity_handler = entity_name_to_entity_map[entity_name]
      if entity_handler ~= nil then
        GlobalState.start_timer("Update Entity")
        local next_update_ticks = entity_handler.on_update(entity_info)
        local rand_delta = global.mod.rand() * 0.1 * next_update_ticks
        Heap.insert(
          global.mod.update_queue,
          game.tick + next_update_ticks + rand_delta,
          entity_id
        )
        GlobalState.stop_timer("Update Entity")
      end
    end
  end
  GlobalState.stop_timer("On Tick")
end

function M.on_tick_60()
  GlobalState.start_timer("Update Player Logistics")
  UpdatePlayerLogistics.update_player_logistics()
  GlobalState.stop_timer("Update Player Logistics")
end

function M.on_init()
  GlobalState.setup()
end

function M.in_open_network_view(event)
  local player = game.get_player(event.player_index)
  if player ~= nil then
    open_window(NetworkViewWindow, player, nil)
  end
end

return M
