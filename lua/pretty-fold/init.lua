local wo = vim.wo
local fn = vim.fn
local sections = require('pretty-fold.service_sections')
local M = {}

local fill_char = '•'

-- local general_config = {
local default_config = {
   fill_char = fill_char,
   remove_fold_markers = true,

   -- nil : Do nothing.
   --  1  : Delete all comment signs from the line.
   --  2  : Delete the first comment sign at the beginning of line (if any).
   --  3  : Replace all comment signs with equal number of spaces.
   --  4  : Replace the first comment sign at the beginning of line (if any)
   --       with an equal number of spaces.
   comment_signs = nil,

   match_the_close_pattern = true,
   matchup_patterns = {
      { '{', '}' },
      { '%(', ')' }, -- % is for escape pattern char
      { '%[', ']' }, -- % is for escape pattern char
      { 'if', 'end' },
      { 'do', 'end' },
      { 'for', 'end' },
   },
   sections = {
      left = {
         'content',
      },
      right = {
         ' ', 'number_of_folded_lines',
         -- ' ', string.rep(fill_char, 2), ' ',
         ': ',
         'percentage', ' '
      }
   }
}

-- local default_config = { }

-- local foldmethods = { 'manual', 'indent', 'expr', 'marker', 'syntax' }

local function fold_text(config)
   local r = { left = {}, right = {} }

   for _, lr in ipairs({'left', 'right'}) do
      for _, s in ipairs(config.sections[lr] or {}) do
         local sec = sections[s]
         if vim.is_callable(sec) then
            table.insert(r[lr], sec(config))
         else
            table.insert(r[lr], sec)
         end
      end
   end

   if config.sections.right and
      not vim.tbl_isempty(config.sections.right)
   then
      -- The width of the number, fold and sign columns.
      local num_col_width = math.min( fn.strlen(fn.line('$')), wo.numberwidth )
      local fold_col_width = wo.foldcolumn:match('%d+$') or 3
      local sign_col_width = wo.signcolumn:match('%d+$') * 2 or 6

      local visible_win_width =
         vim.api.nvim_win_get_width(0) - num_col_width - fold_col_width - sign_col_width

      local lnum = 0
      for _, str in ipairs( vim.tbl_flatten( vim.tbl_values(r) ) ) do
         -- lnum = lnum + #str
         lnum = lnum + fn.strdisplaywidth(str)
      end
      r.expansion_str = string.rep(config.fill_char, visible_win_width - lnum - 4)
   else
      r.expansion_str = ''
   end

   local result = ''
   for _, str in ipairs(r.left)  do result = result .. str end
   result = result .. r.expansion_str
   for _, str in ipairs(r.right) do result = result .. str end

   return result
end

function M.setup(config)
   config = vim.tbl_deep_extend("force", default_config, config or {})

   -- Global table with all 'foldtext' functions.
   _G.pretty_fold = _G.pretty_fold or {}

   local tid = math.random(1000)

   _G.pretty_fold['f'..tid] = function()
      return fold_text(config)
   end

   vim.opt.fillchars:append('fold:'..config.fill_char)
   vim.opt.foldtext = 'v:lua._G.pretty_fold.f'..tid..'()'

   -- _G.pretty_fold.config = _G.pretty_fold.config or {}
   -- _G.pretty_fold.config[tid] = config
end


-- function M.local_setup(config)
--    vim.opt_local.fillchars:append('fold:'..config.fill_char)
--    vim.opt_local.foldtext = 'v:lua.pretty_fold_text()'
-- end

return M
