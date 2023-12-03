local Helpers = require "src.Helpers"
local NetworkChestEntity = require "src.entities.NetworkChestEntity"

local M = Helpers.shallow_copy(NetworkChestEntity)

M.entity_name = "medium-network-chest"

return M
