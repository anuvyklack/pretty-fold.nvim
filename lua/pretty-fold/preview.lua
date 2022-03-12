local api = vim.api
local bo = vim.bo
local wo = vim.wo
local fn = vim.fn
local g = vim.g
local augroup_name = 'fold_preview'
local M = {}
M.service_functions = {}

M.config = {
   key = 'h', -- Only 'h' or 'l' keys are supported.
   border = {' ', '', ' ', ' ', ' ', ' ', ' ', ' '},
}

---@param config table
function M.setup(config)
   M.config = vim.tbl_deep_extend('force', M.config, config or {})
   config = M.config

   ---Shifts due to each of the 4 parts of the border: {up, right, down, left}.
   config.border_shift = {}
   if type(config.border) == "string" then
      if config.border == 'none' then
         config.border_shift = {0,0,0,0}
      elseif vim.tbl_contains({ "single", "double", "rounded", "solid" },
                              config.border)
      then
         config.border_shift = {-1,-1,-1,-1}
      elseif config.border == 'shadow' then
         config.border_shift = {0,-1,-1,0}
      end
   elseif type(config.border) == 'table' then
      for i = 1, 4 do
         M.config.border_shift[i] = config.border[i*2] == '' and 0 or -1
      end
   else
      assert(false, 'Invalid border type or value')
   end

   if M.config.key then
      local key = M.config.key
      assert(key == 'h' or key == 'l', "Only 'h' or 'l' keys are supported!")
      local second_key = key == 'h' and 'l' or 'h'

      g.fold_preview_cocked = true
      vim.keymap.set('n', key,        function() M.keymap_open_close(key)   end)
      vim.keymap.set('n', second_key, function() M.keymap_close(second_key) end)
   end
end

---Open popup window with folded text preview. Also set autocommands to close
---popup window and change its size on scrolling and vim resizing.
function M.show_preview()
   local config = M.config

   ---Current buffer ID
   ---@type number
   local curbufnr = api.nvim_get_current_buf()

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

   ---The maximum line length of the folded region.
   local max_line_len = 0

   --- @type string[]
   local folded_lines = api.nvim_buf_get_lines(0, fold_start - 1, fold_end, true)
   local indent = #(folded_lines[1]:match('^%s+') or '')
   for i, line in ipairs(folded_lines) do
      if indent > 0 then
         line = line:sub(indent + 1)
      end
      folded_lines[i] = line
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
      border = config.border,
      relative = 'win',
      bufpos = {
         fold_start - 1, -- zero-indexed, that's why minus one
         indent,
      },
      -- The position of the window relative to 'bufos' field.
      row = config.border_shift[1],
      col = config.border_shift[4],

      width = max_line_len + 2 < room_right and max_line_len + 1 or room_right - 1,
      height = fold_size < room_below and fold_size or room_below,
      style = 'minimal',
      focusable = false,
      noautocmd = true
   })
   wo[winid].foldenable = false
   wo[winid].signcolumn = 'no'

   function M.service_functions.close()
      api.nvim_win_close(winid, false)
      api.nvim_buf_delete(bufnr, {force = true, unload = false})
      M.service_functions = {}
      api.nvim_create_augroup(augroup_name, { clear = true })
      vim.g.fold_preview_cocked = true
   end

   function M.service_functions.scroll()
      room_below = api.nvim_win_get_height(0) - fn.winline() + 1
      api.nvim_win_set_height(winid,
         fold_size < room_below and fold_size or room_below)
   end

   function M.service_functions.resize()
      room_right = api.nvim_win_get_width(0) - gutter_width - indent
      api.nvim_win_set_width(winid,
         max_line_len < room_right and max_line_len or room_right)
   end

   api.nvim_create_augroup(augroup_name, { clear = true })

   -- close
   api.nvim_create_autocmd({'CursorMoved', 'ModeChanged', 'BufLeave'}, {
      group = augroup_name,
      once = true,
      buffer = curbufnr,
      callback = M.service_functions.close
   })

   -- window scrolled
   api.nvim_create_autocmd('WinScrolled', {
      group = augroup_name,
      buffer = curbufnr,
      callback = M.service_functions.scroll
   })

   -- vim resize
   api.nvim_create_autocmd('VimResized', {
      group = augroup_name,
      buffer = curbufnr,
      callback = M.service_functions.resize
   })

end

function M.keymap_open_close(key)
   if fn.foldclosed('.') ~= -1 and g.fold_preview_cocked then
      g.fold_preview_cocked = false
      M.show_preview()
   elseif fn.foldclosed('.') ~= -1 and not g.fold_preview_cocked then
      api.nvim_command('normal! zv') -- open fold
      if not vim.tbl_isempty(M.service_functions) then
         -- For smoothness to avoid annoying screen flickering.
         vim.defer_fn(M.service_functions.close, 1)
      end
   else
      api.nvim_command('normal! '..vim.v.count1..key)
   end
end

function M.keymap_close(key)
   if fn.foldclosed('.') ~= -1 and not g.fold_preview_cocked then
      api.nvim_command('normal! zv')
      if not vim.tbl_isempty(M.service_functions) then
         -- For smoothness to avoid annoying screen flickering.
         vim.defer_fn(M.service_functions.close, 1)
      end
   elseif fn.foldclosed('.') ~= -1 then
      api.nvim_command('normal! zv') -- open fold
   else
      api.nvim_command('normal! '..vim.v.count1..key)
   end
end

---For backward compatibility
---@param key?
---| '"h"'
---| '"l"'
function M.setup_keybinding(key)
   M.setup{ key = key }
end

return M
