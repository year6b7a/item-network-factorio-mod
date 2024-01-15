local Helpers = require "src.Helpers"
local NetworkTankEntity = require "src.entities.NetworkTankEntity"

local M = Helpers.shallow_copy(NetworkTankEntity)

M.entity_name = "large-network-tank"

return M
