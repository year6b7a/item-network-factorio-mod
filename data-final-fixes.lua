local M = {}

function M.main()
  -- M.add_network_chest_as_pastable_target_for_assemblers()
  M.add_pastable_target_for_entities(
    "container",
    {
      "network-chest",
      "medium-network-chest",
      "large-network-chest",
    }
  )

  M.add_pastable_target_for_entities(
    "storage-tank",
    {
      "network-tank",
      "medium-network-tank",
      "large-network-tank",
    }
  )
end

function M.add_pastable_target_for_entities(prototype_name, entities)
  for _, entity_name in ipairs(entities) do
    local network_chest_proto = data.raw[prototype_name][entity_name]
    local entity_paste = network_chest_proto.additional_pastable_entities or {}

    -- add all other network chests as pastable
    for _, other_entity in ipairs(entities) do
      if other_entity ~= entity_name then
        table.insert(entity_paste, other_entity)
      end
    end

    for _, assembler in pairs(data.raw["assembling-machine"]) do
      local paste_entities = assembler.additional_pastable_entities or {}
      table.insert(paste_entities, entity_name)
      assembler.additional_pastable_entities = paste_entities
    end

    network_chest_proto.additional_pastable_entities = entity_paste
  end
end

M.main()
