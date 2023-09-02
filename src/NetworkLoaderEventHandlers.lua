local UiConstants = require "src.UiConstants"
local NetworkLoaderUi = require "src.NetworkLoaderUi"
local GlobalState = require "src.GlobalState"

local M = {}

M.event_handlers = {
  {
    name = UiConstants.NL_FILTERED_ITEM_BTN,
    event = "on_gui_elem_changed",
    handler = function(event, element)
      local player = game.get_player(event.player_index)
      local ui = GlobalState.get_ui_state(event.player_index)
      local entity = ui.loader.entity
      entity.set_filter(1, element.elem_value)
      NetworkLoaderUi.reset(player, ui)
    end,
  },
  {
    name = UiConstants.NL_SUGGESTED_FILTER_BTN,
    event = "on_gui_click",
    handler = function(event, element)
      local player = game.get_player(event.player_index)
      local ui = GlobalState.get_ui_state(event.player_index)
      local entity = ui.loader.entity
      entity.set_filter(1, element.tags.item)
      NetworkLoaderUi.reset(player, ui)
    end,
  },
}

return M
