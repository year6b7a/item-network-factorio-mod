local EventHandlers = require "src.EventHandlers"

local function main()
  -- create
  script.on_event(
    defines.events.on_built_entity,
    EventHandlers.on_built_entity
  )
  script.on_event(
    defines.events.script_raised_built,
    EventHandlers.script_raised_built
  )
  script.on_event(
    defines.events.on_entity_cloned,
    EventHandlers.on_entity_cloned
  )
  script.on_event(
    defines.events.on_robot_built_entity,
    EventHandlers.on_robot_built_entity
  )
  script.on_event(
    defines.events.script_raised_revive,
    EventHandlers.script_raised_revive
  )

  -- delete
  script.on_event(
    defines.events.on_pre_player_mined_item,
    EventHandlers.on_pre_player_mined_item
  )
  script.on_event(
    defines.events.on_robot_mined_entity,
    EventHandlers.on_robot_mined_entity
  )
  script.on_event(
    defines.events.script_raised_destroy,
    EventHandlers.script_raised_destroy
  )
  script.on_event(
    defines.events.on_entity_died,
    EventHandlers.on_entity_died
  )
  script.on_event(
    defines.events.on_marked_for_deconstruction,
    EventHandlers.on_marked_for_deconstruction
  )


  script.on_event(
    defines.events.on_post_entity_died,
    EventHandlers.on_post_entity_died
  )


  script.on_event(
    defines.events.on_entity_settings_pasted,
    EventHandlers.on_entity_settings_pasted
  )
  script.on_event(
    defines.events.on_pre_entity_settings_pasted,
    EventHandlers.on_pre_entity_settings_pasted
  )

  script.on_event(
    defines.events.on_player_setup_blueprint,
    EventHandlers.on_player_setup_blueprint
  )

  -- gui events
  script.on_event(
    defines.events.on_gui_click,
    EventHandlers.on_gui_click
  )
  script.on_event(
    defines.events.on_gui_opened,
    EventHandlers.on_gui_opened
  )
  script.on_event(
    defines.events.on_gui_closed,
    EventHandlers.on_gui_closed
  )
  script.on_event(
    defines.events.on_gui_text_changed,
    EventHandlers.on_gui_text_changed
  )
  script.on_event(
    defines.events.on_gui_elem_changed,
    EventHandlers.on_gui_elem_changed
  )
  script.on_event(
    defines.events.on_gui_checked_state_changed,
    EventHandlers.on_gui_checked_state_changed
  )
  script.on_event(
    defines.events.on_gui_confirmed,
    EventHandlers.on_gui_confirmed
  )
  script.on_event(
    defines.events.on_gui_selected_tab_changed,
    EventHandlers.on_gui_selected_tab_changed
  )
  script.on_event(
    defines.events.on_gui_selection_state_changed,
    EventHandlers.on_gui_selection_state_changed
  )

  -- custom events
  -- script.on_event(
  --   "in_confirm_dialog",
  --   NetworkChest.in_confirm_dialog
  -- )
  -- script.on_event(
  --   "in_cancel_dialog",
  --   NetworkChest.in_cancel_dialog
  -- )
  -- script.on_event(
  --   "in_open_network_view",
  --   NetworkChest.in_open_network_view
  -- )

  script.on_nth_tick(1, EventHandlers.on_tick)
  -- script.on_nth_tick(60, NetworkChest.onTick_60)
  -- script.on_nth_tick(60 * 3, NetworkChest.on_every_5_seconds)
  -- script.on_nth_tick(120, NetworkChest.service_sensors)

  script.on_init(EventHandlers.on_init)
end

main()
