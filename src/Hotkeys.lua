local M = {}

M.hotkeys = {
  {
    type = "custom-input",
    name = "in_confirm_dialog",
    key_sequence = "E",
    alternative_key_sequence = "RETURN",
  },
  {
    type = "custom-input",
    name = "in_cancel_dialog",
    key_sequence = "ESCAPE",
  },
  {
    type = "custom-input",
    name = "in_open_network_view",
    key_sequence = "CONTROL + SHIFT + N",
  },
}

return M
