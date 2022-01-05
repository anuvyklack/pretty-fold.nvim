local api = vim.api
local bo = vim.bo
local wo = vim.wo
local fn = vim.fn
local g = vim.g
local M = {}

_G.pretty_fold_preview = {}

---Open popup window with folded text preview. Also set autocommands to close
---popup window and change its size on scrolling and vim resizing.
function M.show_preview()
   ---Current buffer ID
   ---@type number
   local curbufnr = api.nvim_get_current_buf()

   _G.pretty_fold_preview[curbufnr] = {}

   local fold_start = fn.foldclosed('.') -- '.' is the current line
   if fold_start == -1 then return end

   local fold_end = fn.foldclosedend('.')

   ---The number of folded lines.
   ---@type number
   local fold_size = fold_end - fold_start + 1

   ---The number of window rows from the current cursor line to the end of the
   ---window. I.e. room below for float window.
   ---@type number
   local room_below = api.nvim_win_get_height(0) - fn.winline() + 1

   local indent = fn.indent(fold_start)

   ---The maximum line length of the folded region.
   local max_line_len = 0
   local folded_lines = api.nvim_buf_get_lines(0, fold_start - 1, fold_end, true)
   for i, line in ipairs(folded_lines) do
      if indent > 0 then
         local tabs = line:match('^\t+')
         if tabs then
            line = tabs:gsub('\t', string.rep(' ', bo.tabstop)) .. line:sub(#tabs + 1)
            -- line = string.rep(' ', fn.strdisplaywidth(tabs)) .. line:sub(#tabs + 1)
         end
         line = line:sub(indent + 1)
         folded_lines[i] = line
      end

      local line_len = fn.strdisplaywidth(line)
      if line_len > max_line_len then max_line_len = line_len end
   end

   local bufnr = api.nvim_create_buf(false, true)
   -- local bufnr = api.nvim_create_buf(true, true)
   api.nvim_buf_set_lines(bufnr, 0, 1, false, folded_lines)
   bo[bufnr].filetype = bo.filetype
   bo[bufnr].modifiable = false
   bo[bufnr].readonly = true

   ---The width of offset of a window, occupied by line number column,
   ---fold column and sign column.
   ---@type number
   local gutter_width = require("ffi").C.curwin_col_off()

   ---The number of columns from the left boundary of the preview window to the
   ---right boundary of the current window.
   ---@type number
   local room_right = api.nvim_win_get_width(0) - gutter_width - indent

   local winid = api.nvim_open_win(bufnr, false, {
      relative = 'win',
      bufpos = { -- Zero-indexed, that's why minus one.
         fold_start - 1,
         indent,
      },
      border = {' ', '', ' ', ' ', ' ', ' ', ' ', ' '},
      row = 0, col = -1, -- The position of the window relative to 'bufos' field.
      width = max_line_len + 2 < room_right and max_line_len + 1 or room_right - 1,
      height = fold_size < room_below and fold_size or room_below,
      style = 'minimal',
      focusable = false,
      noautocmd = true
   })
   wo[winid].foldenable = false
   wo[winid].signcolumn = 'no'

   -- if indent ~= 0 then
   --    fn.win_execute(winid, string.format('normal %dzl', indent), true)
   -- end

   _G.pretty_fold_preview[curbufnr].close = function()
      api.nvim_win_close(winid, false)
      api.nvim_buf_delete(bufnr, {force = true, unload = false})
      _G.pretty_fold_preview[curbufnr] = nil
      vim.cmd([[augroup fold_preview | au! | augroup END]])
      vim.g.fold_preview_cocked = true
   end

   _G.pretty_fold_preview[curbufnr].scroll = function()
      room_below = api.nvim_win_get_height(0) - fn.winline() + 1
      api.nvim_win_set_height(winid,
         fold_size < room_below and fold_size or room_below)
   end

   _G.pretty_fold_preview[curbufnr].resize = function()
      room_right = api.nvim_win_get_width(0) - gutter_width - indent
      api.nvim_win_set_width(winid,
         max_line_len < room_right and max_line_len or room_right)
   end

   -- CursorHold
   vim.cmd(string.format([[
      augroup fold_preview
         au!
         au CursorMoved,BufLeave,ModeChanged <buffer> ++once lua _G.pretty_fold_preview[%d].close()
         au WinScrolled <buffer> lua _G.pretty_fold_preview[%d].scroll()
         au VimResized  <buffer> lua _G.pretty_fold_preview[%d].resize()
      augroup END
      ]], curbufnr, curbufnr, curbufnr
   ))

end

function M.keymap_open_close(key)
   if fn.foldclosed('.') ~= -1 and g.fold_preview_cocked then
      g.fold_preview_cocked = false
      M.show_preview()

   elseif fn.foldclosed('.') ~= -1 and not g.fold_preview_cocked then
      api.nvim_command('normal! zv')
      local bufnr = api.nvim_get_current_buf()
      if _G.pretty_fold_preview[bufnr] then
         -- For smoothness to avoid annoying screen flickering.
         fn.timer_start(1, _G.pretty_fold_preview[bufnr].close)
      end
   else
      api.nvim_command('normal! '..key)
   end
end

function M.keymap_close(key)
   if fn.foldclosed('.') ~= -1 and not g.fold_preview_cocked then
      api.nvim_command('normal! zv')
      local bufnr = api.nvim_get_current_buf()
      if _G.pretty_fold_preview[bufnr] then
         -- For smoothness to avoid annoying screen flickering.
         fn.timer_start(1, _G.pretty_fold_preview[bufnr].close)
      end
   elseif fn.foldclosed('.') ~= -1 then
      api.nvim_command('normal! zv')
   else
      api.nvim_command('normal! '..key)
   end
end

---Setup default keybinding to open preview popup window.
---Only 'h' or 'l' keys are supported.
---@param key?
---| '"h"'
---| '"l"'
function M.default_keybinding(key)
   key = key or 'h'
   assert(key == 'h' or key == 'l', "Only 'h' or 'l' keys are supported!")
   local second_key = key == 'h' and 'l' or 'h'

   g.fold_preview_cocked = true
   vim.cmd(string.format([[
      nnoremap %s <cmd>lua require('pretty-fold.preview').keymap_open_close('%s')<cr>
      nnoremap %s <cmd>lua require('pretty-fold.preview').keymap_close('%s')<cr>
      ]], key, key, second_key, second_key
   ))
end

return M
