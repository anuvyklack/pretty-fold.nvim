local wo = vim.wo
local fn = vim.fn
local sections = require('service_sections')
local M = {}

local fill_char = '•'
local default_config = {
   fill_char = fill_char,
   remove_fold_markers = true;
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

-- It skips first blank line or line that contains only comment sign and folder
-- mark.
function _G.pretty_fold_text(config)
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
   for _, str in ipairs(r.left) do
      result = result .. str
   end
   result = result .. r.expansion_str
   for _, str in ipairs(r.right) do
      result = result .. str
   end

   return result
end

function M.setup(config)
   config = vim.tbl_deep_extend("force", default_config, config or {})

   -- Global table with of config tabels.
   _G.pretty_fold_conf = _G.pretty_fold_conf or {}

   local tid = math.random(1000)
   _G.pretty_fold_conf[tid] = config

   local fold_func = loadstring("return 'v:lua.pretty_fold_text(_G.pretty_fold_conf["..tid.."])'")

   vim.opt.fillchars:append('fold:'..config.fill_char)
   vim.opt.foldtext = fold_func()
end


-- function M.local_setup(config)
--    vim.opt_local.fillchars:append('fold:'..config.fill_char)
--    vim.opt_local.foldtext = 'v:lua.pretty_fold_text()'
-- end

return M

-- vim.opt_local.fillchars:append('fold:•')
-- vim.opt_local.foldtext = 'v:lua.custom_fold_text()'

-- opt.foldtext = 'v:lua.custom_fold_text("•")'
