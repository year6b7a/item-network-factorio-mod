local M = {}

function M.main()
  M.add_network_chest_as_pastable_target_for_assemblers()
end

function M.add_network_chest_as_pastable_target_for_assemblers()
  for _, assembler in pairs(data.raw["assembling-machine"]) do
    local entities = assembler.additional_pastable_entities or {}
    table.insert(entities, "network-chest")
    assembler.additional_pastable_entities = entities
  end
end

M.main()
