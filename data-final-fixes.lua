local M = {}

function M.main()
  M.add_network_chest_as_pastable_target_for_assemblers()
end

local NETWORK_CHEST_ENTITIES = {
  "network-chest",
  "medium-network-chest",
  "large-network-chest",
}

function M.add_network_chest_as_pastable_target_for_assemblers()
  for _, entity_name in ipairs(NETWORK_CHEST_ENTITIES) do
    local network_chest_proto = data.raw["container"][entity_name]
    local nc_paste = network_chest_proto.additional_pastable_entities or {}

    -- add all other network chests as pastable
    for _, other_entity in ipairs(NETWORK_CHEST_ENTITIES) do
      if other_entity ~= entity_name then
        table.insert(nc_paste, other_entity)
      end
    end

    for _, assembler in pairs(data.raw["assembling-machine"]) do
      local entities = assembler.additional_pastable_entities or {}
      table.insert(entities, entity_name)
      assembler.additional_pastable_entities = entities

      table.insert(nc_paste, assembler.name)
    end

    network_chest_proto.additional_pastable_entities = nc_paste
  end
end

M.main()
