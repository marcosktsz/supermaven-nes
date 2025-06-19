local default_config = {
  keymaps = {
    accept_suggestion = "<Tab>",
    clear_suggestion = "<C-]>",
    accept_word = "<C-j>",
  },
  nes = {
    enabled = true,
    move_count_threshold = 3,
    keymaps = {
      next_edit = "<A-n>",
      previous_edit = "<A-p>",
      apply_edit = "<A-a>",
      start_edit = "<A-s>",
      end_edit = "<A-e>",
      clear_edits = "<A-c>",
      trigger_nes = "<C-f>",
    },
  },
  ignore_filetypes = {},
  disable_inline_completion = false,
  disable_keymaps = false,
  condition = function()
    return false
  end,
  log_level = "info",
}

local M = {
  config = vim.deepcopy(default_config),
}

M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), args)
end

return setmetatable(M, {
  __index = function(_, key)
    if key == "setup" then
      return M.setup
    end
    return rawget(M.config, key)
  end,
})
