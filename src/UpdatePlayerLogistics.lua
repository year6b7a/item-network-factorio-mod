local Priority = require "src.Priority"
local GlobalState = require "src.GlobalState"
local M = {}

function M.update_player_logistics()
  if not global.mod.network_chest_has_been_placed then
    return
  end

  for _, player in pairs(game.players) do
    local enable_logistics = settings.get_player_settings(player.index)
      ["item-network-enable-player-logistics"].value

    if enable_logistics then
      -- put all trash into network
      local trash_inv = player.get_inventory(defines.inventory.character_trash)
      GlobalState.deposit_inv_contents(trash_inv)

      -- get contents of player inventory
      local character = player.character
      if character ~= nil and character.character_personal_logistic_requests_enabled then
        local main_inv = player.get_inventory(defines.inventory.character_main)
        if main_inv ~= nil then
          local combined_contents = {}
          local function register_item(item, count)
            combined_contents[item] = (combined_contents[item] or 0) + count
          end

          -- register cursor
          local cursor_stack = player.cursor_stack
          if cursor_stack ~= nil and cursor_stack.valid_for_read then
            register_item(cursor_stack.name, cursor_stack.count)
          end

          -- register main inventory
          local main_contents = main_inv.get_contents()
          for item, count in pairs(main_contents) do
            register_item(item, count)
          end

          -- register ammo inventory
          local ammo_inv = player.get_inventory(defines.inventory.character_ammo)
          if ammo_inv ~= nil then
            local ammo_contents = ammo_inv.get_contents()
            for item, count in pairs(ammo_contents) do
              register_item(item, count)
            end
          end

          -- resolve logistic requests
          for logistic_idx = 1, character.request_slot_count do
            local slot = player.get_personal_logistic_slot(logistic_idx)
            if slot ~= nil and slot.name ~= nil and slot.min ~= nil then
              local current_amount = combined_contents[slot.name] or 0
              local missing = math.max(
                0,
                slot.min - current_amount
              )
              local withdrawn = GlobalState.withdraw_item2(
                slot.name,
                missing,
                Priority.HIGH
              )
              if withdrawn > 0 then
                local n_inserted = main_inv.insert({
                  name = slot.name,
                  count = withdrawn,
                })
                if n_inserted < withdrawn then
                  GlobalState.deposit_item2(
                    slot.name,
                    withdrawn - n_inserted,
                    Priority.ALWAYS_INSERT
                  )
                end
              end
            end
          end
        end
      end
    end
  end
end

return M
