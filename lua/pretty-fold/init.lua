local ffi = require("ffi")
local util = require("pretty-fold.util")
local wo = vim.wo
local fn = vim.fn
local api = vim.api
ffi.cdef('int curwin_col_off(void);')

local M = {
   foldtext = {}, -- Table with all 'foldtext' functions.
   ft_ignore = { -- set with filetypes to be ignored
      neorg = true
   },
}

-- Labels for each vim foldmethod (:help foldmethod) configuration table and one
-- global configuration table, to look for missing keys if the key is not found
-- in a particular foldmethod configuration table.
local foldmethods = {
   'global', -- One global config table for all foldmethods to look missing keys into.
   'manual', 'indent', 'expr', 'marker', 'syntax', 'diff'
}

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

---Make a ready to use config table with all keys for all foldmethos from the
---default config table -and input config table.
---@param config? table
---@return table
local function configure(config)
   -- Flag indicating whether current function got a non-empty parameter.
   local got_input = config and not vim.tbl_isempty(config) and true or false

   if got_input then
      local extracted
      config, extracted = util.tbl_deep_extract(config, 'ft_ignore')
      for _, ft in ipairs(extracted) do M.ft_ignore[ft] = true end

      -- Flag shows if only one global config table has been passed or
      -- several config tables for different foldmethods.
      local input_config_is_fdm_specific = false
      for _, fdm in ipairs(foldmethods) do
         if config[fdm] then
            input_config_is_fdm_specific = true
            break
         end
      end
      if input_config_is_fdm_specific then
         config.global, config[1] = config[1], nil
      else
         config = { global = config }
      end

      -- Check if deprecated option lables was used.
      do -- Check if deprecated option lables were used.
         local old = 'comment_signs'
         local new = 'process_comment_signs'
         local status = false

         for _, k in ipairs(vim.tbl_keys(config)) do
            if config[k][old] and type(config[k][old]) == "string"
            then
               config[k][new], config[k][old] = config[k][old], nil
               status = true
            end
         end

         if status then
            util.warn(string.format(
               '"%s" option was renamed to "%s". Please update your config to avoid errors in the future.',
                old, new
            ))
         end
      end
   else
      config = { global = {} }
   end

   for fdm, _ in pairs(config) do
      config[fdm] = setmetatable(config[fdm], {
         __index = (fdm == 'global') and default_config or config.global
      })
   end

   config = setmetatable(config, {
      __index = function(self, _)
         return self.global
      end
   })

   return config
end

-- Setup the global 'foldtext' vim option.
---@param config table
function M.setup(config)
   config = configure(config)
   M.foldtext.global = function() return fold_text(config) end
   vim.o.foldtext = 'v:lua.require("pretty-fold").foldtext.global()'

   vim.api.nvim_create_autocmd('BufWinEnter', {
      callback = function()
         local filetype = vim.bo.filetype
         if M.ft_ignore[filetype] then return end
         if M.foldtext[filetype] then
            vim.wo.foldtext = string.format("v:lua.require('pretty-fold').foldtext.%s()", filetype)
         else
            vim.wo.foldtext = "v:lua.require('pretty-fold').foldtext.global()"
         end
      end
   })
end

-- Setup the filetype specific window local 'foldtext' vim option.
---@param filetype string
---@param config table
function M.ft_setup(filetype, config)
   if not M.foldtext[filetype] then
      config = configure(config)
      M.foldtext[filetype] = function() return fold_text(config) end
   end
end

return M
