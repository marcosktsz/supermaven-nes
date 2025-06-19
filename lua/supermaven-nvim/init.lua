local completion_preview = require("supermaven-nvim.completion_preview")
local log = require("supermaven-nvim.logger")
local config = require("supermaven-nvim.config")
local commands = require("supermaven-nvim.commands")
local api = require("supermaven-nvim.api")
local nes = require("supermaven-nvim.nes")

local M = {}

M.setup = function(args)
  config.setup(args)

  if config.disable_inline_completion then
    completion_preview.disable_inline_completion = true
  elseif not config.disable_keymaps then
    if config.keymaps.accept_suggestion ~= nil then
      local accept_suggestion_key = config.keymaps.accept_suggestion
      vim.keymap.set(
        "i",
        accept_suggestion_key,
        completion_preview.on_accept_suggestion,
        { noremap = true, silent = true }
      )
    end

    if config.keymaps.accept_word ~= nil then
      local accept_word_key = config.keymaps.accept_word
      vim.keymap.set(
        "i",
        accept_word_key,
        completion_preview.on_accept_suggestion_word,
        { noremap = true, silent = true }
      )
    end

    if config.keymaps.clear_suggestion ~= nil then
      local clear_suggestion_key = config.keymaps.clear_suggestion
      vim.keymap.set("i", clear_suggestion_key, completion_preview.on_dispose_inlay, { noremap = true, silent = true })
    end
  end

  if config.nes and config.nes.enabled and not config.disable_keymaps then
    local nes_keymaps = config.nes.keymaps
    
    if nes_keymaps.trigger_nes then
      vim.keymap.set({"n", "i"}, nes_keymaps.trigger_nes, function()
        nes.request_nes()
      end, { noremap = true, silent = true, desc = "Supermaven NES: Trigger edit suggestions" })
    end
    
    if nes_keymaps.next_edit then
      vim.keymap.set("n", nes_keymaps.next_edit, function()
        nes.next_suggestion()
      end, { noremap = true, silent = true, desc = "Supermaven NES: Next edit" })
    end
    
    if nes_keymaps.previous_edit then
      vim.keymap.set("n", nes_keymaps.previous_edit, function()
        nes.previous_suggestion()
      end, { noremap = true, silent = true, desc = "Supermaven NES: Previous edit" })
    end
    
    if nes_keymaps.apply_edit then
      vim.keymap.set("n", nes_keymaps.apply_edit, function()
        nes.apply_pending_nes()
      end, { noremap = true, silent = true, desc = "Supermaven NES: Apply edit" })
    end
    
    if nes_keymaps.start_edit then
      vim.keymap.set("n", nes_keymaps.start_edit, function()
        nes.walk_cursor_start_edit()
      end, { noremap = true, silent = true, desc = "Supermaven NES: Go to start of edit" })
    end
    
    if nes_keymaps.end_edit then
      vim.keymap.set("n", nes_keymaps.end_edit, function()
        nes.walk_cursor_end_edit()
      end, { noremap = true, silent = true, desc = "Supermaven NES: Go to end of edit" })
    end
    
    if nes_keymaps.clear_edits then
      vim.keymap.set("n", nes_keymaps.clear_edits, function()
        nes.clear()
      end, { noremap = true, silent = true, desc = "Supermaven NES: Clear edits" })
    end
    
    vim.keymap.set("n", "<Tab>", function()
      local _ = nes.walk_cursor_start_edit() or (
        nes.apply_pending_nes() and nes.walk_cursor_end_edit()
      )
    end, { noremap = true, silent = true, desc = "Supermaven NES: Walk cursor or apply edit" })
  end

  commands.setup()

  local cmp_ok, cmp = pcall(require, "cmp")
  if cmp_ok then
    local cmp_source = require("supermaven-nvim.cmp")
    cmp.register_source("supermaven", cmp_source.new())
  else
    if config.disable_inline_completion then
      log:warn(
        "nvim-cmp is not available, but inline completion is disabled. Supermaven nvim-cmp source will not be registered."
      )
    end
  end

  api.start()
end

return M
