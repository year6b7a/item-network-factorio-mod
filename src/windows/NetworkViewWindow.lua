local GlobalState = require "src.GlobalState"
local Helpers = require "src.Helpers"
local Timer = require "src.Timer"
local Priority = require "src.Priority"
local M = {}

M.window_name = "cbe5507815be529f2ee8cc652a7d4cbe"
M.WIDTH = 500
M.HEIGHT = 800
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
    --[[
    This handles a click on an item sprite in the item view.
    If the cursor has something in it, then the cursor content is dumped into the item network.
    If the cursor is empty then we grab something from the item network.
      left-click grabs one item.
      shift + left-click grabs one stack.
      ctrl + left-click grabs it all.
    ]]
    local element = event.element
    local player = game.players[event.player_index]
    if player == nil then
      return
    end
    local inv = player.get_main_inventory()
    if inv == nil then
      return
    end

    -- if we have an empty cursor, then we are taking items, which requires a valid target
    if player.is_cursor_empty() then
      local item_name = event.element.tags.item
      if item_name == nil then
        return
      end

      local network_count = GlobalState.get_item_info(item_name).amount
      local stack_size = game.item_prototypes[item_name].stack_size

      if event.button == defines.mouse_button_type.left then
        -- shift moves a stack, non-shift moves 1 item
        local n_transfer = 1
        if event.shift then
          n_transfer = stack_size
        elseif event.control then
          n_transfer = network_count
        end
        n_transfer = math.min(network_count, n_transfer)
        -- move one item or stack to player inventory
        if n_transfer > 0 then
          local n_moved = inv.insert({ name = item_name, count = n_transfer })
          if n_moved > 0 then
            local withdrawn = GlobalState.withdraw_item2(
              item_name,
              n_moved,
              Priority.HIGH
            )
            assert(n_moved == withdrawn)
            element.number = network_count - n_moved
          end
        end
      end
      return
    else
      -- There is a stack in the cursor. Deposit it.
      local cursor_stack = player.cursor_stack
      if not cursor_stack or not cursor_stack.valid_for_read then
        return
      end

      -- don't deposit tracked entities (can be unique)
      if cursor_stack.item_number ~= nil then
        game.print(string.format(
          "Unable to deposit %s because it might be a vehicle with items that will be lost.",
          cursor_stack.name))
        return
      end

      if event.button == defines.mouse_button_type.left then
        GlobalState.deposit_item2(
          cursor_stack.name,
          cursor_stack.count,
          Priority.ALWAYS_INSERT
        )
        cursor_stack.clear()
        player.clear_cursor()
        M.render_selected_tab(state)
      end
    end
  end,
})

local FLUID_SPRITE_BTN_ID = "f40451f7ff4908eab256c3cae2073587"
table.insert(M.elem_handlers, {
  elem_id = FLUID_SPRITE_BTN_ID,
  event = "on_gui_click",
  handler = function(event, state)
    state.selected_fluid = {
      fluid_name = event.element.tags.fluid_name,
      fluid_temp = event.element.tags.fluid_temp,
    }
    M.render_selected_tab(state)
  end,
})

local ITEM_SHORTAGE_SPRITE_BTN_ID = "0fe523a0d7ebe2ecf19d3a5d86237624"
table.insert(M.elem_handlers, {
  elem_id = ITEM_SHORTAGE_SPRITE_BTN_ID,
  event = "on_gui_click",
  handler = function(event, state)
    local player = game.players[event.player_index]
    if player == nil then
      return
    end

    local item = event.element.tags.item
    local entity_map = GlobalState.get_item_shortage_entities(item)
    for _, info in pairs(entity_map) do
      if info.entity.valid then
        player.add_custom_alert(
          info.entity,
          { type = "item", name = item },
          "Entity is missing item",
          true
        )
      end
    end
  end,
})

local FLUID_SHORTAGE_SPRITE_BTN_ID = "f602cec6caf4484d0b036bc47d10db01"
table.insert(M.elem_handlers, {
  elem_id = FLUID_SHORTAGE_SPRITE_BTN_ID,
  event = "on_gui_click",
  handler = function(event, state)
    local player = game.players[event.player_index]
    if player == nil then
      return
    end

    local fluid = event.element.tags.fluid
    local temp = event.element.tags.temp

    local entity_map = GlobalState.get_fluid_shortage_entities(fluid, temp)
    for _, info in pairs(entity_map) do
      if info.entity.valid then
        player.add_custom_alert(
          info.entity,
          { type = "fluid", name = fluid },
          "Entity is missing fluid",
          true
        )
      end
    end
  end,
})

local GLOBAL_LIMIT_INPUT_ID = "f255a84c7337ef62619b01c3b55c2b45"
table.insert(M.elem_handlers, {
  elem_id = GLOBAL_LIMIT_INPUT_ID,
  event = "on_gui_text_changed",
  handler = function(event, state)
    if state.selected_fluid ~= nil then
      local info = GlobalState.get_fluid_info(
        state.selected_fluid.fluid_name,
        state.selected_fluid.fluid_temp
      )
      local value = tonumber(event.element.text)
      info.max_deposit_limit = value
    end
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
      info.deposit_limit,
      info.max_deposit_limit == nil and "None" or
      info.max_deposit_limit,
    },
    tags = {
      elem_id = ITEM_SPRITE_BTN_ID,
      item = item_name,
    },
    number = info.amount,
  }
end

local function get_missing_item_icon(item_name, missing_count)
  local item_proto = game.item_prototypes[item_name]
  return {
    type = "sprite-button",
    elem_type = "item",
    sprite = "item/" .. item_name,
    tooltip = {
      "",
      item_proto.localised_name,
    },
    tags = {
      elem_id = ITEM_SHORTAGE_SPRITE_BTN_ID,
      item = item_name,
    },
    number = missing_count,
  }
end

local function get_missing_fluid_icon(fluid, temp, missing_count)
  local fluid_proto = game.fluid_prototypes[fluid]
  return {
    type = "sprite-button",
    elem_type = "fluid",
    sprite = "fluid/" .. fluid,
    tooltip = {
      "in_nv.fluid_shortage_sprite_btn_tooltip",
      fluid_proto.localised_name,
      { "format-degrees-c", string.format("%.0f", temp) },
    },
    tags = {
      elem_id = FLUID_SHORTAGE_SPRITE_BTN_ID,
      fluid = fluid,
      temp = temp,
    },
    number = missing_count,
  }
end

local function get_fluid_icon(state, info, fluid_name, temp)
  local proto = game.fluid_prototypes[fluid_name]

  local highlighted = (
    state.selected_fluid ~= nil
    and state.selected_fluid.fluid_name == fluid_name
    and state.selected_fluid.fluid_temp == temp
  )

  return {
    type = "sprite-button",
    elem_type = "fluid",
    sprite = "fluid/" .. fluid_name,
    tooltip = {
      "in_nv.fluid_sprite_btn_tooltip",
      proto.localised_name,
      string.format("%.0f", info.amount),
      { "format-degrees-c", string.format("%.0f", temp) },
      info.deposit_limit,
      info.max_deposit_limit == nil and "None" or
      info.max_deposit_limit,
    },
    tags = {
      elem_id = FLUID_SPRITE_BTN_ID,
      fluid_name = fluid_name,
      fluid_temp = temp,
    },
    number = info.amount,
    toggled = highlighted,
  }
end

local function items_list_sort(left, right)
  if left.static_idx ~= nil then
    if right.static_idx ~= nil then
      return left.static_idx < right.static_idx
    else
      return true
    end
  elseif right.static_idx ~= nil then
    return false
  else
    return left.number > right.number
  end
end

local function sort_items(items)
  table.sort(items, items_list_sort)
end

local function render_rows_of_icons(main_flow, icons)
  sort_items(icons)
  local item_flow = main_flow.add({
    type = "scroll-pane",
    direction = "vertical",
    vertical_scroll_policy = "always",
  })
  item_flow.style.size = { width = M.WIDTH - 42, height = M.HEIGHT - 408 }
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
    for fluid_name, temp_map in pairs(fluids) do
      for temp, info in pairs(temp_map) do
        if info.amount > 0 then
          table.insert(icons, get_fluid_icon(state, info, fluid_name, temp))
        end
      end
    end
    render_rows_of_icons(main_flow, icons)

    if state.selected_fluid ~= nil then
      local fluid_info = GlobalState.get_fluid_info(
        state.selected_fluid.fluid_name,
        state.selected_fluid.fluid_temp
      )

      local global_limit_flow = main_flow.add({
        type = "flow",
        direction = "horizontal",
      })

      global_limit_flow.add({ type = "label", caption = "Global Deposit Limit" })

      local field = global_limit_flow.add({
        type = "textfield",
        numeric = true,
        allow_decimal = false,
        allow_negative = false,
        tags = { elem_id = GLOBAL_LIMIT_INPUT_ID },
      })
      if fluid_info.max_deposit_limit ~= nil then
        field.text = string.format("%s", fluid_info.max_deposit_limit)
      end
      field.style.width = 150
    end
  elseif selected_tab_idx == 3 then
    -- shortages
    local missing_items = GlobalState.get_item_shortages()
    local icons = {}
    for item, amount in pairs(missing_items) do
      table.insert(icons, get_missing_item_icon(
        item,
        amount
      ))
    end

    local missing_fluids = GlobalState.get_fluid_shortages()
    for fluid, temp_map in pairs(missing_fluids) do
      for temp, amount in pairs(temp_map) do
        table.insert(icons, get_missing_fluid_icon(
          fluid,
          temp,
          amount
        ))
      end
    end

    render_rows_of_icons(main_flow, icons)
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
