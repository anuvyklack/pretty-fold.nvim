local ffi = require("ffi")
local util = require("pretty-fold.util")
local wo = vim.wo
local fn = vim.fn
local api = vim.api

ffi.cdef('int curwin_col_off(void);')

local M = {
   ---Table with all 'foldtext' functions.
   foldtext = {}
}

-- Labels for every vim foldmethod config table (:help foldmethod) and one
-- general config unlabeled table (accessible with config[1]) to seek into if
-- no value was found in foldmethod specific config table.
local foldmethods = { 1, 'manual', 'indent', 'expr', 'marker', 'syntax', 'diff' }

local default_config = {
   fill_char = '•',
   remove_fold_markers = true,

   -- Keep the indentation of the content of the fold string.
   keep_indentation = true,

   -- Possible values:
   -- "delete" : Delete all comment signs from the fold string.
   -- "spaces" : Replace all comment signs with equal number of spaces.
   --  false   : Do nothing with comment signs.
   ---@type string|boolean
   process_comment_signs = 'spaces',

   ---Comment signs additional to '&commentstring' option.
   comment_signs = {},

   -- List of patterns that will be removed from content foldtext section.
   stop_words = {
      '@brief%s*', -- (for cpp) Remove '@brief' and all spaces after.
   },

   sections = {
      left = {
         'content',
      },
      right = {
         ' ', 'number_of_folded_lines', ': ', 'percentage', ' ',
         function(config) return config.fill_char:rep(3) end
      }
   },

   add_close_pattern = true, -- true, 'last_line' or false
   matchup_patterns = {
      -- beginning of the line -> any number of spaces -> 'do' -> end of the line
      { '^%s*do$', 'end' }, -- `do ... end` blocks
      { '^%s*if', 'end' },  -- if ... end
      { '^%s*for', 'end' }, -- for
      { 'function%s*%(', 'end' }, -- 'function( or 'function (''
      { '{', '}' },
      { '%(', ')' }, -- % to escape lua pattern char
      { '%[', ']' }, -- % to escape lua pattern char
   },
}

-- The main function which produses the string which will be shown
-- in the fold line.
---@param config table
local function fold_text(config)
   config = config[wo.foldmethod]

   local r = { left = {}, right = {} }

   -- Get the text of all sections of the fold string.
   for _, lr in ipairs({'left', 'right'}) do
      for _, s in ipairs(config.sections[lr] or {}) do
         local sec = require('pretty-fold.sections')[s]
         table.insert(r[lr], vim.is_callable(sec) and sec(config) or sec)
      end
   end

   ---The width of offset of a window, occupied by line number column,
   ---fold column and sign column.
   ---@type number
   local gutter_width = ffi.C.curwin_col_off()

   local visible_win_width = api.nvim_win_get_width(0) - gutter_width

   -- The summation length of all sections of the fold text string.
   local fold_text_len = fn.strdisplaywidth( table.concat( vim.tbl_flatten( vim.tbl_values(r) )))

   r.expansion_str = string.rep(config.fill_char, visible_win_width - fold_text_len)

   return table.concat( vim.tbl_flatten({r.left, r.expansion_str, r.right}) )
end

local function configure_fold_text(input_config)
   local input_config_is_fdm_specific = false
   if input_config then
      for _, v in ipairs(foldmethods) do
         if input_config[v] then
            input_config_is_fdm_specific = true
            break
         end
      end
   end

   do -- Check if deprecated option lables was used.
      local old = 'comment_signs'
      local new = 'process_comment_signs'
      local status = false

      if input_config_is_fdm_specific then
         for _, k in ipairs(vim.tbl_keys(input_config)) do
            if vim.tbl_contains( vim.tbl_keys(input_config[k]), old)
               and type(input_config[k][old]) == "string"
            then
               input_config[k][new], input_config[k][old] = input_config[k][old], nil
               status = true
            end
         end
      else
         if vim.tbl_contains( vim.tbl_keys(input_config), old)
            and type(input_config[old]) == "string"
         then
            input_config[new], input_config[old] = input_config[old], nil
            status = true
         end
      end

      if status then
         util.warn( string.format(
            '"%s" option was renamed to "%s". Please update your config to avoid errors in the future.',
             old, new
         ))
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
         { __index = (fdm == 1) and default_config or config[1] })
   end

   return config
end

-- Setup the global 'foldtext' vim option.
---@param config table
function M.setup(config)
   config = configure_fold_text(config or {})
   M.foldtext.global = function() return fold_text(config) end
   vim.opt.foldtext = 'v:lua.require("pretty-fold").foldtext.global()'
end

-- Setup the filetype specific window local 'foldtext' vim option.
---@param filetype string
---@param config table
function M.ft_setup(filetype, config)
   if not M.foldtext[filetype] then
      config = configure_fold_text(config)
      M.foldtext[filetype] = function() return fold_text(config) end
   end
   wo.foldtext = string.format("v:lua.require('pretty-fold').foldtext.%s()", filetype)
end

return M
