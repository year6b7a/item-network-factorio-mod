local GlobalState = require "src.GlobalState"
local Helpers = require "src.Helpers"
local Timer = require "src.Timer"
local M = {}

M.window_name = "cbe5507815be529f2ee8cc652a7d4cbe"
M.WIDTH = 500
M.HEIGHT = 500
M.elem_handlers = {}

local REFRESH_BTN_ID = "e71d0cba6dfebf9aaa9c266cc8475a7f"
table.insert(M.elem_handlers, {
  elem_id = REFRESH_BTN_ID,
  event = "on_gui_click",
  handler = function(event, state)
    M.render_selected_tab(state)
  end,
})

local CLOSE_BTN_ID = "fecf8d784436453d7bc9dcc68a9da50a"
table.insert(M.elem_handlers, {
  elem_id = CLOSE_BTN_ID,
  event = "on_gui_click",
  handler = function(event, state)
    state.frame.destroy()
  end,
})

local TABBED_PANE_ID = "b7f3893428b19fe74284f2c8bcf255d9"
table.insert(M.elem_handlers, {
  elem_id = TABBED_PANE_ID,
  event = "on_gui_selected_tab_changed",
  handler = function(event, state)
    M.render_selected_tab(state)
  end,
})

local ITEM_SPRITE_BTN_ID = "a36db9fcfc3492ca05406880cd6e020f"
table.insert(M.elem_handlers, {
  elem_id = ITEM_SPRITE_BTN_ID,
  event = "on_gui_click",
  handler = function(event, state)
  end,
})

local FLUID_SPRITE_BTN_ID = "f40451f7ff4908eab256c3cae2073587"
table.insert(M.elem_handlers, {
  elem_id = FLUID_SPRITE_BTN_ID,
  event = "on_gui_click",
  handler = function(event, state)
  end,
})

local function build_item_page(parent)
  local main_flow = parent.add({
    type = "flow",
    direction = "vertical",
  })

  return main_flow
end

function M.on_open_window(state, player, entity)
  local frame = player.gui.screen.add({
    type = "frame",
    name = M.window_name,
  })
  frame.style.size = { M.WIDTH, M.HEIGHT }
  frame.auto_center = true

  local main_flow = frame.add({
    type = "flow",
    direction = "vertical",
  })

  local header_flow = main_flow.add({
    type = "flow",
    direction = "horizontal",
  })
  header_flow.drag_target = frame

  header_flow.add {
    type = "label",
    caption = "Network View",
    style = "frame_title",
    ignored_by_interaction = true,
  }

  local header_drag = header_flow.add {
    type = "empty-widget",
    style = "draggable_space",
    ignored_by_interaction = true,
  }
  header_drag.style.size = { M.WIDTH - 210, 20 }

  header_flow.add {
    type = "sprite-button",
    sprite = "utility/refresh",
    style = "frame_action_button",
    tooltip = { "gui.refresh" },
    tags = { elem_id = REFRESH_BTN_ID },
  }

  header_flow.add {
    type = "sprite-button",
    sprite = "utility/close_white",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    style = "close_button",
    tags = { elem_id = CLOSE_BTN_ID },
  }

  -- add tabbed stuff
  local tabbed_pane = main_flow.add {
    type = "tabbed-pane",
    tags = { elem_id = TABBED_PANE_ID },
  }

  local tab_item = tabbed_pane.add { type = "tab", caption = "Items" }
  local tab_fluid = tabbed_pane.add { type = "tab", caption = "Fluids" }
  local tab_shortage = tabbed_pane.add { type = "tab", caption = "Shortages" }


  tabbed_pane.add_tab(tab_item, build_item_page(tabbed_pane))
  tabbed_pane.add_tab(tab_fluid, build_item_page(tabbed_pane))
  tabbed_pane.add_tab(tab_shortage, build_item_page(tabbed_pane))

  local enable_perf_tab = settings.get_player_settings(player.index)
    ["item-network-enable-performance-tab"].value
  if enable_perf_tab then
    local tab_info = tabbed_pane.add { type = "tab", caption = "Performance" }
    tabbed_pane.add_tab(tab_info, build_item_page(tabbed_pane))
  end

  -- select "items" (not really needed, as that is the default)
  tabbed_pane.selected_tab_index = 1

  state.frame = frame
  state.tabbed_pane = tabbed_pane

  M.render_selected_tab(state)

  return frame
end

function M.on_close_window(state)
end

local function get_item_icon(item_name, info)
  local item_proto = game.item_prototypes[item_name]
  return {
    type = "sprite-button",
    elem_type = "item",
    sprite = "item/" .. item_name,
    tooltip = {
      "in_nv.item_sprite_btn_tooltip",
      item_proto.localised_name,
      info.amount,
    },
    tags = {
      elem_id = ITEM_SPRITE_BTN_ID,
      item = item_name,
    },
    number = info.amount,
  }
end

local function get_fluid_icon(info)
  local proto = game.fluid_prototypes[info.fluid_name]
  return {
    type = "sprite-button",
    elem_type = "fluid",
    sprite = "fluid/" .. info.fluid_name,
    tooltip = {
      "in_nv.fluid_sprite_btn_tooltip",
      proto.localised_name,
      string.format("%.0f", info.amount),
      { "format-degrees-c", string.format("%.0f", info.fluid_temp) },
    },
    tags = {
      elem_id = FLUID_SPRITE_BTN_ID,
      fluid_name = info.fluid_name,
      fluid_temp = info.fluid_temp,
    },
    number = info.amount,
  }
end

local function render_rows_of_icons(main_flow, icons)
  local item_flow = main_flow.add({
    type = "scroll-pane",
    direction = "vertical",
    vertical_scroll_policy = "always",
  })
  item_flow.style.size = { width = M.WIDTH - 42, height = M.HEIGHT - 108 }
  item_flow.style.left_margin = 5

  local rows = Helpers.split_list_by_batch_size(icons, 10)
  for _, row in ipairs(rows) do
    local item_h_stack = item_flow.add({
      type = "flow",
      diraction = "horizontal",
    })
    for _, icon in ipairs(row) do
      local icon_inst = item_h_stack.add(icon)
      icon_inst.number = icon.number
    end
  end
end

function M.render_selected_tab(state)
  -- clear all tabs
  for _, tab in ipairs(state.tabbed_pane.tabs) do
    tab.content.clear()
  end
  local selected_tab_idx = state.tabbed_pane.selected_tab_index
  local tab_content = state.tabbed_pane.tabs[selected_tab_idx].content
  if tab_content == nil then
    return
  end

  local main_flow = tab_content.add({
    type = "flow",
    direction = "vertical",
  })
  main_flow.style.size = { width = M.WIDTH - 33, height = M.HEIGHT - 105 }

  if selected_tab_idx == 1 then
    -- items
    local icons = {}
    local items = GlobalState.get_items()
    for item_name, info in pairs(items) do
      if info.amount > 0 then
        table.insert(icons, get_item_icon(item_name, info))
      end
    end
    render_rows_of_icons(main_flow, icons)
  elseif selected_tab_idx == 2 then
    -- fluids
    local icons = {}
    local fluids = GlobalState.get_fluids()
    for _, info in pairs(fluids) do
      if info.amount > 0 then
        table.insert(icons, get_fluid_icon(info))
      end
    end
    render_rows_of_icons(main_flow, icons)
  elseif selected_tab_idx == 3 then
    -- shortages
  elseif selected_tab_idx == 4 then
    -- performance
    for _, timer_info in ipairs(GlobalState.get_timers()) do
      local timer_flow = main_flow.add({
        type = "flow", direction = "horizontal",
      })
      timer_flow.add({
        type = "label",
        caption = {
          "",
          timer_info.name,
          " (",
          timer_info.timer.count,
          "):",
        },
      })
      local timer_label = timer_flow.add({ type = "label" })
      timer_label.caption = Timer.get_average(timer_info.timer)
    end
  end
end

return M
