local NetworkChest = require "NetworkChest"



function main()
  -- create
  script.on_event(
    defines.events.on_built_entity,
    NetworkChest.on_built_entity
  )
  script.on_event(
    defines.events.script_raised_built,
    NetworkChest.script_raised_built
  )
  script.on_event(
    defines.events.on_entity_cloned,
    NetworkChest.on_entity_cloned
  )
  script.on_event(
    defines.events.on_robot_built_entity,
    NetworkChest.on_robot_built_entity
  )
  script.on_event(
    defines.events.script_raised_revive,
    NetworkChest.script_raised_revive
  )

  -- delete
  script.on_event(
    defines.events.on_player_mined_entity,
    NetworkChest.on_player_mined_entity
  )
  script.on_event(
    defines.events.on_robot_mined_entity,
    NetworkChest.on_robot_mined_entity
  )
  script.on_event(
    defines.events.script_raised_destroy,
    NetworkChest.script_raised_destroy
  )
  script.on_event(
    defines.events.on_entity_died,
    NetworkChest.on_entity_died
  )


  script.on_event(
    defines.events.on_entity_settings_pasted,
    NetworkChest.on_entity_settings_pasted
  )


  script.on_event(
    defines.events.on_player_setup_blueprint,
    NetworkChest.on_player_setup_blueprint
  )

  -- gui events
  script.on_event(
    defines.events.on_gui_click,
    NetworkChest.on_gui_click
  )
  script.on_event(
    defines.events.on_gui_opened,
    NetworkChest.on_gui_opened
  )
  script.on_event(
    defines.events.on_gui_closed,
    NetworkChest.on_gui_closed
  )
  script.on_event(
    defines.events.on_gui_text_changed,
    NetworkChest.on_gui_text_changed
  )
  script.on_event(
    defines.events.on_gui_elem_changed,
    NetworkChest.on_gui_elem_changed
  )
  script.on_event(
    defines.events.on_gui_checked_state_changed,
    NetworkChest.on_gui_checked_state_changed
  )

  script.on_nth_tick(1, NetworkChest.onTick)
  script.on_nth_tick(60, NetworkChest.updatePlayers)
end

main()
