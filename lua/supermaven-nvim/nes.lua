local binary = require("supermaven-nvim.binary.binary_handler")
local u = require("supermaven-nvim.util")
local log = require("supermaven-nvim.logger")

local M = {}

local nes_ns = vim.api.nvim_create_namespace("supermaven-nes")

M.state = {
  pending_edits = {},
  current_edit_index = 0,
  move_count = 0,
  last_cursor_pos = nil,
}

function M.request_nes(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_before_cursor = vim.api.nvim_get_current_line():sub(1, cursor[2])
  local line_after_cursor = vim.api.nvim_get_current_line():sub(cursor[2] + 1)
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local buffer_context = table.concat(lines, "\n")
  
  binary:request_nes_suggestions(bufnr, buffer_context, cursor[1] - 1, cursor[2], function(edits)
    if edits and #edits > 0 then
      M.state.pending_edits = edits
      M.state.current_edit_index = 1
      M.display_next_suggestion(bufnr)
    end
  end)
  
  return true
end

function M.display_next_suggestion(bufnr)
  M.clear_suggestions(bufnr)
  
  if #M.state.pending_edits == 0 or M.state.current_edit_index > #M.state.pending_edits then
    return
  end
  
  local edit = M.state.pending_edits[M.state.current_edit_index]
  if not edit then
    return
  end
  
  local cursor = vim.api.nvim_win_get_cursor(0)
  local preview = M.calculate_preview(edit, cursor[1] - 1, cursor[2])
  
  if preview then
    M.display_preview(bufnr, edit, preview)
  end
end

function M.calculate_preview(edit, cursor_row, cursor_col)
  if not edit or not edit.range or not edit.newText then
    return nil
  end
  
  local start_line = edit.range.start.line
  local start_char = edit.range.start.character
  local end_line = edit.range["end"].line
  local end_char = edit.range["end"].character
  
  if cursor_row < start_line or (cursor_row == start_line and cursor_col < start_char) then
    return {
      type = "before_edit",
      text = edit.newText,
      start_pos = { start_line + 1, start_char },
      end_pos = { end_line + 1, end_char }
    }
  elseif cursor_row > end_line or (cursor_row == end_line and cursor_col > end_char) then
    return {
      type = "after_edit", 
      text = edit.newText,
      start_pos = { start_line + 1, start_char },
      end_pos = { end_line + 1, end_char }
    }
  else
    return {
      type = "within_edit",
      text = edit.newText,
      start_pos = { start_line + 1, start_char },
      end_pos = { end_line + 1, end_char }
    }
  end
end

function M.display_preview(bufnr, edit, preview)
  if not preview then
    return
  end
  
  local opts = {
    id = M.state.current_edit_index,
    hl_mode = "combine",
    virt_text = { { preview.text, "Comment" } },
    virt_text_pos = "overlay",
  }
  
  if preview.type == "before_edit" then
    opts.virt_text_pos = "eol"
    opts.virt_text = { { "→ " .. preview.text, "DiagnosticHint" } }
  elseif preview.type == "after_edit" then
    opts.virt_text_pos = "eol"
    opts.virt_text = { { "← " .. preview.text, "DiagnosticInfo" } }
  end
  
  local extmark_id = vim.api.nvim_buf_set_extmark(
    bufnr, 
    nes_ns, 
    preview.start_pos[1] - 1, 
    preview.start_pos[2], 
    opts
  )
end

function M.clear_suggestions(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, nes_ns, 0, -1)
  end
end

function M.walk_cursor_start_edit(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if #M.state.pending_edits == 0 or M.state.current_edit_index == 0 then
    M.request_nes(bufnr)
    return false
  end
  
  local edit = M.state.pending_edits[M.state.current_edit_index]
  if edit and edit.range then
    local start_line = edit.range.start.line + 1
    local start_char = edit.range.start.character
    vim.api.nvim_win_set_cursor(0, { start_line, start_char })
    return true
  end
  
  return false
end

function M.walk_cursor_end_edit(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if #M.state.pending_edits == 0 or M.state.current_edit_index == 0 then
    return false
  end
  
  local edit = M.state.pending_edits[M.state.current_edit_index]
  if edit and edit.range then
    local end_line = edit.range["end"].line + 1
    local end_char = edit.range["end"].character
    vim.api.nvim_win_set_cursor(0, { end_line, end_char })
    return true
  end
  
  return false
end

function M.apply_pending_nes(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if #M.state.pending_edits == 0 or M.state.current_edit_index == 0 then
    return false
  end
  
  local edit = M.state.pending_edits[M.state.current_edit_index]
  if not edit then
    return false
  end
  
  vim.lsp.util.apply_text_edits({ edit }, bufnr, "utf-8")
  
  M.state.current_edit_index = M.state.current_edit_index + 1
  M.display_next_suggestion(bufnr)
  
  return true
end

function M.next_suggestion(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if #M.state.pending_edits == 0 then
    M.request_nes(bufnr)
    return
  end
  
  M.state.current_edit_index = M.state.current_edit_index + 1
  if M.state.current_edit_index > #M.state.pending_edits then
    M.state.current_edit_index = 1
  end
  
  M.display_next_suggestion(bufnr)
end

function M.previous_suggestion(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if #M.state.pending_edits == 0 then
    return
  end
  
  M.state.current_edit_index = M.state.current_edit_index - 1
  if M.state.current_edit_index < 1 then
    M.state.current_edit_index = #M.state.pending_edits
  end
  
  M.display_next_suggestion(bufnr)
end

function M.on_cursor_moved(bufnr)
  local config = require("supermaven-nvim.config")
  local threshold = config.nes and config.nes.move_count_threshold or 3
  
  local current_pos = vim.api.nvim_win_get_cursor(0)
  
  if M.state.last_cursor_pos then
    local moved = M.state.last_cursor_pos[1] ~= current_pos[1] or 
                  M.state.last_cursor_pos[2] ~= current_pos[2]
    
    if moved then
      M.state.move_count = M.state.move_count + 1
      if M.state.move_count >= threshold then
        M.clear(bufnr)
      end
    end
  end
  
  M.state.last_cursor_pos = current_pos
end

function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  M.clear_suggestions(bufnr)
  M.state.pending_edits = {}
  M.state.current_edit_index = 0
  M.state.move_count = 0
  M.state.last_cursor_pos = nil
end

function M.has_suggestions()
  return #M.state.pending_edits > 0 and M.state.current_edit_index > 0
end

return M