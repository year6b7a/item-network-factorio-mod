local M = {}

function M.main()
  M.add_network_chest_as_pastable_target_for_assemblers()
end

function M.add_network_chest_as_pastable_target_for_assemblers()
  local network_chest_proto = data.raw["container"]["network-chest"]
  local nc_paste = network_chest_proto.additional_pastable_entities or {}

  for _, assembler in pairs(data.raw["assembling-machine"]) do
    local entities = assembler.additional_pastable_entities or {}
    table.insert(entities, "network-chest")
    assembler.additional_pastable_entities = entities

    table.insert(nc_paste, assembler.name)
  end

  network_chest_proto.additional_pastable_entities = nc_paste
end

M.main()
