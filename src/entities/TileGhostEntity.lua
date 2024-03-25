local Helpers = require "src.Helpers"
local GhostEntity = require "src.entities.GhostEntity"

local M = Helpers.shallow_copy(GhostEntity)

M.entity_name = "tile-ghost"

return M
