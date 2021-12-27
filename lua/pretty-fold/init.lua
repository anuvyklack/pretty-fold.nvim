local wo = vim.wo
local fn = vim.fn
local M = {}

-- Labels for every vim foldmethod config table (:help foldmethod) and one
-- general config unlabeled table (accessible with config[1]) to seek into if
-- no value was found in foldmethod specific config table.
local foldmethods = { 1, 'manual', 'indent', 'expr', 'marker', 'syntax' }

local default_config = {
   fill_char = '•',
   remove_fold_markers = true,
   foldcolumn = 3,
         -- We can't calculate precisely the current foldcolumn width so we take
         -- its maximum value from 'foldcolumn' option.  But if it is set to
         -- 'auto' we have no digit to use. This value will be use in this case.
   comment_signs = nil,
         -- nil : Do nothing with comment signs.
         --  1  : Delete all comment signs from the line.
         --  2  : Delete the first comment sign at the beginning of line (if any).
         --  3  : Replace all comment signs with equal number of spaces.
         --  4  : Replace the first comment sign at the beginning of line (if
         --       any) with an equal number of spaces.
   sections = {
      left = {
         'content',
      },
      right = {
         ' ', 'number_of_folded_lines', ': ', 'percentage', ' ',
         function(config) return config.fill_char:rep(3) end
      }
   },
   add_close_pattern = true,
   matchup_patterns = {
      { '{', '}' },
      { '%(', ')' }, -- % is for escape pattern char
      { '%[', ']' }, -- % is for escape pattern char
      { 'if', 'end' },
      { 'do', 'end' },
      { 'for', 'end' },
   },
}

local function fold_text(config)
   config = config[wo.foldmethod]

   local r = { left = {}, right = {} }

   -- Get the text of all sections of the fold string.
   for _, lr in ipairs({'left', 'right'}) do
      for _, s in ipairs(config.sections[lr] or {}) do
         local sec = require('pretty-fold.service_sections')[s]
         if vim.is_callable(sec) then
            table.insert(r[lr], sec(config))
         else
            table.insert(r[lr], sec)
         end
      end
   end

   -- Calculate widths of the number column.
   local num_col_width = math.max( fn.strlen(fn.line('$')), wo.numberwidth )

   -- We can't calculate precisely the current foldcolumn width.
   -- So we assume it has the maximum value taken from 'foldcolumn' option ...
   local fold_col_width = wo.foldcolumn:match('%d+$') or config.foldcolumn

   -- Calculate width of the signs column.
   local sign_col_width = 0
   local signcolumn = wo.signcolumn
   if signcolumn:match('^auto') or
      (signcolumn:match('^number') and not wo.number)
   then
      -- Calculate the maximum number of signes placed on any line
      -- in current buffer.
      local signs = vim.fn.sign_getplaced('%', { group = '*' })[1].signs
      local spl = {}  -- signs per line
      for _, sign in ipairs(signs) do
         spl[sign.lnum] = (spl[sign.lnum] or 0) + 1
      end
      local max_spl = math.max( unpack(vim.tbl_values(spl)) or 0 )

      signcolumn = signcolumn:match('%d+$') or math.huge
      sign_col_width = math.min(signcolumn, max_spl)
   elseif signcolumn:match('^yes') then
      sign_col_width = signcolumn:match('%d+$') or 1
   end
   sign_col_width = sign_col_width * 2

   local visible_win_width =
      vim.api.nvim_win_get_width(0) - num_col_width - fold_col_width - sign_col_width

   -- Calculate the summation length of all the sections of the fold text string.
   local fold_text_len = 0
   for _, str in ipairs( vim.tbl_flatten( vim.tbl_values(r) ) ) do
      fold_text_len = fold_text_len + fn.strdisplaywidth(str)
   end

   r.expansion_str = string.rep(config.fill_char, visible_win_width - fold_text_len)

   -- ... but real foldcolumn doesn't always have its maximum value, so we need
   -- to close the gap between right section and the boder of the window.
   r.end_str = string.rep(config.fill_char, fold_col_width-1)

   local result = ''
   for _, str in ipairs(r.left)  do result = result .. str end
   result = result .. r.expansion_str
   for _, str in ipairs(r.right) do result = result .. str end
   result = result .. r.end_str

   return result
end

function M.configure_fold_text(input_config)
   local input_config_is_fdm_specific = false
   if input_config then
      for _, v in ipairs(foldmethods) do
         if input_config[v] then
            input_config_is_fdm_specific = true
            break
         end
      end
   end

   local config = {}
   for _, fdm in ipairs(foldmethods) do config[fdm] = {} end

   if input_config_is_fdm_specific then
      config = vim.tbl_deep_extend('force', config, input_config)
   elseif input_config then
      config[1] = vim.tbl_deep_extend('force', config[1], input_config)
   end

   for _, fdm in ipairs(foldmethods) do
      config[fdm] = setmetatable(config[fdm],
         { __index = (fdm == 1) and default_config or config[1] }
      )
   end

   -- Global table with all 'foldtext' functions.
   _G.pretty_fold = _G.pretty_fold or {}

   -- _G.pretty_fold.config = _G.pretty_fold.config or {}
   -- _G.pretty_fold.config[tid] = config

   return config
end

function M.setup(config)
   config = M.configure_fold_text(config)

   _G.pretty_fold.global = function() return fold_text(config) end

   vim.opt.foldtext = 'v:lua._G.pretty_fold.global()'

   -- local fid = 'f'..math.random(1000)  -- function ID
   -- _G.pretty_fold[fid] = function() return fold_text(config) end
   --
   -- vim.opt.foldtext = 'v:lua._G.pretty_fold.'..fid..'()'
end

function M.local_setup(filetype, config)
   if not _G.pretty_fold[filetype] then
      config = M.configure_fold_text(config)
      _G.pretty_fold[filetype] = function() return fold_text(config) end
      vim.opt_local.foldtext = 'v:lua._G.pretty_fold.'..filetype..'()'
   end
end

return M
